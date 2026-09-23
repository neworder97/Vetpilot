import Foundation

enum DoseSelectionLevel: String, CaseIterable, Identifiable {
    case low = "Low"
    case middle = "Middle"
    case high = "High"

    var id: String { rawValue }
    var fraction: Double {
        switch self {
        case .low: return 0
        case .middle: return 0.5
        case .high: return 1
        }
    }
}

enum SolidDoseRounding: String, CaseIterable, Identifiable {
    case down = "Round down"
    case nearest = "Nearest whole"
    case up = "Round up"

    var id: String { rawValue }
}

struct DoseRangeSelection: Equatable {
    let low: Double
    let high: Double
    let selected: Double
    let unit: String
    let math: String
    let isRate: Bool

    var hasRange: Bool { abs(low - high) > 0.0000001 }
}

struct SolidAdministrationPlan: Equatable {
    let rawUnits: Double
    let roundedUnits: Double
    let deliveredMg: Double
    let targetMg: Double

    var variancePercent: Double {
        guard targetMg > 0 else { return 0 }
        return ((deliveredMg - targetMg) / targetMg) * 100
    }
}

enum AdministrationMath {
    static func interpolate(_ low: Double, _ high: Double, level: DoseSelectionLevel) -> Double {
        low + ((high - low) * level.fraction)
    }

    static func selection(for medication: Medication, kg: Double, level: DoseSelectionLevel) -> DoseRangeSelection? {
        guard medication.kind != .protocolOnly,
              MedicationSafety.positiveFinite(kg),
              (MedicationSafety.validRange(low: medication.minDose, high: medication.maxDose) || medication.kind == .robenacoxibCatBand) else { return nil }

        if medication.kind == .robenacoxibCatBand {
            guard kg >= 2.5 && kg <= 12 else { return nil }
            let mg = kg <= 6 ? 6.0 : 12.0
            return DoseRangeSelection(low: mg, high: mg, selected: mg, unit: "mg", math: "Labeled weight band", isRate: false)
        }

        if medication.generic == "Mirtazapine transdermal" && medication.brand == "Mirataz" {
            return DoseRangeSelection(low: 2, high: 2, selected: 2, unit: "mg", math: "Fixed labeled dose", isRate: false)
        }

        guard kg > 0 else { return nil }
        let highDose = medication.maxDose > 0 ? medication.maxDose : medication.minDose
        let low: Double
        let high: Double
        let math: String

        switch medication.kind {
        case .fixedMg:
            low = medication.minDose
            high = highDose
            math = "Fixed dose"
        case .mgLb:
            let lb = ClinicalData.kgToLb(kg)
            low = medication.minDose * lb
            high = highDose * lb
            math = "\(ClinicalData.format(lb)) lb × selected mg/lb"
        case .mgKg:
            low = medication.minDose * kg
            high = highDose * kg
            math = "\(ClinicalData.format(kg)) kg × selected mg/kg"
        default:
            return nil
        }

        let selected = interpolate(low, high, level: level)
        guard MedicationSafety.positiveFinite(low), MedicationSafety.positiveFinite(high),
              MedicationSafety.positiveFinite(selected), high >= low else { return nil }
        return DoseRangeSelection(
            low: low,
            high: high,
            selected: selected,
            unit: "mg",
            math: math,
            isRate: false
        )
    }

