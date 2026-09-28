import XCTest
@testable import FergusonVetPilot

final class ClinicOverrideTests: XCTestCase {
    private func fixture(kind: DoseKind = .mgKg, form: MedicationForm = .liquid) -> Medication {
        Medication(generic: "Fixture", brand: "Test", drugClass: "Test", species: [.dog, .cat], form: form,
            indication: "Original indication", kind: kind, minDose: 2, maxDose: 4, frequency: "q12h",
            route: "PO", notes: "Original clinical information", source: "Original reference",
            strengths: form == .tablet ? [10, 20] : [], concentration: form == .liquid ? 25 : nil, controlled: false)
    }

    func testSeedsPreserveOriginalUnitsAndClinicalInformation() throws {
        for (kind, basis) in [(DoseKind.mgKg, ProtocolDoseBasis.mgKg), (.mgLb, .mgLb), (.fixedMg, .fixedMg)] {
            let original = fixture(kind: kind)
            let seed = try XCTUnwrap(ClinicMedicationOverride.seed(for: original, species: .dog))
            XCTAssertEqual(seed.doseBasis, basis)
            XCTAssertEqual(seed.concentration, 25)
            XCTAssertEqual(seed.notes, original.notes)
            XCTAssertEqual(seed.sourceReference, original.source)
            XCTAssertFalse(seed.veterinarianApproved)
        }
        XCTAssertNil(ClinicMedicationOverride.seed(for: fixture(kind: .robenacoxibCatBand), species: .cat))
    }

    @MainActor func testDoseAndConcentrationPersistAndCalculateAfterReopening() throws {
        let suite = "ClinicOverrideTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = fixture()
        var definition = try XCTUnwrap(ClinicMedicationOverride.seed(for: original, species: .dog))
        definition.minDose = 3; definition.maxDose = 3; definition.concentration = 50
        definition.veterinarianApproved = true
        ProtocolMedicationStore(defaults: defaults).save(definition)
        let reopened = ProtocolMedicationStore(defaults: defaults)
        let saved = try XCTUnwrap(reopened.definition(for: original, species: .dog))
        XCTAssertEqual(saved, definition)
        XCTAssertEqual(ClinicMedicationOverride.concentrationInput(for: original, definition: saved), "50")
        let range = try XCTUnwrap(AdministrationMath.selection(for: saved, kg: 10, level: .low))
        XCTAssertEqual(range.selected, 30)
        let volume = try XCTUnwrap(AdministrationMath.volume(selection: range, basis: saved.doseBasis, concentration: saved.concentration))
        XCTAssertEqual(volume.value, 0.6, accuracy: 1e-12)
        XCTAssertEqual(volume.unit, "mL")
        XCTAssertTrue(ProtocolDoseCalculator.calculate(definition: saved, kg: 10, strength: nil, concentration: saved.concentration).available)
        XCTAssertEqual(original.minDose, 2)
        XCTAssertEqual(original.concentration, 25)
        XCTAssertEqual(original.notes, "Original clinical information")
        reopened.remove(for: original, species: .dog)
        XCTAssertNil(ProtocolMedicationStore(defaults: defaults).definition(for: original, species: .dog))
        XCTAssertEqual(ClinicMedicationOverride.concentrationInput(for: original, definition: nil), "25")
    }

    @MainActor func testOverridesAreSeparateForSpeciesAndDosageForm() throws {
        let suite = "ClinicOverrideTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProtocolMedicationStore(defaults: defaults), liquid = fixture(), tablet = fixture(form: .tablet)
        var dog = try XCTUnwrap(ClinicMedicationOverride.seed(for: liquid, species: .dog))
        dog.concentration = 75; store.save(dog)
        XCTAssertNil(store.definition(for: liquid, species: .cat))
        XCTAssertNil(store.definition(for: tablet, species: .dog))
        XCTAssertEqual(store.definition(for: liquid, species: .dog)?.concentration, 75)
    }

    func testBlankOverrideConcentrationNeverFallsBackToCatalogProduct() throws {
        let medication = fixture()
        var override = try XCTUnwrap(ClinicMedicationOverride.seed(for: medication, species: .dog))
        override.concentration = nil
        XCTAssertEqual(ClinicMedicationOverride.concentrationInput(for: medication, definition: override), "")
        XCTAssertEqual(ClinicMedicationOverride.concentrationInput(for: medication, definition: nil), "25")
    }

    func testInvalidOrUnapprovedOverridesDoNotCalculate() throws {
        var definition = try XCTUnwrap(ClinicMedicationOverride.seed(for: fixture(), species: .dog))
        XCTAssertFalse(ProtocolDoseCalculator.calculate(definition: definition, kg: 10, strength: nil, concentration: 25).available)
        definition.veterinarianApproved = true; definition.concentration = -1
        XCTAssertNotNil(definition.validationIssue)
        XCTAssertNil(AdministrationMath.selection(for: definition, kg: 10, level: .low))
        XCTAssertFalse(ProtocolDoseCalculator.calculate(definition: definition, kg: 10, strength: nil, concentration: -1).available)
    }

    @MainActor func testEveryCatalogMedicationAcceptsAnIndependentSavedClinicRule() throws {
        let suite = "ClinicOverrideTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProtocolMedicationStore(defaults: defaults)
        XCTAssertFalse(MedicationFormulations.organized.isEmpty)
        for medication in MedicationFormulations.organized {
            for species in medication.species {
                let definition = ProtocolMedicationDefinition(
                    medicationKey: ProtocolMedicationDefinition.key(for: medication, species: species),
                    generic: medication.generic, speciesRaw: species.rawValue, doseBasisRaw: ProtocolDoseBasis.mgKg.rawValue,
                    minDose: 1, maxDose: 1, frequency: "q12h", route: "PO", strengths: [], concentration: 12.5,
                    sourceReference: "Synthetic persistence test only", notes: "", veterinarianApproved: false)
                store.save(definition)
                let reopened = ProtocolMedicationStore(defaults: defaults)
                XCTAssertEqual(reopened.definition(for: medication, species: species), definition, medication.displayName)
                store.remove(for: medication, species: species)
            }
        }
    }

    func testPresetSeedUsesTheSelectedFormulationsConcentrationAndRoute() throws {
        let medication = try XCTUnwrap(MedicationFormulations.organized.first { $0.generic == "Famotidine" && $0.form == .liquid })
        let preset = try XCTUnwrap(BuiltInProtocolCatalog.presets(for: medication, species: .dog).first)
        let expected = MedicationFormulations.definition(preset.definition, for: medication)
        let seed = try XCTUnwrap(ClinicMedicationOverride.seed(for: medication, species: .dog, preset: preset))
        XCTAssertEqual(seed.concentration, expected.concentration)
        XCTAssertEqual(seed.route, expected.route)
        XCTAssertEqual(seed.strengths, expected.strengths)
        XCTAssertFalse(seed.veterinarianApproved)
    }
}
