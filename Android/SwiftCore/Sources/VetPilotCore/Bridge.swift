import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

public enum VetPilotBridge {
    static func optional<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }
    static func encode<T: Encodable>(_ value: T) throws -> Any {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: encoder.encode(value))
    }
    static func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: JSONSerialization.data(withJSONObject: value))
    }
    static func fail(_ text: String) -> [String: Any] { ["error": text] }
    public static func dispatch(_ input: String) -> String {
        do {
            guard let data = input.data(using: .utf8), data.count <= 20_000_000,
                  let q = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "{\"error\":\"Invalid request\"}"
            }
            let response = try handle(q)
            let output = try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])
            return String(data: output, encoding: .utf8)!
        } catch { return (try? String(data: JSONSerialization.data(withJSONObject: fail(error.localizedDescription)), encoding: .utf8)) ?? "{\"error\":\"Request failed\"}" }
    }
    static func medicationJSON(_ m: Medication, id: Int) -> [String: Any] {
        ["id":id,"name":m.displayName,"generic":m.generic,"brand":m.brand,"drugClass":m.drugClass,
         "species":m.species.map(\.rawValue).sorted(),"form":m.form.rawValue,"indication":m.indication,
         "protocolOnly":m.kind == .protocolOnly,"frequency":m.frequency,"route":m.route,"notes":m.notes,
         "source":m.source,"strengths":m.strengths,"concentration":optional(m.concentration),"controlled":m.controlled]
    }
    static func presetJSON(_ p: BuiltInProtocolPreset) throws -> [String: Any] {
        ["id":p.id,"label":p.label,"definition":try encode(p.definition),"highRisk":p.highRisk,
         "confidence":p.confidence,"requiresWeight":p.doseBasis.requiresWeight,"supportsConcentration":p.doseBasis.supportsConcentration,
         "concentrationLabel":p.doseBasis.concentrationLabel,"isRate":p.doseBasis.isRate]
    }
    static func selectionJSON(_ s: DoseRangeSelection?) -> Any {
        guard let s else { return NSNull() }
        return ["low":s.low,"high":s.high,"selected":s.selected,"unit":s.unit,"math":s.math,"isRate":s.isRate]
    }
    static func handle(_ q: [String: Any]) throws -> [String: Any] {
        func str(_ key: String, _ fallback: String = "") -> String { q[key] as? String ?? fallback }
        func bool(_ key: String) -> Bool { q[key] as? Bool ?? false }
        func number(_ key: String) -> Double? {
            if let s = q[key] as? String { return MedicationSafety.parsePositive(s) }
            guard let n = q[key] as? Double, n.isFinite, n > 0 else { return nil }; return n
        }
        let op = str("op")
        if op == "catalog" {
            return ["medications":ClinicalData.medications.enumerated().map { medicationJSON($0.element,id:$0.offset) },
                    "breeds":ClinicalData.breeds.map { ["species":$0.species.rawValue,"name":$0.name,"conditions":$0.conditions,"note":$0.note] },
                    "labs":LabworkCatalog.tests.map { ["id":$0.id,"provider":$0.provider,"code":$0.code,"name":$0.name,"purpose":$0.purpose,"species":$0.species,"specimen":$0.specimen,"amount":$0.amount,"tube":$0.tube,"preparation":LabworkCatalog.preparation($0.preparation),"handling":$0.handling,"notes":$0.notes,"source":$0.source,"available":$0.available,"components":$0.components] as [String:Any] },
                    "labReviewed":LabworkCatalog.reviewed,"tubeNote":LabworkCatalog.tubeNote,
                    "protocolBases":ProtocolDoseBasis.allCases.map(\.rawValue),"clinicCategories":ClinicProtocol.categories]
        }
        if op == "clinicValidate" || op == "clinicImport" {
            guard let package = q["package"] else { return fail("Missing file") }
            let decoded = try ClinicPackage.decode(JSONSerialization.data(withJSONObject: package))
            let result = op == "clinicImport" ? ClinicPackage(items: decoded.items.map { $0.importedCopy() }) : decoded
            return ["package": try encode(result)]
        }
        if op == "nutrition" {
            guard let species = Species(rawValue:str("species")), let unit = NutritionWeightUnit(rawValue:str("unit")),
                  let status = NutritionReproductiveStatus(rawValue:str("status")), let weight = number("weight"), let bcs = q["bcs"] as? Int else { return fail("Enter a valid weight, species, units and body condition score.") }
            for key in ["currentCalories","targetWeight"] {
                if !str(key).isEmpty && number(key) == nil { return fail("Enter a positive number for \(key), or leave it blank.") }
            }
            guard let r = NutritionMath.estimate(species:species,weight:weight,unit:unit,bcs:bcs,reproductiveStatus:status,currentCalories:number("currentCalories"),clinicianTargetWeight:number("targetWeight")) else { return fail("Nutrition inputs are outside supported limits.") }
            return ["goal":r.goal.rawValue,"weightStatus":r.weightStatus,"currentKg":r.currentKg,
                    "idealWeight":optional(r.estimatedIdealKg.map { unit.value(fromKg:$0) }),"unit":unit.rawValue,
                    "currentRER":r.currentRER,"planningRER":optional(r.planningRER),"targetCalories":optional(r.targetCalories),
                    "floor":optional(r.calorieFloor),"baseline":optional(r.baselineCalories),"reductionPercent":r.reductionPercent,
                    "math":r.factorDescription,"caution":r.caution]
        }
        var med: Medication
        if let custom = q["custom"] {
            let c = try decode(custom,as:CustomMedicationDefinition.self)
            guard c.hasValidDefinition, !c.generic.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return fail("Invalid custom medication definition") }
            med = c.asMedication
        } else {
            guard let id = q["medication"] as? Int, ClinicalData.medications.indices.contains(id) else { return fail("Choose a medication") }
            med = ClinicalData.medications[id]
        }
        guard let species = Species(rawValue:str("species")), med.supports(species) else { return fail("This medication entry does not support the selected species.") }
        let presets = med.kind == .protocolOnly ? BuiltInProtocolCatalog.presets(for:med,species:species) : []
        if op == "presets" { return ["presets":try presets.map(presetJSON),"medication":medicationJSON(med,id:-1)] }
        guard op == "dose" else { return fail("Unsupported operation") }
        var logic = DoseLogic(medication:med)
        if let override = q["override"] {
            guard med.kind == .protocolOnly else { return fail("Clinic overrides apply only to protocol entries") }
            let def = try decode(override,as:ProtocolMedicationDefinition.self)
            guard def.species == species, def.medicationKey == ProtocolMedicationDefinition.key(for:med,species:species), def.validationIssue == nil else { return fail("Invalid clinic override") }
            logic.protocolDefinition = def
        } else if med.kind == .protocolOnly {
            guard let selected = presets.first(where: { $0.id == str("preset") }) else { return fail("Choose a valid medication protocol") }
            logic.selectedBuiltInPreset = selected; logic.protocolDefinition = selected.definition
        }
        guard ["lb","kg"].contains(str("unit")), let level = DoseSelectionLevel(rawValue:str("level")),
              let frequency = DoseLogic.FrequencyChoice(rawValue:str("frequency")),let rounding = SolidDoseRounding(rawValue:str("rounding")) else { return fail("Invalid dose selections") }
        logic.patientWeight = str("weight"); logic.patientWeightUnit = str("unit")
        logic.selectedDoseLevel = level; logic.selectedFrequency = frequency; logic.solidRounding = rounding
        logic.selectedStrengthIndex = q["strengthIndex"] as? Int ?? 0
        if !logic.activeStrengths.isEmpty && !logic.activeStrengths.indices.contains(logic.selectedStrengthIndex) { return fail("Choose a valid product strength") }
        logic.concentration = str("concentration");logic.prescribedPotassiumRate = str("potassiumRate")
        logic.infusionConcentrationConfirmed = bool("infusionConfirmed")
        logic.priorCourseDoses = q["priorCourseDoses"] as? Int ?? 0;logic.priorCourseHistoryConfirmed = bool("priorConfirmed")
        if let error = logic.prescribedRateInputError ?? logic.weightInputError ?? logic.concentrationInputError { return fail(error) }
        let r: DoseResult
        if let definition = logic.protocolDefinition {
            r = ProtocolDoseCalculator.calculate(definition:definition,kg:logic.kg,strength:logic.selectedStrength,concentration:logic.activeConcentration,builtInPreset:logic.selectedBuiltInPreset,prescribedRate:MedicationSafety.parsePositive(logic.prescribedPotassiumRate))
        } else { r = ClinicalData.calculate(medication:med,kg:logic.kg,strength:logic.selectedStrength,concentration:logic.activeConcentration) }
        var out: [String: Any] = ["available":r.available,"headline":r.headline,"math":r.math,"formulation":r.formulation,"warning":r.warning,
         "source":logic.protocolDefinition?.sourceReference ?? med.source,"notes":logic.protocolDefinition?.notes ?? med.notes,
         "route":logic.activeRoute,"frequency":logic.activeFrequencyLabel,"kg":logic.kg]
        guard r.available else { return out }
        out["selection"] = selectionJSON(logic.administrationSelection ?? logic.doseSelection)
        out["summary"] = optional(logic.readableAdministrationSummary);out["note"] = optional(logic.readableAdministrationNote)
        out["reviewReason"] = optional(logic.administrationReviewReason)
        out["levels"] = DoseSelectionLevel.allCases.map { candidate -> Any in
            var copy = logic;copy.selectedDoseLevel = candidate
            return ["level":candidate.rawValue,"selection":selectionJSON(copy.administrationSelection ?? copy.doseSelection)]
        }
        if let solid = logic.selectedSolidPlan {
            out["solid"] = ["rawUnits":solid.rawUnits,"roundedUnits":solid.roundedUnits,"deliveredMg":solid.deliveredMg,"variancePercent":solid.variancePercent,"instruction":logic.administrationInstruction(for:solid)]
        }
        if let volume = logic.selectedAdministrationVolume { out["volume"] = ["value":volume.value,"unit":volume.unit,"instruction":logic.volumeInstruction(volume)] }
        if let days = q["days"] as? Int, days > 0, days <= 365 { out["supply"] = logic.supplySummary(days:days) }
        return out
    }
}
@_cdecl("vetpilot_dispatch")
public func dispatchC(_ input: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let input else { return nil }
    return strdup(VetPilotBridge.dispatch(String(cString:input)))
}
@_cdecl("vetpilot_free")
public func freeC(_ value: UnsafeMutablePointer<CChar>?) { free(value) }
