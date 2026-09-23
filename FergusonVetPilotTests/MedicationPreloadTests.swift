import XCTest
@testable import FergusonVetPilot

final class MedicationPreloadTests: XCTestCase {
    // Expected clinical eligibility is asserted independently of the engine.
    private func expectedEligibility(_ id: String, weight: Double) -> Bool {
        switch id {
        case "levetiracetam-cat-2": return false
        case "praziquantel-dog-1": return weight > 0 && weight <= 34
        case "doxorubicin-dog-1": return weight > 10
        case "doxorubicin-dog-2": return weight > 0 && weight <= 10
        case "digoxin-cat-1": return weight > 0 && weight < 3
        case "digoxin-cat-2": return weight >= 3 && weight <= 6
        case "digoxin-cat-3": return weight > 6
        case "mirtazapine-oral-dog-1": return weight > 0 && weight < 7
        case "mirtazapine-oral-dog-2": return weight > 7 && weight <= 15
        case "mirtazapine-oral-dog-3": return weight > 15 && weight <= 30
        case "mirtazapine-oral-dog-4": return weight > 30
        default: return true
        }
    }

    func testProtocolOnlyLibraryHasFull114MedicationCoverage() {
        let protocolMeds = ClinicalData.medications.filter { $0.kind == .protocolOnly }
        XCTAssertEqual(protocolMeds.count, 114)
        XCTAssertEqual(BuiltInProtocolCatalog.coveredMedicationNames.count, 114)

        var missing: [String] = []
        for med in protocolMeds {
            for species in Species.allCases where med.supports(species) {
                if BuiltInProtocolCatalog.presets(for: med, species: species).isEmpty {
                    missing.append("\(med.generic) [\(species.rawValue)]")
                }
            }
        }
        XCTAssertTrue(missing.isEmpty, "Missing preloaded calculator presets: \(missing.joined(separator: ", "))")
    }

    func testEveryBuiltInPresetCalculatesWithRepresentativeWeight() {
        var failures: [String] = []
        for preset in BuiltInProtocolCatalog.all {
            let definition = preset.definition
            let result = ProtocolDoseCalculator.calculate(
                definition: definition,
                kg: preset.species == .dog ? 20 : 4,
                strength: definition.strengths.first,
                concentration: definition.concentration,
                builtInPreset: preset
            )
            let weight = preset.species == .dog ? 20.0 : 4.0
            if expectedEligibility(preset.id, weight: weight) != result.available {
                failures.append(preset.id)
            }
        }
        XCTAssertTrue(failures.isEmpty, "Presets that did not calculate: \(failures.joined(separator: ", "))")
    }

