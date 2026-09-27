import XCTest
@testable import FergusonVetPilot

final class AdministrationMathTests: XCTestCase {
    func testExplicitInjectionPrescriptionPreservesUnitsAndRejectsInvalidValues() {
        let range = DoseRangeSelection(low: 20, high: 60, selected: 20, unit: "mg", math: "10 kg × selected mg/kg", isRate: false)
        for (dose, amount) in [(2.0, 20.0), (3.25, 32.5), (6.0, 60.0)] {
            let selected = AdministrationMath.prescribedInjectionSelection(range, minDose: 2, maxDose: 6, prescribedDose: dose)
            XCTAssertEqual(selected?.selected, amount)
            XCTAssertEqual(selected?.unit, "mg")
            XCTAssertEqual(selected?.low, 20)
            XCTAssertEqual(selected?.high, 60)
        }
        for dose in [nil, 0, -1, .nan, .infinity, 1.9, 6.1] as [Double?] {
            XCTAssertNil(AdministrationMath.prescribedInjectionSelection(range, minDose: 2, maxDose: 6, prescribedDose: dose))
        }
        let capped = DoseRangeSelection(low: 20, high: 30, selected: 20, unit: "mg", math: "10 kg × selected mg/kg", isRate: false)
        XCTAssertNil(AdministrationMath.prescribedInjectionSelection(capped, minDose: 2, maxDose: 6, prescribedDose: 4))
        let insulin = DoseRangeSelection(low: 5, high: 10, selected: 5, unit: "units", math: "10 kg × selected units/kg", isRate: false)
        let selected = AdministrationMath.prescribedInjectionSelection(insulin, minDose: 0.5, maxDose: 1, prescribedDose: 0.75)
        XCTAssertEqual(selected?.selected, 7.5)
        XCTAssertEqual(selected?.unit, "units")
        if let selected { XCTAssertEqual(AdministrationMath.volume(selection: selected, basis: .unitsKg, concentration: 40)?.value, 0.1875) }
    }

