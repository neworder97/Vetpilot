import Foundation

/// Arithmetic/input safeguards, not clinical approval of a drug or protocol.
enum MedicationSafety {
    static let posix = Locale(identifier: "en_US_POSIX")

    static func positiveFinite(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    /// A zero upper bound is the legacy representation for an omitted upper bound.
    static func validRange(low: Double, high: Double) -> Bool {
        positiveFinite(low) && high.isFinite && (high == 0 || high >= low)
    }

    static func optionalPositive(_ value: Double?) -> Bool {
        value.map(positiveFinite) ?? true
    }

    /// Decimal point only: ambiguous comma/grouping input is rejected, never guessed.
    static func parsePositive(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(","),
              let result = Double(value), positiveFinite(result) else { return nil }
        return result
    }

    /// Round-trip representation for edit controls; do not use a display formatter here.
    static func input(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let text = String(value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    static func display(_ value: Double) -> String {
        guard value.isFinite else { return "Invalid number" }
        if value == 0 { return "0" }
        if abs(value) < 1e-9 || abs(value) >= 1e12 {
            return String(format: "%.10g", locale: posix, value)
        }
        let formatter = NumberFormatter()
        formatter.locale = posix
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 1
        formatter.maximumSignificantDigits = 10
        formatter.minimumIntegerDigits = 1
        let text = formatter.string(from: NSNumber(value: value)) ?? input(value)
        return Double(text) == 0 ? input(value) : text
    }

    /// Only absorbs binary floating-point noise within eight ULPs of an integer.
    /// A clinically meaningful fraction (e.g. 1.000000001) is not snapped.
    static func snapIntegerBoundary(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let nearest = value.rounded(.toNearestOrAwayFromZero)
        let tolerance = 8 * max(value.ulp, nearest.ulp)
        return abs(value - nearest) <= tolerance ? nearest : value
    }

    /// Absorb only binary noise at half-unit ties before nearest-whole rounding.
    static func snapHalfBoundary(_ value: Double) -> Double {
        let doubled = value * 2
        return doubled.isFinite ? snapIntegerBoundary(doubled) / 2 : value
    }

    static func dailyTotal(_ frequency: String) -> Bool {
        let value = frequency.lowercased()
        return value.contains("total daily dose") || value.contains("total daily amount")
    }

    /// Only parse a single unambiguous regular schedule. Alternative, PRN,
    /// titration, loading and weekly-cycle schedules require an explicit plan.
    static func regularDosesPerDay(_ frequency: String) -> Double? {
        let value = frequency.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "total daily dose divided into 2 portions ~12h apart" { return 2 }
        if value == "q24h total daily dose; may divide q12h" { return 1 }
        let pattern = #"^q(4|6|8|12|24|48|72)h(?: (?:total daily dose|after day 1|after initial phase|per label|induction|with food|in the morning|\(every other day\)|(?:for )?(?:up to )?[0-9]+ days))?$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value),
              let hours = Double(value[range]), hours > 0 else { return nil }
        return 24 / hours
    }

    static func perAdministration(_ selection: DoseRangeSelection, frequency: String,
                                  dosesPerDay: Double?) -> DoseRangeSelection? {
        guard dailyTotal(frequency) else { return selection }
        guard let count = dosesPerDay, positiveFinite(count), count >= 1 else { return nil }
        let low = selection.low / count, high = selection.high / count
        let selected = selection.selected / count
        guard positiveFinite(low), positiveFinite(high), positiveFinite(selected) else { return nil }
        return DoseRangeSelection(low: low, high: high, selected: selected, unit: selection.unit,
            math: "Daily amount divided by \(display(count)) administrations/day", isRate: false)
    }

    static func withinRange(_ amount: Double, _ selection: DoseRangeSelection) -> Bool {
        guard positiveFinite(amount) else { return false }
        let tolerance = max(abs(selection.low), abs(selection.high)) * 1e-12
        return amount >= selection.low - tolerance && amount <= selection.high + tolerance
    }

    static func enteredRangeIsValid(low: String, high: String, concentration: String) -> Bool {
        guard let minimum = parsePositive(low) else { return false }
        let highText = high.trimmingCharacters(in: .whitespacesAndNewlines)
        if !highText.isEmpty {
            guard let maximum = parsePositive(highText), maximum >= minimum else { return false }
        }
        return concentration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            parsePositive(concentration) != nil
    }
}

struct LabeledTabletPlan: Equatable {
    let strengthMg: Double
    let units: Double
    let band: String
    var deliveredMg: Double { strengthMg * units }
}

extension MedicationSafety {
    /// DailyMed GALLIPRANT label updated 2025-08-11, reviewed 2026-09-22.
    /// https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a38cc5c6-93e8-4c90-aabc-33bc8423beab
    /// Match the printed table in the entered unit; do not invent cutoffs in
    /// gaps between the printed bands or extrapolate beyond the table.
    static func galliprantPlan(weight: Double, unit: String) -> LabeledTabletPlan? {
        guard positiveFinite(weight), unit == "kg" || unit == "lb" else { return nil }
        let kg: [(Double, Double, Double, Double)] = [
            (3.6, 6.8, 20, 0.5), (6.9, 13.6, 20, 1), (13.7, 20.4, 60, 0.5),
            (20.5, 34, 60, 1), (34.1, 68, 100, 1)
        ]
        let lb: [(Double, Double, Double, Double)] = [
            (8, 15, 20, 0.5), (15.1, 30, 20, 1), (30.1, 45, 60, 0.5),
            (45.1, 75, 60, 1), (75.1, 150, 100, 1)
        ]
        guard let row = (unit == "kg" ? kg : lb).first(where: { weight >= $0.0 && weight <= $0.1 }) else { return nil }
        return LabeledTabletPlan(strengthMg: row.2, units: row.3, band: "\(display(row.0))–\(display(row.1)) \(unit)")
    }
}

extension MedicationSafety {
    /// Treat an explicitly documented duration as a ceiling for this entry.
    /// This is not evidence that a shorter course is clinically appropriate.
    static func documentedDaysCeiling(_ frequency: String) -> Int? {
        let pattern = #"(?:for\s+(?:up to\s+)?|up to\s+|×\s*)([1-9][0-9]*)\s*days"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.firstMatch(in: frequency, range: NSRange(frequency.startIndex..., in: frequency)),
              let range = Range(match.range(at: 1), in: frequency) else { return nil }
        return Int(frequency[range])
    }
}

extension MedicationSafety {
    /// Product-specific insulin protocols cannot be reused with another strength.
    /// Glargine U-300 has different pharmacokinetics from U-100; PZI is U-40.
    static func insulinConcentrationIssue(presetID: String?, concentration: Double?) -> String? {
        guard let id = presetID else { return nil }
        let expected: Double
        if id.hasPrefix("insulin-glargine-") { expected = 100 }
        else if id.hasPrefix("insulin-pzi-") { expected = 40 }
        else { return nil }
        guard let entered = concentration, positiveFinite(entered), entered == expected else {
            return "This insulin protocol requires U-\(Int(expected)) (\(display(expected)) units/mL). A different insulin strength needs its own reviewed product-specific protocol and matched delivery device."
        }
        return nil
    }
}

extension MedicationSafety {
    static func builtinID(_ key: String) -> String? {
        key.hasPrefix("builtin|") ? String(key.dropFirst(8)) : nil
    }

    static func requiresEligibilityWeight(key: String) -> Bool {
        guard let id = builtinID(key) else { return false }
        return id.hasPrefix("digoxin-cat-") || id.hasPrefix("mirtazapine-oral-dog-")
    }

    static func protocolEligibilityIssue(key: String, kg: Double) -> String? {
        guard let id = builtinID(key) else { return nil }
        if ["ampicillin-sulbactam-dog-2", "ampicillin-sulbactam-cat-2"].contains(id) {
            return "This CRI reference does not establish whether mg means combined drug or ampicillin alone. Use an individually reviewed protocol with an explicit mass convention and final infusion preparation."
        }
        if id == "cyclophosphamide-cat-1" {
            return "The source specifies a cyclophosphamide total across days 1 and 3, not an amount for each day. An oncologist must supply an explicit divided-dose order before calculation."
        }
        if id == "levetiracetam-cat-2" {
            return "Feline extended-release levetiracetam needs a specialist-selected regimen and intact-tablet assessment. The cited general dog/cat summary does not establish this preset for cats."
        }
        let eligible: Bool
        switch id {
        case "doxorubicin-dog-1": eligible = positiveFinite(kg) && kg > 10
        case "doxorubicin-dog-2": eligible = positiveFinite(kg) && kg <= 10
        case "digoxin-cat-1": eligible = positiveFinite(kg) && kg < 3
        case "digoxin-cat-2": eligible = positiveFinite(kg) && kg >= 3 && kg <= 6
        case "digoxin-cat-3": eligible = positiveFinite(kg) && kg > 6
        case "mirtazapine-oral-dog-1": eligible = positiveFinite(kg) && kg < 7
        case "mirtazapine-oral-dog-2": eligible = positiveFinite(kg) && kg > 7 && kg <= 15
        case "mirtazapine-oral-dog-3": eligible = positiveFinite(kg) && kg > 15 && kg <= 30
        case "mirtazapine-oral-dog-4": eligible = positiveFinite(kg) && kg > 30
        default: return nil
        }
        // The source leaves exactly 7 kg unspecified; do not invent a band.
        return eligible ? nil : "Enter a valid weight and select the matching protocol weight band. Source boundary gaps require an individually reviewed regimen."
    }

    static func maximumProtocolAmount(key: String) -> Double? {
        switch builtinID(key) {
        case "digoxin-dog-1": return 0.25
        case "praziquantel-dog-1": return 170
        default: return nil
        }
    }
}

extension MedicationSafety {
    /// SIMBADOL's labeled feline regimen is formulation-specific.
    /// Conventional immediate-dose presets intentionally name 0.3 mg/mL.
    /// CRI presets use a separately prepared final infusion concentration.
    static func buprenorphineConcentrationIssue(presetID: String?, concentration: Double?) -> String? {
        let expected: Double
        switch presetID {
        case "buprenorphine-cat-4": expected = 1.8
        case "buprenorphine-dog-1", "buprenorphine-dog-2",
             "buprenorphine-cat-1", "buprenorphine-cat-2": expected = 0.3
        default: return nil
        }
        guard let c = concentration, positiveFinite(c), c == expected else {
            return "This buprenorphine product-specific regimen requires \(display(expected)) mg/mL. Select a separately reviewed regimen for another product; concentration substitution alone is not sufficient."
        }
        return nil
    }
}


extension MedicationSafety {
    static func requiresPrescribedPotassiumRate(key: String) -> Bool {
        guard let id = builtinID(key) else { return false }
        return id == "potassium-chloride-dog-1" || id == "potassium-chloride-cat-1"
    }

    static func validPotassiumRate(_ rate: Double?) -> Bool {
        guard let rate else { return false }
        return positiveFinite(rate) && rate <= 0.5
    }
}