    func testInsulinGlargineCatPresetCalculatesUnits() throws {
        let med = try XCTUnwrap(ClinicalData.medications.first { $0.kind == .protocolOnly && $0.generic == "Insulin glargine" && $0.supports(.cat) })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: med, species: .cat).first)
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 4,
            strength: nil,
            concentration: preset.concentration,
            builtInPreset: preset
        )
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.lowercased().contains("unit"))
    }

    func testDoxorubicinBSAProtocolCalculates() throws {
        let med = try XCTUnwrap(ClinicalData.medications.first { $0.kind == .protocolOnly && $0.generic == "Doxorubicin" && $0.supports(.dog) })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: med, species: .dog).first { $0.doseBasis == .mgM2 })
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 25,
            strength: nil,
            concentration: preset.concentration,
            builtInPreset: preset
        )
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.math.contains("BSA"))
        XCTAssertTrue(result.math.contains("mg/m²"))
    }

    func testOphthalmicDropProtocolDoesNotRequireWeight() throws {
        let med = try XCTUnwrap(ClinicalData.medications.first { $0.kind == .protocolOnly && $0.generic == "Tacrolimus ophthalmic" })
        let species = try XCTUnwrap(Species.allCases.first { med.supports($0) })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: med, species: species).first { $0.doseBasis == .dropsEye })
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 0,
            strength: nil,
            concentration: nil,
            builtInPreset: preset
        )
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.lowercased().contains("drop"))
    }

    func testPotassiumChlorideRateProtocolProducesHourlyVolumeWhenConcentrationKnown() throws {
        let med = try XCTUnwrap(ClinicalData.medications.first { $0.kind == .protocolOnly && $0.generic == "Potassium chloride" })
        let species = try XCTUnwrap(Species.allCases.first { med.supports($0) })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: med, species: species).first { $0.doseBasis == .mEqKgHr })
        let concentration = preset.concentration ?? 2.0
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 10,
            strength: nil,
            concentration: concentration,
            builtInPreset: preset
        )
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("/hr"))
        XCTAssertTrue(result.formulation.contains("mL/hr"))
    }

    func testManualClinicOverridePathRemainsAvailable() {
        let definition = ProtocolMedicationDefinition(
            medicationKey: "manual-test",
            generic: "Manual Test",
            speciesRaw: Species.dog.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mgKg.rawValue,
            minDose: 2,
            maxDose: 2,
            frequency: "q12h",
            route: "PO",
            strengths: [10],
            concentration: nil,
            sourceReference: "Clinic protocol",
            notes: "Manual override retained",
            veterinarianApproved: true
        )
        let result = ProtocolDoseCalculator.calculate(
            definition: definition,
            kg: 5,
            strength: 10,
            concentration: nil
        )
        XCTAssertTrue(result.available)
        XCTAssertTrue(result.headline.contains("10 mg"))
    }

    func testEveryBuiltInPresetCalculatesAtSmallTypicalAndLargeWeights() {
        var failures: [String] = []
        for preset in BuiltInProtocolCatalog.all {
            let weights: [Double]
            if !preset.doseBasis.requiresWeight {
                weights = [0]
            } else if preset.species == .dog {
                weights = [2, 20, 60]
            } else {
                weights = [1, 4, 8]
            }

            for weight in weights {
                let definition = preset.definition
                let result = ProtocolDoseCalculator.calculate(
                    definition: definition,
                    kg: weight,
                    strength: definition.strengths.first,
                    concentration: definition.concentration,
                    builtInPreset: preset
                )
                let combined = [result.headline, result.math, result.formulation].joined(separator: " ").lowercased()
                if result.available != expectedEligibility(preset.id, weight: weight) || combined.contains("nan") || combined.contains(" inf ") || combined.hasPrefix("inf") {
                    failures.append("\(preset.id)@\(weight)kg")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "Boundary arithmetic failures: \(failures.joined(separator: ", "))")
    }

    func testPresetIdentifiersAreUniqueAndAllHaveSources() {
        XCTAssertEqual(Set(BuiltInProtocolCatalog.all.map(\.id)).count, BuiltInProtocolCatalog.all.count)
        let missingSources = BuiltInProtocolCatalog.all.filter {
            $0.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        XCTAssertTrue(missingSources.isEmpty, "Presets missing sources: \(missingSources.map(\.id))")
    }

    func testMassConcentrationsUseMgPerMlDisplayUnit() {
        XCTAssertEqual(ProtocolDoseBasis.mgKg.concentrationLabel, "mg/mL")
        XCTAssertEqual(ProtocolDoseBasis.mcgKg.concentrationLabel, "mg/mL")
        XCTAssertEqual(ProtocolDoseBasis.mcgKgMin.concentrationLabel, "mg/mL")
        XCTAssertEqual(ProtocolDoseBasis.gKg.concentrationLabel, "mg/mL")
        XCTAssertEqual(ProtocolDoseBasis.unitsKg.concentrationLabel, "units/mL")
        XCTAssertEqual(ProtocolDoseBasis.mEqKgHr.concentrationLabel, "mEq/mL")
    }

    func testDexmedetomidineCatMcgToMgMlConversion() throws {
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "dexmedetomidine-cat-1" })
        XCTAssertEqual(try XCTUnwrap(preset.concentration), 0.5, accuracy: 0.000001)
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 4,
            strength: nil,
            concentration: preset.concentration,
            builtInPreset: preset
        )
        XCTAssertTrue(result.available)
        // 40 mcg/kg × 4 kg = 160 mcg = 0.16 mg; 0.16 mg / 0.5 mg/mL = 0.32 mL.
        XCTAssertTrue(result.formulation.contains("0.32 mL"), result.formulation)
        XCTAssertTrue(result.formulation.contains("0.5 mg/mL"), result.formulation)
    }

    func testDexmedetomidineDogUsesBSAInsteadOfFixedMcgKg() throws {
        let iv = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "dexmedetomidine-dog-1" })
        let im = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "dexmedetomidine-dog-2" })
        XCTAssertEqual(iv.doseBasis, .mgM2)
        XCTAssertEqual(iv.minDose, 0.375, accuracy: 0.000001)
        XCTAssertEqual(im.doseBasis, .mgM2)
        XCTAssertEqual(im.minDose, 0.5, accuracy: 0.000001)
        let result = ProtocolDoseCalculator.calculate(
            definition: iv.definition,
            kg: 10,
            strength: nil,
            concentration: iv.concentration,
            builtInPreset: iv
        )
        XCTAssertTrue(result.math.contains("BSA"))
        XCTAssertTrue(result.formulation.contains("mg/mL"))
    }

    func testLidocaineCriMcgPerMinuteConvertsSafelyFromMgPerMl() throws {
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "lidocaine-dog-2" })
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 20,
            strength: nil,
            concentration: 20,
            builtInPreset: preset
        )
        // 25–80 mcg/kg/min × 20 kg = 500–1600 mcg/min = 0.5–1.6 mg/min.
        // ×60 / 20 mg/mL = 1.5–4.8 mL/hr.
        XCTAssertTrue(result.formulation.contains("1.5–4.8 mL/hr"), result.formulation)
    }

    func testFentanylCriUsesHourlyMgProtocolAndMgPerMl() throws {
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "fentanyl-dog-2" })
        XCTAssertEqual(preset.doseBasis, .mgKgHr)
        XCTAssertEqual(preset.minDose, 0.01, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(preset.concentration), 0.05, accuracy: 0.000001)
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 20,
            strength: nil,
            concentration: preset.concentration,
            builtInPreset: preset
        )
        // 0.01 mg/kg/hr × 20 kg = 0.2 mg/hr; /0.05 mg/mL = 4 mL/hr.
        XCTAssertTrue(result.formulation.contains("4 mL/hr"), result.formulation)
    }

    func testFelineGlargineU100IsFixedUnitStartingProtocol() throws {
        let presets = BuiltInProtocolCatalog.all.filter { $0.generic == "Insulin glargine" && $0.species == .cat }
        XCTAssertEqual(presets.count, 1)
        let preset = try XCTUnwrap(presets.first)
        XCTAssertEqual(preset.doseBasis, .fixedUnits)
        XCTAssertEqual(preset.minDose, 1, accuracy: 0.000001)
        XCTAssertEqual(preset.maxDose, 1, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(preset.concentration), 100, accuracy: 0.000001)
        let result = ProtocolDoseCalculator.calculate(
            definition: preset.definition,
            kg: 4,
            strength: nil,
            concentration: 100,
            builtInPreset: preset
        )
        XCTAssertTrue(result.formulation.contains("0.01 mL"), result.formulation)
    }

    func testPziCatSeparatesFdaLabelAndAahaGuidelineBranches() {
        let presets = BuiltInProtocolCatalog.all.filter { $0.generic == "Insulin PZI" && $0.species == .cat }
        XCTAssertTrue(presets.contains { $0.id == "insulin-pzi-cat-1" && $0.doseBasis == .unitsKg && $0.minDose == 0.2 && $0.maxDose == 0.7 })
        XCTAssertTrue(presets.contains { $0.id == "insulin-pzi-cat-2" && $0.doseBasis == .fixedUnits && $0.minDose == 1 && $0.maxDose == 1 })
    }

    func testMetronidazoleUsesIndicationSpecificBranches() {
        let dog = BuiltInProtocolCatalog.all.filter { $0.generic == "Metronidazole" && $0.species == .dog }
        XCTAssertTrue(dog.contains { $0.id == "metronidazole-dog-1" && $0.minDose == 10 && $0.maxDose == 15 && $0.frequency == "q12h" })
        XCTAssertTrue(dog.contains { $0.id == "metronidazole-dog-2" && $0.minDose == 25 && $0.maxDose == 25 })
        XCTAssertTrue(dog.contains { $0.id == "metronidazole-dog-3" && $0.minDose == 7.5 && $0.maxDose == 7.5 })
    }

    func testLevetiracetamHasIRERAndIVBranchesForBothSpecies() {
        for species in Species.allCases {
            let presets = BuiltInProtocolCatalog.all.filter { $0.generic == "Levetiracetam" && $0.species == species }
            XCTAssertTrue(presets.contains { $0.frequency == "q8h" && $0.route == "PO" && $0.minDose == 20 && $0.maxDose == 60 })
            XCTAssertTrue(presets.contains { $0.frequency == "q12h" && $0.route.contains("ER") && $0.minDose == 30 && $0.maxDose == 30 })
            XCTAssertTrue(presets.contains { $0.route == "IV" && $0.minDose == 30 && $0.maxDose == 60 })
        }
    }

    func testMitotaneMaintenanceIsWeeklyNotQ12h() throws {
        let maintenance = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "mitotane-dog-2" })
        XCTAssertTrue(maintenance.frequency.lowercased().contains("week"))
        XCTAssertFalse(maintenance.frequency.lowercased().contains("q12"))
    }

    func testDigoxinUsesExplicitSourceSpecificSelectors() throws {
        let dogConservative = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "digoxin-dog-1" })
        XCTAssertEqual(dogConservative.minDose, 0.0025, accuracy: 0.000001)
        XCTAssertEqual(dogConservative.maxDose, 0.005, accuracy: 0.000001)
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "digoxin-dog-2" && $0.minDose == 0.003 && $0.maxDose == 0.011 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "digoxin-cat-2" && $0.doseBasis == .fixedMg && $0.minDose == 0.03125 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "digoxin-cat-3" && $0.doseBasis == .fixedMg && $0.minDose == 0.03125 })
    }

    func testAuditedAntimicrobialRangesAndProducts() {
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "amoxicillin-dog-1" && $0.minDose == 11 && $0.maxDose == 30 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "amoxicillin-cat-1" && $0.minDose == 11 && $0.maxDose == 30 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "marbofloxacin-dog-1" && $0.minDose == 2.75 && $0.maxDose == 5.5 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "orbifloxacin-dog-1" && $0.minDose == 2.5 && $0.maxDose == 7.5 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "orbifloxacin-dog-2" && $0.minDose == 7.5 && $0.route.contains("suspension") })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "minocycline-dog-1" && $0.minDose == 5 && $0.maxDose == 10 })
    }

    func testControlledAnalgesicCriticalBranches() throws {
        let butorphanolDog = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "butorphanol-dog-2" })
        XCTAssertEqual(butorphanolDog.minDose, 0.2, accuracy: 0.000001)
        XCTAssertEqual(butorphanolDog.maxDose, 0.2, accuracy: 0.000001)
        let buprenorphineCatLA = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "buprenorphine-cat-4" })
        XCTAssertEqual(buprenorphineCatLA.minDose, 0.24, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(buprenorphineCatLA.concentration), 1.8, accuracy: 0.000001)
        let hydromorphoneDogCri = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "hydromorphone-dog-3" })
        XCTAssertEqual(hydromorphoneDogCri.minDose, 0.03, accuracy: 0.000001)
        XCTAssertEqual(hydromorphoneDogCri.maxDose, 0.03, accuracy: 0.000001)
    }

    func testEmergencySelectorsCarryCorrectFrequencyAndSeparation() {
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "epinephrine-dog-1" && $0.frequency.contains("3–5") })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "epinephrine-cat-1" && $0.frequency.contains("3–5") })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "atropine-injection-dog-1" && $0.minDose == 0.02 && $0.maxDose == 0.04 })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "atropine-injection-dog-2" && $0.minDose == 0.04 && $0.maxDose == 0.04 && $0.frequency.contains("once") })
        XCTAssertTrue(BuiltInProtocolCatalog.all.contains { $0.id == "atropine-injection-cat-2" && $0.minDose == 0.04 && $0.maxDose == 0.04 })
    }

    func testCriBranchesSayContinuousAndUseCriRoute() {
        for id in ["ampicillin-sulbactam-dog-2", "ampicillin-sulbactam-cat-2", "metoclopramide-dog-2", "metoclopramide-cat-2"] {
            let preset = BuiltInProtocolCatalog.all.first { $0.id == id }
            XCTAssertEqual(preset?.frequency, "continuous")
            XCTAssertEqual(preset?.route, "IV CRI")
        }
        for id in ["potassium-chloride-dog-1", "potassium-chloride-cat-1"] {
            let preset = BuiltInProtocolCatalog.all.first { $0.id == id }
            XCTAssertTrue(preset?.frequency.contains("continuous") == true)
            XCTAssertEqual(preset?.route, "IV infusion")
        }
    }

    func testSecondAuditMetadataAndIndicationBranches() throws {
        let tmpDogGeneral = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "trimethoprim-sulfamethoxazole-dog-2" })
        XCTAssertEqual(tmpDogGeneral.minDose, 30, accuracy: 0.000001)
        XCTAssertEqual(tmpDogGeneral.maxDose, 45, accuracy: 0.000001)
        XCTAssertEqual(tmpDogGeneral.route, "PO")
        XCTAssertEqual(tmpDogGeneral.frequency, "q12h")

        let tmpCat = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "trimethoprim-sulfamethoxazole-cat-1" })
        XCTAssertEqual(tmpCat.minDose, 15, accuracy: 0.000001)
        XCTAssertEqual(tmpCat.maxDose, 15, accuracy: 0.000001)

        let telmisartan = BuiltInProtocolCatalog.all.filter { $0.generic == "Telmisartan" && $0.species == .cat }
        XCTAssertTrue(telmisartan.contains { $0.id == "telmisartan-cat-1" && $0.minDose == 1.5 && $0.frequency.contains("14 days") && $0.route == "PO" })
        XCTAssertTrue(telmisartan.contains { $0.id == "telmisartan-cat-2" && $0.minDose == 2 && $0.frequency == "q24h" })
        XCTAssertTrue(telmisartan.contains { $0.id == "telmisartan-cat-3" && $0.minDose == 1 && $0.frequency == "q24h" })

        let levothyroxine = BuiltInProtocolCatalog.all.filter { $0.generic == "Levothyroxine" && $0.species == .dog }
        XCTAssertTrue(levothyroxine.contains { $0.id == "levothyroxine-dog-1" && $0.minDose == 0.022 && $0.frequency == "q24h" && $0.route == "PO" })
        XCTAssertTrue(levothyroxine.contains { $0.id == "levothyroxine-dog-2" && $0.minDose == 0.011 && $0.frequency == "q12h" && $0.route == "PO" })

        let trilostane = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "trilostane-dog-1" })
        XCTAssertEqual(trilostane.route, "PO")
        XCTAssertTrue(trilostane.frequency.contains("q24h"))
    }

    func testDesmopressinSeparatesHemostaticAndCdiProtocols() {
        for species in Species.allCases {
            let presets = BuiltInProtocolCatalog.all.filter { $0.generic == "Desmopressin" && $0.species == species }
            XCTAssertTrue(presets.contains { $0.doseBasis == .mcgKg && $0.minDose == 0.3 && $0.maxDose == 1 && $0.route == "SC/IV" && $0.frequency == "once" })
            XCTAssertTrue(presets.contains { $0.doseBasis == .fixedMg && $0.minDose == 0.1 && $0.maxDose == 0.2 && $0.route == "PO" })
            XCTAssertTrue(presets.contains { $0.doseBasis == .dropsEye })
        }
    }

    func testMethocarbamolDistinguishesDailyTotalFromIvIncrement() throws {
        for species in Species.allCases {
            let oral = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "methocarbamol-\(species.rawValue.lowercased())-1" })
            let iv = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "methocarbamol-\(species.rawValue.lowercased())-2" })
            XCTAssertEqual(oral.route, "PO")
            XCTAssertTrue(oral.frequency.contains("total daily"))
            XCTAssertEqual(iv.route, "IV")
            XCTAssertEqual(iv.minDose, 44, accuracy: 0.000001)
            XCTAssertTrue(iv.frequency.contains("330 mg/kg/day"))
            XCTAssertTrue(iv.highRisk)
        }
    }

    func testAllPresetsHaveExplicitRouteFrequencyAndSource() {
        let missing = BuiltInProtocolCatalog.all.filter {
            $0.route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        XCTAssertTrue(missing.isEmpty, "Missing protocol metadata: \(missing.map(\.id))")
    }

    func testVolumeBasedProtocolRetainsRequiredProductConcentration() throws {
        let calcium = try XCTUnwrap(BuiltInProtocolCatalog.all.first { $0.id == "calcium-gluconate-dog-1" })
        XCTAssertEqual(calcium.doseBasis, .mLKg)
        XCTAssertEqual(try XCTUnwrap(calcium.concentration), 100, accuracy: 0.000001)
        XCTAssertTrue(calcium.route.lowercased().contains("iv"))
    }

}