    func testLowMiddleHighInterpolation() {
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .low), 10, accuracy: 0.000001)
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .middle), 15, accuracy: 0.000001)
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .high), 20, accuracy: 0.000001)
    }

    func testAllInjectionProtocolsAcceptExplicitDosesWithoutChangingConversions() throws {
        var checks = 0
        for medication in MedicationFormulations.organized where medication.form == .injection {
            for species in medication.species {
                for preset in BuiltInProtocolCatalog.presets(for: medication, species: species) {
                    let definition = MedicationFormulations.definition(preset.definition, for: medication)
                    if MedicationSafety.requiresPrescribedPotassiumRate(key: definition.medicationKey) { continue }
                    for kg in [1.0, 4.0, 10.0, 50.0] {
                        for level in DoseSelectionLevel.allCases {
                            let reference = AdministrationMath.selection(for: definition, kg: kg, level: level)
                            let dose = definition.minDose + (definition.maxDose - definition.minDose) * level.fraction
                            let selected = AdministrationMath.prescribedInjectionSelection(reference, minDose: definition.minDose, maxDose: definition.maxDose, prescribedDose: dose)
                            if let reference {
                                let candidate = try XCTUnwrap(selected, preset.id)
                                XCTAssertEqual(candidate.selected, reference.selected, accuracy: max(1e-10, abs(reference.selected) * 1e-12), preset.id)
                                XCTAssertEqual(candidate.unit, reference.unit, preset.id)
                                let expectedVolume = AdministrationMath.volume(selection: reference, basis: definition.doseBasis, concentration: definition.concentration)
                                let actualVolume = AdministrationMath.volume(selection: candidate, basis: definition.doseBasis, concentration: definition.concentration)
                                XCTAssertEqual(actualVolume?.unit, expectedVolume?.unit, preset.id)
                                if let expectedVolume, let actualVolume { XCTAssertEqual(actualVolume.value, expectedVolume.value, accuracy: max(1e-12, abs(expectedVolume.value) * 1e-12), preset.id) }
                            } else { XCTAssertNil(selected, preset.id) }
                            checks += 1
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checks, 1000)
    }

    func testWholeSolidRoundingShowsDeliveredDose() throws {
        let down = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 62, strengthMg: 50, rounding: .down))
        XCTAssertEqual(down.rawUnits, 1.24, accuracy: 0.000001)
        XCTAssertEqual(down.roundedUnits, 1, accuracy: 0.000001)
        XCTAssertEqual(down.deliveredMg, 50, accuracy: 0.000001)

        let up = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 62, strengthMg: 50, rounding: .up))
        XCTAssertEqual(up.roundedUnits, 2, accuracy: 0.000001)
        XCTAssertEqual(up.deliveredMg, 100, accuracy: 0.000001)
    }

    func testMcgPerKgMinuteConvertsAgainstMgPerMl() throws {
        let d = ProtocolMedicationDefinition(
            medicationKey: "test", generic: "Lidocaine", speciesRaw: Species.dog.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mcgKgMin.rawValue, minDose: 25, maxDose: 80,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 20,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let middle = try XCTUnwrap(AdministrationMath.selection(for: d, kg: 20, level: .middle))
        XCTAssertEqual(middle.selected, 1050, accuracy: 0.000001) // 52.5 mcg/kg/min × 20 kg
        let volume = try XCTUnwrap(AdministrationMath.volume(selection: middle, basis: .mcgKgMin, concentration: 20))
        XCTAssertEqual(volume.value, 3.15, accuracy: 0.000001)
        XCTAssertEqual(volume.unit, "mL/hr")
    }

    func testBsaUsesAuditedDogAndCatConstants() throws {
        let dog = ProtocolMedicationDefinition(
            medicationKey: "dog", generic: "Chemo", speciesRaw: Species.dog.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mgM2.rawValue, minDose: 30, maxDose: 30,
            frequency: "once", route: "IV", strengths: [], concentration: nil,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let cat = ProtocolMedicationDefinition(
            medicationKey: "cat", generic: "Chemo", speciesRaw: Species.cat.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mgM2.rawValue, minDose: 30, maxDose: 30,
            frequency: "once", route: "IV", strengths: [], concentration: nil,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let dogSelection = try XCTUnwrap(AdministrationMath.selection(for: dog, kg: 10, level: .middle))
        let catSelection = try XCTUnwrap(AdministrationMath.selection(for: cat, kg: 4, level: .middle))
        XCTAssertEqual(dogSelection.selected, 14.07, accuracy: 0.02)
        XCTAssertEqual(catSelection.selected, 7.56, accuracy: 0.02)
    }

    func testDispenseAdministrationCountRoundsPartialScheduleUp() {
        XCTAssertEqual(AdministrationMath.administrations(days: 7, dosesPerDay: 0.5), 4)
        XCTAssertEqual(AdministrationMath.administrations(days: 14, dosesPerDay: 2), 28)
    }
    func testEverySolidStrengthRoundingAndCourseQuantity() throws {
        var cases = 0
        // Fractional, half-boundary, zero-down and exact-whole inputs across every
        // catalog strength. Expected values are independent of production rounding.
        for medication in MedicationFormulations.organized where [.tablet, .capsule].contains(medication.form) {
            for strength in medication.strengths {
                for (raw, down, nearest, up) in [(0.2,0.0,0.0,1.0),(0.5,0.0,1.0,1.0),(1.24,1.0,1.0,2.0),(1.5,1.0,2.0,2.0),(1.76,1.0,2.0,2.0),(2.0,2.0,2.0,2.0)] {
                    for (mode, expected) in [(SolidDoseRounding.exact,raw),(.down,down),(.nearest,nearest),(.up,up)] {
                        let plan = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: raw * strength, strengthMg: strength, rounding: mode))
                        XCTAssertEqual(plan.rawUnits,raw,accuracy:1e-10,medication.displayName)
                        XCTAssertEqual(plan.roundedUnits,expected,accuracy:1e-10,medication.displayName)
                        XCTAssertEqual(plan.deliveredMg,expected * strength,accuracy:1e-10)
                        for perDay in [1.0,2.0,3.0,4.0] {
                            let count = AdministrationMath.administrations(days:14,dosesPerDay:perDay)
                            XCTAssertEqual(plan.roundedUnits * Double(count),expected * 14 * perDay,accuracy:1e-8)
                        }
                        cases += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(cases,1000)
        print("SOLID_ROUNDING_AUDIT: \(cases) strength/rounding cases; four frequencies each")
    }

    func testCarprofenRoundsAfterDailyDoseDivision() throws {
        let medication = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        let total = try XCTUnwrap(AdministrationMath.selection(for:medication,kg:10,level:.low))
        XCTAssertEqual(total.selected,44,accuracy:1e-12)
        for perDay in [1.0,2.0,3.0,4.0] {
            let perDose = try XCTUnwrap(MedicationSafety.perAdministration(total,frequency:medication.frequency,dosesPerDay:perDay))
            XCTAssertEqual(perDose.selected,44 / perDay,accuracy:1e-12)
            for strength in medication.strengths {
                for mode in SolidDoseRounding.allCases {
                    let plan = try XCTUnwrap(AdministrationMath.solidPlan(targetMg:perDose.selected,strengthMg:strength,rounding:mode))
                    let raw = 44 / perDay / strength
                    let expected = mode == .exact ? raw : mode == .down ? floor(raw) : mode == .up ? ceil(raw) : raw.rounded()
                    XCTAssertEqual(plan.roundedUnits,expected)
                    XCTAssertEqual(plan.deliveredMg,expected * strength)
                    // A mathematical rounding result must not silently be approved
                    // when it no longer matches this fixed source-backed target.
                    XCTAssertEqual(MedicationSafety.withinRange(plan.deliveredMg,perDose),abs(plan.deliveredMg-perDose.selected)<1e-10)
                }
            }
        }
    }

    func testHalfUnitTiesAbsorbOnlyBinaryNoise() throws {
        for value in [1.5,1.5.nextDown,1.5.nextUp] {
            XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:value,strengthMg:1,rounding:.nearest)).roundedUnits,2)
            XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:value,strengthMg:1,rounding:.down)).roundedUnits,1)
            XCTAssertEqual(ClinicDoseMath.roundedUnits(quantity:value,mode:"Nearest whole"),2)
        }
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:1.499999999,strengthMg:1,rounding:.nearest)).roundedUnits,1)
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:1.500000001,strengthMg:1,rounding:.nearest)).roundedUnits,2)
    }

    func testExactMathAndDoseControlParity() throws {
        XCTAssertEqual(SolidDoseRounding.allCases.map(\.rawValue),["Exact math","Round down","Nearest whole","Round up"])
        let exact = try XCTUnwrap(AdministrationMath.solidPlan(targetMg:44,strengthMg:25,rounding:.exact))
        XCTAssertEqual(exact.roundedUnits,1.76,accuracy:1e-12)
        XCTAssertEqual(exact.deliveredMg,44,accuracy:1e-12)
        let carprofen = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        XCTAssertTrue(AdministrationMath.hasSourceRecommendedDose(for:carprofen))
        let cefpodoxime = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Cefpodoxime proxetil" })
        XCTAssertFalse(AdministrationMath.hasSourceRecommendedDose(for:cefpodoxime),"A range midpoint is not a recommendation")
        let potassium = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Potassium chloride" })
        var definition = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "potassium-chloride-dog-1" }).definition
        definition.minDose = 0.1; definition.maxDose = 0.1
        XCTAssertFalse(AdministrationMath.hasSourceRecommendedDose(for:potassium,definition:definition,isBuiltInProtocol:true))
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.definition.minDose > 0 && $0.definition.minDose == $0.definition.maxDose && !$0.id.hasPrefix("potassium-chloride") })
        XCTAssertTrue(AdministrationMath.hasSourceRecommendedDose(for:carprofen,definition:preset.definition,isBuiltInProtocol:true))
        XCTAssertFalse(AdministrationMath.hasSourceRecommendedDose(for:carprofen,definition:preset.definition,isBuiltInProtocol:false),"A clinic-entered rule must not become a catalog recommendation")
    }

}
