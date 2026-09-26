import XCTest
@testable import FergusonVetPilot

final class MedicationFormulationTests: XCTestCase {
    func testEveryExistingProtocolRemainsAvailableWithoutDoseChanges() {
        for original in BuiltInProtocolCatalog.all {
            let entries = MedicationFormulations.organized.filter { $0.generic == original.generic && $0.supports(original.species) }
            let copies = entries.flatMap { BuiltInProtocolCatalog.presets(for: $0, species: original.species) }.filter { $0.id == original.id }
            XCTAssertFalse(copies.isEmpty, original.id)
            for copy in copies { XCTAssertEqual(copy, original) }
        }
    }

    func testSeparatedProductsOnlyExposeCompatibleUnitsAndRoutes() {
        for medication in MedicationFormulations.organized where medication.formulation != nil {
            for species in medication.species {
                for preset in BuiltInProtocolCatalog.presets(for: medication, species: species) {
                    let definition = MedicationFormulations.definition(preset.definition, for: medication)
                    XCTAssertEqual(definition.minDose, preset.minDose)
                    XCTAssertEqual(definition.maxDose, preset.maxDose)
                    XCTAssertEqual(definition.frequency, preset.frequency)
                    if [.tablet, .capsule].contains(medication.form) {
                        XCTAssertNil(definition.concentration)
                        XCTAssertTrue(definition.route.contains("PO"), preset.id)
                        XCTAssertFalse(definition.route.contains("IV"), preset.id)
                    } else { XCTAssertTrue(definition.strengths.isEmpty, preset.id) }
                }
            }
        }
    }

    func testPregabalinProductsHaveIndependentStrengths() throws {
        let entries = MedicationFormulations.organized.filter { $0.generic == "Pregabalin" }
        XCTAssertEqual(entries.count, 4)
        let capsule = try XCTUnwrap(entries.first { $0.form == .capsule })
        XCTAssertEqual(capsule.strengths, [25,50,75,100,150,200,225,300])
        let solution = try XCTUnwrap(entries.first { $0.formulation?.label == "Oral solution · 20 mg/mL" })
        let suspension = try XCTUnwrap(entries.first { $0.formulation?.label == "Compounded oral suspension" })
        XCTAssertEqual(solution.concentration, 20)
        XCTAssertNil(suspension.concentration)
        XCTAssertEqual(suspension.formulation?.concentrations, [50])
        XCTAssertEqual(suspension.formulation?.customConcentration, true)
        let bonqat = try XCTUnwrap(entries.first { $0.formulation?.bonqat == true })
        XCTAssertEqual(bonqat.species, [.cat])
        let labeled = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: bonqat, species: .cat).first)
        XCTAssertEqual(labeled.minDose, 5)
        XCTAssertEqual(labeled.maxDose, 5)
        XCTAssertEqual(labeled.concentration, 50)
        XCTAssertTrue(BuiltInProtocolCatalog.presets(for: bonqat, species: .dog).isEmpty)
        for medication in [solution, suspension] {
            XCTAssertTrue(medication.strengths.isEmpty)
            let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: medication, species: .dog).first)
            let definition = MedicationFormulations.definition(preset.definition, for: medication)
            XCTAssertTrue(definition.strengths.isEmpty)
            XCTAssertEqual(definition.minDose, 2)
            XCTAssertEqual(definition.maxDose, 5)
        }
    }
    func testReleaseBranchesAndInjectionDefaultsRemainDistinct() {
        for medication in MedicationFormulations.organized {
            for species in medication.species {
                for preset in BuiltInProtocolCatalog.presets(for: medication, species: species) {
                    let definition = MedicationFormulations.definition(preset.definition, for: medication)
                    if medication.formulation?.keepProtocolConcentration == true {
                        XCTAssertEqual(definition.concentration, preset.concentration, preset.id)
                    }
                    if ["Levetiracetam", "Diltiazem"].contains(medication.generic), medication.form != .injection {
                        let isER = medication.formulation?.label.contains("extended release") == true
                        XCTAssertEqual(preset.label.lowercased().contains("extended-release") || preset.label.lowercased().contains("extended release"), isER, preset.id)
                    }
                }
            }
        }
    }

}
