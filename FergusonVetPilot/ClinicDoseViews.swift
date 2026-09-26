import SwiftUI

/// Clinic-prescribed arithmetic. These inputs do not establish a universal clinical regimen.
enum ClinicDoseMath {
    static func gabapentin(weight: Double, pounds: Bool, dose: Double, strength: Double?) -> (kg: Double, mg: Double, quantity: Double?)? {
        guard weight.isFinite, weight > 0, [15.0,25,30,50].contains(dose) else { return nil }
        let kg = weight * (pounds ? 0.45359237 : 1), mg = kg * dose
        guard mg.isFinite, mg > 0 else { return nil }
        if let strength, (!strength.isFinite || strength <= 0) { return nil }
        let quantity = strength.map { mg / $0 }
        if let quantity, (!quantity.isFinite || quantity <= 0) { return nil }
        return (kg, mg, quantity)
    }
    static func course(quantity: Double, hours: Int, days: Int) -> (administrations: Int, units: Double)? {
        guard quantity.isFinite, quantity > 0, [6,8,12,24].contains(hours), (1...3650).contains(days) else { return nil }
        let administrations = days * (24 / hours), units = quantity * Double(administrations)
        guard units.isFinite, units > 0 else { return nil }
        return (administrations, units)
    }
    static func roundedUnits(quantity: Double, mode: String) -> Double? {
        guard quantity.isFinite, quantity > 0 else { return nil }
        let q = MedicationSafety.snapIntegerBoundary(quantity)
        switch mode {
        case "Round down": return floor(q)
        case "Round up": return ceil(q)
        case "Nearest whole": return MedicationSafety.snapHalfBoundary(quantity).rounded()
        default: return quantity
        }
    }
    static func buprenorphine(weight: Double, pounds: Bool, dose: Double, perKg: Bool) -> (mg: Double, ml: Double)? {
        guard weight.isFinite, weight > 0, dose.isFinite, dose > 0 else { return nil }
        let kg = weight * (pounds ? 0.45359237 : 1)
        let mg = perKg ? dose * kg : dose, ml = mg / 0.6
        guard mg.isFinite, ml.isFinite, mg > 0, ml > 0 else { return nil }
        return (mg, ml)
    }
}