    static func selection(for definition: ProtocolMedicationDefinition, kg: Double, level: DoseSelectionLevel) -> DoseRangeSelection? {
        guard definition.validationIssue == nil, definition.veterinarianApproved,
              kg.isFinite, kg >= 0 else { return nil }
        guard MedicationSafety.protocolEligibilityIssue(key: definition.medicationKey, kg: kg) == nil else { return nil }
        let basis = definition.doseBasis
        guard !basis.requiresWeight || kg > 0 else { return nil }
        let maxDose = definition.maxDose > 0 ? definition.maxDose : definition.minDose
        let low: Double
        var high: Double
        let math: String

        switch basis {
        case .mgKg, .unitsKg, .mcgKg, .mEqKg, .mLKg, .gKg:
            low = definition.minDose * kg
            high = maxDose * kg
            math = "\(ClinicalData.format(kg)) kg × selected \(basis.rawValue)"
        case .mgM2:
            let constant = definition.species == .dog ? 0.101 : 0.100
            let bsa = constant * pow(kg, 2.0 / 3.0)
            low = definition.minDose * bsa
            high = maxDose * bsa
            math = "BSA \(ClinicalData.format(bsa)) m² × selected mg/m²"
        case .mgLb:
            let lb = ClinicalData.kgToLb(kg)
            low = definition.minDose * lb
            high = maxDose * lb
            math = "\(ClinicalData.format(lb)) lb × selected mg/lb"
        case .fixedMg, .fixedUnits, .dropsEye, .ribbonInch:
            low = definition.minDose
            high = maxDose
            math = "Selected fixed-dose protocol"
        case .mcgKgMin:
            low = definition.minDose * kg
            high = maxDose * kg
            math = "\(ClinicalData.format(kg)) kg × selected mcg/kg/min"
        case .mgKgHr, .mEqKgHr:
            low = definition.minDose * kg
            high = maxDose * kg
            math = "\(ClinicalData.format(kg)) kg × selected \(basis.rawValue)"
        }

        if let ceiling = MedicationSafety.maximumProtocolAmount(key: definition.medicationKey) {
            guard low <= ceiling else { return nil }
            high = min(high, ceiling)
        }
        let unit: String
        switch basis {
        case .mcgKgMin: unit = "mcg/min"
        case .mgKgHr: unit = "mg/hr"
        case .mEqKgHr: unit = "mEq/hr"
        default: unit = basis.amountUnit
        }

        let selected = interpolate(low, high, level: level)
        guard MedicationSafety.positiveFinite(low), MedicationSafety.positiveFinite(high),
              MedicationSafety.positiveFinite(selected), high >= low else { return nil }
        return DoseRangeSelection(
            low: low,
            high: high,
            selected: selected,
            unit: unit,
            math: math,
            isRate: basis.isRate
        )
    }

    static func solidPlan(targetMg: Double, strengthMg: Double, rounding: SolidDoseRounding) -> SolidAdministrationPlan? {
        guard MedicationSafety.positiveFinite(targetMg), MedicationSafety.positiveFinite(strengthMg) else { return nil }
        let raw = targetMg / strengthMg
        guard MedicationSafety.positiveFinite(raw) else { return nil }
        let roundingInput = MedicationSafety.snapIntegerBoundary(raw)
        let rounded: Double
        switch rounding {
        case .down: rounded = floor(roundingInput)
        case .nearest: rounded = roundingInput.rounded(.toNearestOrAwayFromZero)
        case .up: rounded = ceil(roundingInput)
        }
        guard rounded.isFinite, (rounded * strengthMg).isFinite else { return nil }
        return SolidAdministrationPlan(
            rawUnits: raw,
            roundedUnits: rounded,
            deliveredMg: rounded * strengthMg,
            targetMg: targetMg
        )
    }

    static func volume(selection: DoseRangeSelection, basis: ProtocolDoseBasis?, concentration: Double?) -> (value: Double, unit: String)? {
        guard MedicationSafety.positiveFinite(selection.selected) else { return nil }
        if basis == .mLKg { return (selection.selected, "mL") }
        if basis == .dropsEye { return (selection.selected, "drop(s)/eye") }
        if basis == .ribbonInch { return nil } // Ointment length is not a liquid volume.
        guard let concentration, MedicationSafety.positiveFinite(concentration) else { return nil }
        let value: Double
        let unit: String
        switch basis {
        case .mcgKgMin:
            value = ((selection.selected / 1000) * 60) / concentration; unit = "mL/hr"
        case .mgKgHr, .mEqKgHr:
            value = selection.selected / concentration; unit = "mL/hr"
        case .mcgKg:
            value = (selection.selected / 1000) / concentration; unit = "mL"
        case .gKg:
            value = (selection.selected * 1000) / concentration; unit = "mL"
        default:
            value = selection.selected / concentration; unit = "mL"
        }
        guard MedicationSafety.positiveFinite(value) else { return nil }
        return (value, unit)
    }

    static func administrations(days: Int, dosesPerDay: Double) -> Int {
        guard days > 0, MedicationSafety.positiveFinite(dosesPerDay) else { return 0 }
        let count = ceil(MedicationSafety.snapIntegerBoundary(Double(days) * dosesPerDay))
        guard count.isFinite, count > 0, count < Double(Int.max) else { return 0 }
        return Int(count)
    }
}

