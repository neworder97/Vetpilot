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
    @State private var purpose = "Pain"
    @State private var sedation = 0.0
    @State private var strength = ""
    @State private var formulation = "Capsule"
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
                    Picker("Formulation", selection: $formulation) { Text("Capsule").tag("Capsule"); Text("Tablet").tag("Tablet") }.pickerStyle(.segmented)
                    TextField("Verified strength (mg per unit)", text: $strength).keyboardType(.decimalPad).accessibilityIdentifier("gabapentin.strength")
                    Text("Oral (PO) · Frequency / timing: As prescribed")
                }
                Section("Automatic calculation") {
                    if let c = calculation {
                        Text("\(MedicationSafety.display(c.mg)) mg").font(.title2.bold()).accessibilityIdentifier("gabapentin.amount")
                        Text("\(MedicationSafety.display(c.kg)) kg × \(MedicationSafety.display(dose)) mg/kg = \(MedicationSafety.display(c.mg)) mg")
                        if let quantity = c.quantity {
                            Text("\(MedicationSafety.display(quantity)) \(formulation.lowercased())(s) at \(strength) mg each").accessibilityIdentifier("gabapentin.quantity")
                            Text("Quantity = \(MedicationSafety.display(c.mg)) mg ÷ \(strength) mg. Exact mathematical quantity; confirm permitted tablet splitting. Do not interpret a fractional capsule as an instruction to divide its contents.").font(.footnote)
                        } else { Text("Enter verified strength to calculate tablets/capsules.") }
                    } else { Text(dose == 0 ? "Select the prescribed 25 or 30 mg/kg dose." : "Enter a positive weight and, if supplied, a positive strength.") }
                }
                Section("Source") { Text("User-reported treating veterinarian clinic protocol for dogs and cats, oral capsules/tablets. No administration interval supplied.").font(.footnote) }
            }
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
    @State private var verified = false
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
                    TextField("Prescribed frequency / timing", text: $frequency)
                    LabeledContent("Verified concentration", value: "0.6 mg/mL")
                    Toggle("Product, release type and prescription verified", isOn: $verified)
                }
                Section("Automatic conversion") {
                    if complete, let c = ClinicDoseMath.buprenorphine(weight: Double(weight) ?? 0, pounds: unit == "lb", dose: Double(dose) ?? 0, perKg: basis == "mg/kg") {
                        Text("\(MedicationSafety.display(c.ml)) mL").font(.title2.bold())
                        Text("\(MedicationSafety.display(c.mg)) mg ÷ 0.6 mg/mL = \(MedicationSafety.display(c.ml)) mL")
                        Text("Prescription: \(dose) \(basis) · \(route) · \(frequency)")
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
        }
    }
}