struct ClinicGabapentinView: View {
    let species: Species
    @State var weight: String
    @State var unit: String
    var lockedForm: String? = nil
    @State private var purpose = "Pain"
    @State private var sedation = 0.0
    @State private var strength = ""
    @State private var formulation = "Capsule"
    @State private var interval = 0
    @State private var days = ""
    @State private var rounding = "Exact math"
    @State private var calculateRequested = 0
    private var selectedForm: String { lockedForm ?? formulation }
    private var listedStrengths: [Int] { selectedForm == "Capsule" ? [100,200,300,400] : [600,800] }
    @Environment(\.dismiss) private var dismiss
    private var dose: Double { purpose == "Pain" ? 15 : purpose == "Fractious" ? 50 : sedation }
    private var calculation: (kg: Double, mg: Double, quantity: Double?)? {
        ClinicDoseMath.gabapentin(weight: Double(weight) ?? 0, pounds: unit == "lb", dose: dose,
            strength: strength.isEmpty ? nil : Double(strength) ?? 0)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Gabapentin · \(species.rawValue)") {
                    Text("Clinic protocol — veterinarian approved as reported by the user. Confirm the prescription for this patient.").font(.footnote)
                    Picker("Purpose", selection: $purpose) {
                        Text("Pain").tag("Pain")
                        Text("Mild sedation").tag("Mild sedation")
                        Text("Fractious").tag("Fractious")
                    }.pickerStyle(.segmented).accessibilityIdentifier("gabapentin.purpose")
                    Text("Pain: 15 mg/kg · Mild sedation: 25–30 mg/kg · Fractious: 50 mg/kg").font(.caption)
                    if purpose == "Mild sedation" {
                        Picker("Prescribed sedation dose", selection: $sedation) {
                            Text("Choose").tag(0.0)
                            Text("25 mg/kg").tag(25.0)
                            Text("30 mg/kg").tag(30.0)
                        }.pickerStyle(.segmented).accessibilityIdentifier("gabapentin.sedation")
                    }
                }
                Section("Patient and formulation") {
                    TextField("Patient weight", text: $weight).keyboardType(.decimalPad).accessibilityIdentifier("dose.sheet.weight")
                    Picker("Weight unit", selection: $unit) { Text("lb").tag("lb"); Text("kg").tag("kg") }.pickerStyle(.segmented)
                    if let lockedForm { Text("Formulation: \(lockedForm)") } else {
                        Picker("Formulation", selection: $formulation) { Text("Capsule").tag("Capsule"); Text("Tablet").tag("Tablet") }.pickerStyle(.segmented)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
                        ForEach(listedStrengths, id: \.self) { mg in
                            Button("\(mg) mg") { strength = String(mg) }
                                .buttonStyle(.bordered).tint(strength == String(mg) ? AppTheme.blue : .secondary)
                                .accessibilityIdentifier("gabapentin.strength.\(mg)")
                        }
                    }
                    TextField("Verified strength (mg per unit)", text: $strength).keyboardType(.decimalPad).accessibilityIdentifier("gabapentin.strength")
                    Text("Oral (PO) · immediate-release products only")
                    Link("RELGAABI capsule label, including 200 mg", destination: URL(string: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4cc6615b-5447-9c0e-e063-6394a90a2883")!).font(.caption)
                }
                Section("Tablet / capsule rounding") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        ForEach(["Exact math", "Round down", "Nearest whole", "Round up"], id: \.self) { mode in
                            Button(mode) { rounding = mode }.buttonStyle(.bordered)
                                .tint(rounding == mode ? AppTheme.blue : .secondary)
                                .accessibilityIdentifier("gabapentin.rounding." + mode)
                        }
                    }
                }
                Section("Frequency") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        Button("Recommended") { interval = 0 }.buttonStyle(.bordered).tint(interval == 0 ? AppTheme.blue : .secondary)
                        ForEach([6,8,12,24], id: \.self) { hours in
                            Button("Every \(hours) h") { interval = hours }.buttonStyle(.bordered).tint(interval == hours ? AppTheme.blue : .secondary)
                                .accessibilityIdentifier("gabapentin.frequency.q\(hours)h")
                        }
                    }
                    Text(interval == 0 ? "As prescribed — no administration interval was supplied for this clinic protocol. Select the veterinarian's schedule to calculate a course quantity." : "Prescriber-selected schedule: every \(interval) hours. Confirm the schedule and duration for this patient; sedation and pre-visit dosing are not automatically repeating regimens.").font(.footnote)
                }
                Section("Quantity / treatment duration") {
                    HStack { ForEach([7,14,30], id: \.self) { value in
                        Button("\(value) days") { days = String(value) }.buttonStyle(.bordered).tint(days == String(value) ? AppTheme.blue : .secondary)
                    } }
                    TextField("Prescribed course length (days)", text: $days).keyboardType(.numberPad).accessibilityIdentifier("gabapentin.days")
                }
                Section {
                    Button("Calculate dose") {
                        calculateRequested += 1
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("gabapentin.calculate")
                    if calculateRequested > 0 {
                        Text(calculation == nil ? "Enter a positive weight and select the prescribed dose; verify any entered strength." : "Calculation updated from current inputs.")
                            .accessibilityIdentifier("gabapentin.calculate.status")
                    }
                }
                Section("Automatic calculation") {
                    if let c = calculation {
                        Text("\(MedicationSafety.display(c.mg)) mg").font(.title2.bold()).accessibilityIdentifier("gabapentin.amount")
                        Text("\(MedicationSafety.display(c.kg)) kg × \(MedicationSafety.display(dose)) mg/kg = \(MedicationSafety.display(c.mg)) mg")
                        if let quantity = c.quantity {
                            Text("\(MedicationSafety.display(quantity)) \(selectedForm.lowercased())(s) at \(strength) mg each").accessibilityIdentifier("gabapentin.quantity")
                            Text("Quantity = \(MedicationSafety.display(c.mg)) mg ÷ \(strength) mg. Exact mathematical quantity; confirm permitted tablet splitting. Do not interpret a fractional capsule as an instruction to divide its contents.").font(.footnote)
                            if let units = ClinicDoseMath.roundedUnits(quantity: quantity, mode: rounding) {
                                let delivered = units * (Double(strength) ?? 0)
                                let matches = delivered > 0 && abs(delivered - c.mg) <= max(1e-9, c.mg * 1e-12)
                                if rounding != "Exact math" {
                                    Text("Rounded dose candidate").font(.headline)
                                    Text("\(MedicationSafety.display(units)) whole \(selectedForm.lowercased())(s) per administration · \(MedicationSafety.display(delivered)) mg · \(MedicationSafety.display(delivered / c.kg)) mg/kg")
                                        .accessibilityIdentifier("gabapentin.rounded.amount")
                                    Text(matches ? "Matches the selected prescribed amount." : "Outside the selected prescribed amount. Veterinarian review is required before using this rounded dose.")
                                    if units == 0 { Text("Zero whole units is not an administration plan. Choose another verified strength.") }
                                }
                                if let course = ClinicDoseMath.course(quantity: units, hours: interval, days: Int(days) ?? 0) {
                                    if matches, let summary = PrescriptionSummary.text(amount: units, unit: selectedForm.lowercased(), route: "PO", hours: Double(interval), days: Int(days) ?? 0) {
                                        Text("Administration and quantity").font(.headline)
                                        Text(summary).accessibilityIdentifier("gabapentin.administration.summary")
                                    }
                                    if rounding == "Exact math" {
                                        Text("Course: \(course.administrations) administrations · \(MedicationSafety.display(course.units)) \(selectedForm.lowercased()) equivalents in total").accessibilityIdentifier("gabapentin.course")
                                        Text("Exact course arithmetic before dispensing rounding. Verify the actual administered units and prescribed duration.").font(.footnote)
                                    } else {
                                        Text("Candidate quantity: \(MedicationSafety.display(course.units)) whole \(selectedForm.lowercased())(s) for \(days) days at every \(interval) hours. \(matches ? "" : "Not an approved dispensing instruction.")")
                                            .accessibilityIdentifier("gabapentin.rounded.course")
                                    }
                                } else if !days.isEmpty && units != 0 { Text("Select the prescribed frequency and a whole number of days (1–3650) to calculate course quantity.").font(.footnote) }
                            }
                        } else { Text("Enter verified strength to calculate tablets/capsules.") }
                    } else { Text(dose == 0 ? "Select the prescribed 25 or 30 mg/kg dose." : "Enter a positive weight and, if supplied, a positive strength.") }
                }
                Section("Source") { Text("User-reported treating veterinarian clinic protocol for dogs and cats, oral capsules/tablets. No administration interval supplied.").font(.footnote) }
            }
            .onChange(of: formulation) { _, _ in strength = "" }
            .onChange(of: purpose) { _, _ in interval = 0; days = "" }
            .navigationTitle("Gabapentin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("dose.done") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("dose.keyboard.done") }
            }
        }
    }
}

