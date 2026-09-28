import Foundation

/// Clinic settings are stored alongside the catalog; they never overwrite its clinical reference.
enum ClinicMedicationOverride {
    static func seed(for medication: Medication, species: Species, preset: BuiltInProtocolPreset? = nil) -> ProtocolMedicationDefinition? {
        if let preset {
            var definition = MedicationFormulations.definition(preset.definition, for: medication)
            definition.veterinarianApproved = false
            return definition
        }
        let basis: ProtocolDoseBasis
        switch medication.kind {
        case .mgKg: basis = .mgKg
        case .mgLb: basis = .mgLb
        case .fixedMg: basis = .fixedMg
        // Weight-band and protocol-only entries need an explicit clinic equation.
        case .robenacoxibCatBand, .protocolOnly: return nil
        }
        return ProtocolMedicationDefinition(
            medicationKey: ProtocolMedicationDefinition.key(for: medication, species: species),
            generic: medication.generic, speciesRaw: species.rawValue, doseBasisRaw: basis.rawValue,
            minDose: medication.minDose, maxDose: medication.maxDose > 0 ? medication.maxDose : medication.minDose,
            frequency: medication.frequency, route: medication.route, strengths: medication.strengths,
            concentration: medication.concentration, sourceReference: medication.source,
            notes: medication.notes, veterinarianApproved: false)
    }

    static func concentrationInput(for medication: Medication, definition: ProtocolMedicationDefinition?) -> String {
        // A saved override with no concentration must not silently inherit a different product.
        let value: Double?
        if let definition { value = definition.concentration } else { value = medication.concentration }
        return value.map(MedicationSafety.input) ?? ""
    }
}