struct PrescribedBuprenorphineView: View {
    let species: Species
    @State private var weight = ""
    @State private var unit = "kg"
    @State private var dose = ""
    @State private var basis = "mg/kg"
    @State private var product = ""
    @State private var route = ""
    @State private var frequency = ""
    @State private var courseDays = ""
    @State private var verified = false
    @State private var calculateRequested = 0
    @Environment(\.dismiss) private var dismiss
    private var complete: Bool { verified && [product,route,frequency].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Buprenorphine · 0.6 mg/mL injectable") {
                    Text("Prescribed-dose conversion for \(species.rawValue). Verify the product, release type and prescription. This does not select a clinical dose or establish equivalence to other formulations.").font(.footnote)
                    TextField("Product / pharmacy and release type", text: $product)
                    TextField("Patient weight", text: $weight).keyboardType(.decimalPad)
                    Picker("Weight unit", selection: $unit) { Text("kg").tag("kg"); Text("lb").tag("lb") }.pickerStyle(.segmented)
                    Picker("Prescribed dose basis", selection: $basis) { Text("mg/kg").tag("mg/kg"); Text("Total mg").tag("mg") }.pickerStyle(.segmented)
                    TextField("Prescribed dose", text: $dose).keyboardType(.decimalPad)
                    TextField("Prescribed route", text: $route)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        Button("Recommended") { frequency = "" }.buttonStyle(.bordered)
                        ForEach([6,8,12,24], id: \.self) { hours in
                            Button("Every \(hours) h") { frequency = "q\(hours)h" }.buttonStyle(.bordered).tint(frequency == "q\(hours)h" ? AppTheme.blue : .secondary)
                        }
                    }
                    Text("No recommended interval is assigned to this concentration. Use the veterinarian's exact order.").font(.footnote)
                    TextField("Prescribed frequency / timing", text: $frequency)
                    HStack { ForEach([7,14,30], id: \.self) { value in
                        Button("\(value) days") { courseDays = String(value) }.buttonStyle(.bordered)
                    } }
                    TextField("Prescribed course length (days)", text: $courseDays).keyboardType(.numberPad)
                    LabeledContent("Verified concentration", value: "0.6 mg/mL")
                    Toggle("Product, release type and prescription verified", isOn: $verified)
                }
                Section {
                    Button("Calculate dose / volume") {
                        calculateRequested += 1
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("buprenorphine.calculate")
                    if calculateRequested > 0 { Text("The calculation below uses the current verified prescription inputs.") }
                }
                Section("Automatic conversion") {
                    if complete, let c = ClinicDoseMath.buprenorphine(weight: Double(weight) ?? 0, pounds: unit == "lb", dose: Double(dose) ?? 0, perKg: basis == "mg/kg") {
                        Text("\(MedicationSafety.display(c.ml)) mL").font(.title2.bold())
                        Text("\(MedicationSafety.display(c.mg)) mg ÷ 0.6 mg/mL = \(MedicationSafety.display(c.ml)) mL")
                        Text("Prescription: \(dose) \(basis) · \(route) · \(frequency)")
                        if let hours = [6,8,12,24].first(where: { frequency == "q\($0)h" }), let course = ClinicDoseMath.course(quantity: c.ml, hours: hours, days: Int(courseDays) ?? 0) {
                            if let summary = PrescriptionSummary.text(amount: c.ml, unit: "mL", route: route, hours: Double(hours), days: Int(courseDays) ?? 0) {
                                Text("Administration and quantity").font(.headline)
                                Text(summary).accessibilityIdentifier("buprenorphine.administration.summary")
                            }
                            Text("Course quantity: \(MedicationSafety.display(course.units)) mL · \(course.administrations) administrations. Exact arithmetic for the verified repeating prescription.")
                        } else if !courseDays.isEmpty { Text("Course volume needs an explicit repeating schedule and a whole number of days (1–3650).") }
                    } else { Text("Complete and verify the product and prescription with positive weight and dose to calculate.") }
                }
            }
            .navigationTitle("Prescribed conversion")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onChange(of: product) { _, _ in verified = false }
            .onChange(of: dose) { _, _ in verified = false }
            .onChange(of: basis) { _, _ in verified = false }
            .onChange(of: route) { _, _ in verified = false }
            .onChange(of: frequency) { _, _ in verified = false }
            .onChange(of: courseDays) { _, _ in verified = false }
        }
    }
}
