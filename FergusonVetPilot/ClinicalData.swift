import Foundation

enum Species: String, CaseIterable, Identifiable, Hashable {
    case dog = "Dog"
    case cat = "Cat"
    var id: String { rawValue }
}

enum MedicationForm: String, CaseIterable, Identifiable, Hashable {
    case any = "Any form"
    case tablet = "Tablet"
    case capsule = "Capsule"
    case liquid = "Liquid"
    case injection = "Injection"
    case transdermal = "Transdermal"
    case reference = "Reference"
    var id: String { rawValue }
}

enum DoseKind: Hashable {
    case mgKg
    case mgLb
    case fixedMg
    case robenacoxibCatBand
    case protocolOnly
}

struct Medication: Identifiable, Hashable {
    let id = UUID()
    let generic: String
    let brand: String
    let drugClass: String
    let species: Set<Species>
    let form: MedicationForm
    let indication: String
    let kind: DoseKind
    let minDose: Double
    let maxDose: Double
    let frequency: String
    let route: String
    let notes: String
    let source: String
    let strengths: [Double]
    let concentration: Double?
    let controlled: Bool
    var formulation: MedicationFormulation? = nil

    var displayName: String {
        let name = formulation.map { "\(generic) · \($0.label)" } ?? generic
        return brand.isEmpty ? name : "\(name) (\(brand))"
    }

    func supports(_ species: Species) -> Bool { self.species.contains(species) }
}

struct DoseResult {
    let available: Bool
    let headline: String
    let math: String
    let formulation: String
    let warning: String
}

struct BreedEntry: Identifiable {
    let id = UUID()
    let species: Species
    let name: String
    let conditions: String
    let note: String
}

enum ClinicalData {
    static func lbToKg(_ lb: Double) -> Double { lb * 0.45359237 }
    static func kgToLb(_ kg: Double) -> Double { kg / 0.45359237 }

    static func format(_ value: Double) -> String { MedicationSafety.display(value) }

    private static func trim(_ value: String) -> String {
        var result = value
        while result.contains(".") && result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    static func calculate(
        medication m: Medication,
        kg: Double,
        strength: Double?,
        concentration: Double?
    ) -> DoseResult {
        guard MedicationSafety.positiveFinite(kg) else {
            return DoseResult(available: false, headline: "Enter a valid weight", math: "", formulation: "", warning: "Weight must be greater than 0 kg.")
        }

        if m.kind == .protocolOnly {
            return DoseResult(
                available: false,
                headline: "Clinic protocol required",
                math: "No automatic equation is enabled for this entry.",
                formulation: "",
                warning: m.controlled
                    ? "Controlled/high-risk medication. Verify indication, patient factors, legal requirements, and clinic protocol."
                    : "Verify the current clinic formulary or an authoritative veterinary reference."
            )
        }

        guard MedicationSafety.validRange(low: m.minDose, high: m.maxDose) || m.kind == .robenacoxibCatBand,
              MedicationSafety.optionalPositive(strength),
              MedicationSafety.optionalPositive(concentration),
              MedicationSafety.optionalPositive(m.concentration),
              m.strengths.allSatisfy(MedicationSafety.positiveFinite) else {
            return DoseResult(available: false, headline: "Invalid medication inputs", math: "", formulation: "",
                warning: "Dose bounds, strengths and concentrations must be finite and positive. The upper dose cannot be below the lower dose.")
        }

        if m.kind == .robenacoxibCatBand {
            if kg < 2.5 {
                return DoseResult(available: false, headline: "Below labeled weight", math: "\(format(kg)) kg", formulation: "", warning: "Label applies to cats ≥2.5 kg and ≥4 months old.")
            } else if kg <= 6 {
                return DoseResult(available: true, headline: "1 × 6 mg tablet q24h", math: "Weight band 2.5–6.0 kg", formulation: "Whole 6 mg tablet; do not split.", warning: "Maximum labeled course: 3 days.")
            } else if kg <= 12 {
                return DoseResult(available: true, headline: "2 × 6 mg tablets q24h", math: "Weight band 6.1–12.0 kg", formulation: "Whole 6 mg tablets; do not split.", warning: "Maximum labeled course: 3 days.")
            }
            return DoseResult(available: false, headline: "Outside labeled chart", math: "\(format(kg)) kg", formulation: "", warning: "Do not extrapolate automatically above the cited weight chart.")
        }

        if m.generic == "Mirtazapine transdermal" && m.brand == "Mirataz" {
            return DoseResult(
                available: true,
                headline: "2 mg q24h ×14 days per label",
                math: "Fixed labeled dose = 2 mg/cat",
                formulation: "Apply the labeled 1.5-inch ribbon of ointment to the inner pinna. Use the label application length; do not convert the ointment to a liquid volume.",
                warning: m.notes
            )
        }

        let low: Double
        let high: Double

        switch m.kind {
        case .fixedMg:
            low = m.minDose
            high = m.maxDose > 0 ? m.maxDose : m.minDose
        case .mgLb:
            let lb = kgToLb(kg)
            low = m.minDose * lb
            high = (m.maxDose > 0 ? m.maxDose : m.minDose) * lb
        default:
            low = m.minDose * kg
            high = (m.maxDose > 0 ? m.maxDose : m.minDose) * kg
        }

        guard MedicationSafety.positiveFinite(low), MedicationSafety.positiveFinite(high), high >= low else {
            return DoseResult(available: false, headline: "Calculation outside numeric limits", math: "", formulation: "", warning: "No dose has been produced.")
        }

        let mg = abs(low - high) < 0.0000001
            ? "\(format(low)) mg"
            : "\(format(low))–\(format(high)) mg"

        let basis: String
        switch m.kind {
        case .fixedMg:
            basis = "Fixed labeled dose"
        case .mgLb:
            basis = "\(format(kg)) kg converted to lb × \(format(m.minDose))–\(format(m.maxDose)) mg/lb"
        default:
            basis = "\(format(kg)) kg × " + (
                abs(m.minDose - m.maxDose) < 0.0000001
                    ? "\(format(m.minDose)) mg/kg"
                    : "\(format(m.minDose))–\(format(m.maxDose)) mg/kg"
            )
        }

        var formulation = ""
        if [.liquid, .injection, .transdermal].contains(m.form) {
            let c = concentration ?? m.concentration
            if let c, c > 0 {
                let a = low / c
                let b = high / c
                guard MedicationSafety.positiveFinite(a), MedicationSafety.positiveFinite(b) else {
                    return DoseResult(available: false, headline: "Formulation outside numeric limits", math: "", formulation: "", warning: "Verify concentration/strength and weight; no administration amount is available.")
                }
                formulation = abs(a - b) < 0.0000001
                    ? "\(format(a)) mL at \(format(c)) mg/mL"
                    : "\(format(a))–\(format(b)) mL at \(format(c)) mg/mL"
            }
        } else if let strength, strength > 0 {
            let a = low / strength
            let b = high / strength
            guard MedicationSafety.positiveFinite(a), MedicationSafety.positiveFinite(b) else {
                return DoseResult(available: false, headline: "Formulation outside numeric limits", math: "", formulation: "", warning: "Verify concentration/strength and weight; no administration amount is available.")
            }
            formulation = abs(a - b) < 0.0000001
                ? "\(format(a)) unit(s) of \(format(strength)) mg; raw mathematical conversion—round only per label/protocol"
                : "\(format(a))–\(format(b)) unit(s) of \(format(strength)) mg; raw mathematical conversion—round only per label/protocol"
        }

        return DoseResult(
            available: true,
            headline: "\(mg) \(m.frequency)",
            math: "\(basis) = \(mg)",
            formulation: formulation,
            warning: m.controlled ? "Controlled/high-risk medication: calculation is not authorization to prescribe or dispense." : m.notes
        )
    }

    static let medications: [Medication] = {
        let dog: Set<Species> = [.dog]
        let cat: Set<Species> = [.cat]
        let both: Set<Species> = [.dog, .cat]
        let fda = "FDA Animal Drugs @ FDA"

        var r: [Medication] = [
            Medication(generic: "Carprofen", brand: "Rimadyl", drugClass: "NSAID", species: dog, form: .tablet, indication: "OA/postoperative pain", kind: .mgKg, minDose: 4.4, maxDose: 4.4, frequency: "q24h total daily dose", route: "PO", notes: "Label permits divided total daily dosing in some uses; screen NSAID risks.", source: "\(fda) NADA 141-053/141-199", strengths: [25,75,100], concentration: nil, controlled: false),
            Medication(generic: "Amoxicillin + clavulanate", brand: "Clavamox", drugClass: "Antimicrobial", species: dog, form: .tablet, indication: "Susceptible skin/soft-tissue infections", kind: .mgLb, minDose: 6.25, maxDose: 6.25, frequency: "q12h", route: "PO", notes: "Culture/susceptibility and duration matter.", source: "\(fda) NADA 55-099", strengths: [62.5,125,250,375], concentration: nil, controlled: false),
            Medication(generic: "Cefpodoxime proxetil", brand: "Simplicef", drugClass: "Cephalosporin", species: dog, form: .tablet, indication: "Susceptible skin infections", kind: .mgKg, minDose: 5, maxDose: 10, frequency: "q24h", route: "PO", notes: "Use antimicrobial stewardship.", source: "\(fda) NADA 141-232", strengths: [100,200], concentration: nil, controlled: false),
            Medication(generic: "Meloxicam", brand: "Metacam maintenance", drugClass: "NSAID", species: dog, form: .liquid, indication: "OA pain/inflammation", kind: .mgKg, minDose: 0.1, maxDose: 0.1, frequency: "q24h after day 1", route: "PO", notes: "Day-1 label dose is 0.2 mg/kg; this entry is maintenance.", source: "\(fda) NADA 141-213", strengths: [], concentration: 1.5, controlled: false),
            Medication(generic: "Meloxicam", brand: "Metacam day 1", drugClass: "NSAID", species: dog, form: .liquid, indication: "OA initial dose", kind: .mgKg, minDose: 0.2, maxDose: 0.2, frequency: "once day 1", route: "PO", notes: "Follow with labeled maintenance dose when appropriate.", source: "\(fda) NADA 141-213", strengths: [], concentration: 1.5, controlled: false),
            Medication(generic: "Maropitant citrate", brand: "Cerenia acute oral", drugClass: "NK1 antiemetic", species: dog, form: .tablet, indication: "Acute vomiting", kind: .mgKg, minDose: 2, maxDose: 2, frequency: "q24h", route: "PO", notes: "Do not confuse with motion-sickness dose.", source: "\(fda) NADA 141-263", strengths: [16,24,60,160], concentration: nil, controlled: false),
            Medication(generic: "Maropitant citrate", brand: "Cerenia motion sickness", drugClass: "NK1 antiemetic", species: dog, form: .tablet, indication: "Motion sickness", kind: .mgKg, minDose: 8, maxDose: 8, frequency: "q24h per label", route: "PO", notes: "Verify age and feeding instructions on current label.", source: "\(fda) NADA 141-263", strengths: [16,24,60,160], concentration: nil, controlled: false),
            Medication(generic: "Maropitant citrate", brand: "Cerenia Injectable", drugClass: "NK1 antiemetic", species: both, form: .injection, indication: "Acute vomiting", kind: .mgKg, minDose: 1, maxDose: 1, frequency: "q24h per label", route: "SC", notes: "Species and age restrictions differ; confirm current package insert.", source: "\(fda) NADA 141-263", strengths: [], concentration: 10, controlled: false),
            Medication(generic: "Mirtazapine transdermal", brand: "Mirataz", drugClass: "Appetite/weight management", species: cat, form: .transdermal, indication: "Management of weight loss", kind: .fixedMg, minDose: 2, maxDose: 2, frequency: "q24h ×14 days per label", route: "inner pinna", notes: "Fixed dose; alternate ears and use gloves per label.", source: "\(fda) NADA 141-481", strengths: [], concentration: nil, controlled: false),
            Medication(generic: "Deracoxib", brand: "Deramaxx", drugClass: "NSAID", species: dog, form: .tablet, indication: "OA pain/inflammation", kind: .mgKg, minDose: 1, maxDose: 2, frequency: "q24h", route: "PO", notes: "This is OA labeled range; postoperative protocols differ.", source: "\(fda) NADA 141-203", strengths: [12,25,75,100], concentration: nil, controlled: false),
            Medication(generic: "Firocoxib", brand: "Previcox", drugClass: "NSAID", species: dog, form: .tablet, indication: "Pain/inflammation", kind: .mgKg, minDose: 5, maxDose: 5, frequency: "q24h", route: "PO", notes: "Confirm indication, age, and NSAID risk factors.", source: "\(fda) NADA 141-230", strengths: [57,227], concentration: nil, controlled: false),
            Medication(generic: "Grapiprant", brand: "Galliprant", drugClass: "EP4 antagonist", species: dog, form: .tablet, indication: "OA pain/inflammation", kind: .mgKg, minDose: 2, maxDose: 2, frequency: "q24h", route: "PO", notes: "Label uses half-tablet increments; dogs <3.6 kg cannot be accurately dosed.", source: "\(fda) NADA 141-455", strengths: [20,60,100], concentration: nil, controlled: false),
            Medication(generic: "Robenacoxib", brand: "Onsior", drugClass: "NSAID", species: cat, form: .tablet, indication: "Postoperative pain/inflammation", kind: .robenacoxibCatBand, minDose: 1, maxDose: 1, frequency: "q24h up to 3 days", route: "PO", notes: "Whole-tablet weight-band dosing.", source: "\(fda) current cat tablet label", strengths: [6], concentration: nil, controlled: false),
            Medication(generic: "Cefovecin sodium", brand: "Convenia", drugClass: "Cephalosporin", species: both, form: .injection, indication: "Susceptible skin infections", kind: .mgKg, minDose: 8, maxDose: 8, frequency: "single injection per labeled indication", route: "SC", notes: "Repeat rules and indications vary by species; confirm label.", source: "\(fda) NADA 141-285", strengths: [], concentration: 80, controlled: false),
            Medication(generic: "Pradofloxacin", brand: "Veraflox", drugClass: "Fluoroquinolone", species: cat, form: .liquid, indication: "Susceptible bacterial infections", kind: .mgKg, minDose: 7.5, maxDose: 7.5, frequency: "q24h per label", route: "PO", notes: "Use fluoroquinolone stewardship; verify current label instructions.", source: "\(fda) NADA 141-344", strengths: [], concentration: 25, controlled: false),
            Medication(generic: "Oclacitinib", brand: "Apoquel initial", drugClass: "JAK inhibitor", species: dog, form: .tablet, indication: "Allergic dermatitis / atopic dermatitis — initial phase", kind: .mgKg, minDose: 0.4, maxDose: 0.6, frequency: "q12h for up to 14 days", route: "PO", notes: "For dogs at least 12 months old; review current immune-system and infection warnings.", source: "\(fda) NADA 141-345", strengths: [3.6,5.4,16], concentration: nil, controlled: false),
            Medication(generic: "Oclacitinib", brand: "Apoquel maintenance", drugClass: "JAK inhibitor", species: dog, form: .tablet, indication: "Atopic dermatitis — maintenance phase", kind: .mgKg, minDose: 0.4, maxDose: 0.6, frequency: "q24h after initial phase", route: "PO", notes: "For dogs at least 12 months old; review current immune-system and infection warnings.", source: "\(fda) NADA 141-345 / 141-555", strengths: [3.6,5.4,16], concentration: nil, controlled: false),
            Medication(generic: "Pimobendan", brand: "Vetmedin", drugClass: "Inodilator", species: dog, form: .tablet, indication: "CHF due to MMVD or DCM", kind: .mgKg, minDose: 0.5, maxDose: 0.5, frequency: "total daily dose divided into 2 portions ~12h apart", route: "PO", notes: "The label describes a 0.5 mg/kg total daily dose divided into two portions; veterinarian must confirm cardiac diagnosis and concurrent therapy.", source: "\(fda) NADA 141-273", strengths: [1.25,2.5,5,10], concentration: nil, controlled: false),
            Medication(generic: "Cyclosporine", brand: "Atopica induction", drugClass: "Immunomodulator", species: dog, form: .capsule, indication: "Canine atopic dermatitis — induction", kind: .mgKg, minDose: 5, maxDose: 5, frequency: "q24h induction", route: "PO", notes: "This entry represents the label-supported induction dose; maintenance frequency is individualized/tapered according to response.", source: "\(fda) NADA 141-218", strengths: [10,25,50,100], concentration: nil, controlled: false),
            Medication(generic: "Capromorelin", brand: "Entyce", drugClass: "Ghrelin receptor agonist", species: dog, form: .liquid, indication: "Appetite stimulation", kind: .mgKg, minDose: 3, maxDose: 3, frequency: "q24h", route: "PO", notes: "Current label advises caution in dogs with cardiac disease, severe dehydration, or diabetes; effectiveness in the original field study was not evaluated beyond 4 days.", source: "\(fda) NADA 141-457", strengths: [], concentration: 30, controlled: false),
            Medication(generic: "Capromorelin", brand: "Elura", drugClass: "Ghrelin receptor agonist", species: cat, form: .liquid, indication: "Management of weight loss in cats with chronic kidney disease", kind: .mgKg, minDose: 2, maxDose: 2, frequency: "q24h", route: "PO", notes: "Use only for the labeled feline CKD indication and review cardiovascular, hydration, hepatic, and glycemic precautions.", source: "\(fda) NADA 141-536", strengths: [], concentration: 20, controlled: false),
            Medication(generic: "Methimazole", brand: "Felimazole initial", drugClass: "Antithyroid", species: cat, form: .tablet, indication: "Feline hyperthyroidism — starting dose", kind: .fixedMg, minDose: 2.5, maxDose: 2.5, frequency: "q12h", route: "PO", notes: "Starting dose only. Recheck TT4, hematology, and chemistry and titrate in 2.5 mg increments according to the label and patient response.", source: "\(fda) NADA 141-292", strengths: [2.5,5], concentration: nil, controlled: false),
            Medication(generic: "Fluoxetine", brand: "Reconcile", drugClass: "SSRI", species: dog, form: .tablet, indication: "Canine separation anxiety with behavior modification", kind: .mgKg, minDose: 1, maxDose: 2, frequency: "q24h", route: "PO", notes: "Label indication requires use with a behavior-modification plan; monitor response and contraindications/interactions.", source: "\(fda) NADA 141-272", strengths: [8,16,32,64], concentration: nil, controlled: false)
        ]

        // Common extra-label medications with indication-specific dosing sourced to MSD Veterinary Manual.
        // These entries intentionally cover only the cited use; other indications remain protocol-dependent.
        r.append(Medication(generic: "Gabapentin", brand: "Neurontin", drugClass: "Anticonvulsant/analgesic", species: dog, form: .capsule, indication: "Canine chronic/neuropathic pain — MSD reference dose", kind: .mgKg, minDose: 10, maxDose: 15, frequency: "q8h", route: "PO", notes: "Extra-label veterinary use. This calculator is scoped to the cited canine chronic-pain reference only; renal function, sedation, concurrent CNS depressants, and indication can change the plan.", source: "MSD Veterinary Manual — Selected Analgesics for Use in Dogs (10–15 mg/kg PO q8h; accessed 2026-09-20)", strengths: [100,300,400,600,800], concentration: nil, controlled: false))
        r.append(Medication(generic: "Gabapentin", brand: "Neurontin", drugClass: "Anticonvulsant/anxiolytic", species: cat, form: .capsule, indication: "Feline situational anxiety before transport/vet visit — MSD reference dose", kind: .fixedMg, minDose: 100, maxDose: 200, frequency: "once 90–120 min before stress", route: "PO", notes: "Extra-label veterinary use. MSD describes 100–200 mg/cat for situational anxiety; sedation/ataxia and patient-specific factors require veterinarian review.", source: "MSD Veterinary Manual — Behavior Problems of Cats (100–200 mg/cat once 90–120 min before stress; accessed 2026-09-20)", strengths: [100,300,400], concentration: nil, controlled: false))
        r.append(Medication(generic: "Trazodone", brand: "Desyrel", drugClass: "Serotonergic anxiolytic", species: dog, form: .tablet, indication: "Canine situational anxiety / travel — MSD reference dose", kind: .mgKg, minDose: 5, maxDose: 7.5, frequency: "once ~90 min before event", route: "PO", notes: "Extra-label veterinary use. This entry is only for the cited situational-anxiety/travel use. Review serotonergic drug interactions, sedation, cardiovascular status, and patient-specific contraindications.", source: "MSD Veterinary Manual — Motion Sickness in Animals (5–7.5 mg/kg PO ~90 min before event; accessed 2026-09-20)", strengths: [50,100,150,300], concentration: nil, controlled: false))
        r.append(Medication(generic: "Trazodone", brand: "Desyrel", drugClass: "Serotonergic anxiolytic", species: cat, form: .tablet, indication: "Feline situational anxiety before stressful event — MSD reference dose", kind: .fixedMg, minDose: 50, maxDose: 100, frequency: "once ~90 min before stress", route: "PO", notes: "Extra-label veterinary use. MSD describes 50–100 mg/cat for situational anxiety. Review serotonergic interactions, sedation, and patient-specific factors.", source: "MSD Veterinary Manual — Behavior Problems of Cats (50–100 mg/cat once ~90 min before stress; accessed 2026-09-20)", strengths: [50,100,150], concentration: nil, controlled: false))

        func ref(_ generic: String, _ brand: String, _ drugClass: String, _ species: Set<Species>, _ form: MedicationForm, _ indication: String, _ controlled: Bool = false) {
            r.append(Medication(generic: generic, brand: brand, drugClass: drugClass, species: species, form: form, indication: indication, kind: .protocolOnly, minDose: 0, maxDose: 0, frequency: "", route: "", notes: "Dose depends on indication, route, patient status, product, or clinic protocol.", source: "clinic formulary / authoritative veterinary reference required", strengths: [], concentration: nil, controlled: controlled))
        }

        ref("Metronidazole","Flagyl","Nitroimidazole",both,.tablet,"Selected anaerobic/protozoal indications")
        ref("Doxycycline","Vibramycin","Tetracycline",both,.tablet,"Selected bacterial/vector-borne disease")
        ref("Prednisone/prednisolone","","Corticosteroid",both,.tablet,"Inflammatory/immune-mediated indications")
        ref("Levetiracetam","Keppra","Anticonvulsant",both,.tablet,"Seizure control")
        ref("Omeprazole","Prilosec","PPI",both,.capsule,"Acid suppression")
        ref("Famotidine","Pepcid","H2 blocker",both,.tablet,"Acid suppression")
        ref("Ondansetron","Zofran","5-HT3 antiemetic",both,.tablet,"Nausea/vomiting")
        ref("Diphenhydramine","Benadryl","Antihistamine",both,.tablet,"Selected allergic reactions")
        ref("Cetirizine","Zyrtec","Antihistamine",both,.tablet,"Selected allergic/pruritic indications")
        ref("Furosemide","Lasix/Salix","Loop diuretic",both,.tablet,"CHF/pulmonary edema")
        ref("Spironolactone","Aldactone","Aldosterone antagonist",both,.tablet,"Selected cardiac/ascites protocols")
        ref("Benazepril","Lotensin","ACE inhibitor",both,.tablet,"Selected cardiac/renal disease")
        ref("Enalapril","Enacard","ACE inhibitor",dog,.tablet,"Selected canine cardiac disease")
        ref("Methimazole transdermal","compounded","Antithyroid",cat,.transdermal,"Feline hyperthyroidism (compounded extra-label)")
        ref("Insulin glargine","Lantus","Insulin",both,.injection,"Diabetes mellitus")
        ref("Insulin PZI","ProZinc","Insulin",both,.injection,"Diabetes mellitus")
        ref("Phenobarbital","","Anticonvulsant",both,.tablet,"Seizure control",true)
        ref("Tramadol","Ultram","Opioid-like analgesic",both,.tablet,"Selected pain indications",true)
        ref("Buprenorphine","Buprenex/Simbadol","Opioid",both,.injection,"Analgesia",true)
        ref("Butorphanol","Torbugesic","Opioid agonist-antagonist",both,.injection,"Analgesia/sedation",true)
        ref("Hydromorphone","Dilaudid","Opioid",both,.injection,"Analgesia/premedication",true)
        ref("Fentanyl","","Opioid",both,.injection,"Analgesia/CRI/transdermal",true)
        ref("Ketamine","Ketaset","Dissociative anesthetic",both,.injection,"Anesthesia/analgesia",true)
        ref("Midazolam","Versed","Benzodiazepine",both,.injection,"Sedation/anesthesia/seizure protocols",true)
        ref("Diazepam","Valium","Benzodiazepine",both,.injection,"Seizure/anesthesia protocols",true)
        ref("Alprazolam","Xanax","Benzodiazepine",both,.tablet,"Situational anxiety",true)
        ref("Dexmedetomidine","Dexdomitor","Alpha-2 agonist",both,.injection,"Sedation/anesthesia")
        ref("Propofol","PropoFlo","Anesthetic",both,.injection,"Induction/anesthesia")
        ref("Alfaxalone","Alfaxan","Anesthetic",both,.injection,"Induction/anesthesia")
        // Additional common small-animal medications kept searchable but protocol-locked
        // until a specific indication/route/source-backed dose rule is selected.
        ref("Amoxicillin","","Penicillin antimicrobial",both,.capsule,"Selected susceptible bacterial infections")
        ref("Ampicillin","","Penicillin antimicrobial",both,.injection,"Selected susceptible bacterial infections")
        ref("Ampicillin + sulbactam","Unasyn","Penicillin/beta-lactamase inhibitor",both,.injection,"Selected susceptible bacterial infections")
        ref("Cephalexin","Keflex","Cephalosporin",both,.capsule,"Selected susceptible skin/soft-tissue infections")
        ref("Cefazolin","Ancef","Cephalosporin",both,.injection,"Perioperative/selected susceptible infections")
        ref("Clindamycin","Antirobe","Lincosamide antimicrobial",both,.capsule,"Dental, bone, soft-tissue and selected protozoal indications")
        ref("Enrofloxacin","Baytril","Fluoroquinolone",both,.tablet,"Selected susceptible bacterial infections")
        ref("Marbofloxacin","Zeniquin","Fluoroquinolone",both,.tablet,"Selected susceptible bacterial infections")
        ref("Orbifloxacin","Orbax","Fluoroquinolone",both,.tablet,"Selected susceptible bacterial infections")
        ref("Azithromycin","Zithromax","Macrolide antimicrobial",both,.tablet,"Selected bacterial/protozoal indications")
        ref("Minocycline","Minocin","Tetracycline",both,.capsule,"Selected bacterial/vector-borne indications")
        ref("Trimethoprim-sulfamethoxazole","TMS/SMZ-TMP","Potentiated sulfonamide",both,.tablet,"Selected susceptible infections")
        ref("Chloramphenicol","","Amphenicol antimicrobial",both,.capsule,"Selected resistant/susceptible infections")
        ref("Sucralfate","Carafate","GI protectant",both,.tablet,"Esophageal/gastric mucosal protection")
        ref("Pantoprazole","Protonix","PPI",both,.injection,"Acid suppression in selected hospitalized patients")
        ref("Metoclopramide","Reglan","Prokinetic/antiemetic",both,.tablet,"Selected nausea/prokinetic indications")
        ref("Cisapride","compounded","Prokinetic",both,.capsule,"Selected GI motility disorders")
        ref("Lactulose","Enulose","Osmotic laxative",both,.liquid,"Constipation/hepatic encephalopathy protocols")
        ref("Ursodiol","Actigall","Bile acid",both,.capsule,"Selected hepatobiliary disease")
        ref("Mirtazapine oral","Remeron","Appetite stimulant/antidepressant",both,.tablet,"Selected appetite/nausea indications")
        ref("Dexamethasone","","Corticosteroid",both,.injection,"Inflammatory/immune-mediated/emergency indications")
        ref("Methylprednisolone","","Corticosteroid",both,.tablet,"Inflammatory/immune-mediated indications")
        ref("Triamcinolone","","Corticosteroid",both,.tablet,"Selected inflammatory/allergic indications")
        ref("Amlodipine","Norvasc","Calcium-channel blocker",both,.tablet,"Systemic hypertension")
        ref("Atenolol","Tenormin","Beta blocker",both,.tablet,"Selected tachyarrhythmia/cardiac indications")
        ref("Diltiazem","Cardizem","Calcium-channel blocker",both,.tablet,"Selected tachyarrhythmia/cardiac indications")
        ref("Clopidogrel","Plavix","Antiplatelet",both,.tablet,"Thromboembolism prevention protocols")
        ref("Digoxin","Lanoxin","Cardiac glycoside",both,.tablet,"Selected CHF/arrhythmia protocols")
        ref("Sildenafil","Viagra","PDE-5 inhibitor",both,.tablet,"Pulmonary hypertension")
        ref("Hydralazine","","Vasodilator",both,.tablet,"Selected severe hypertension/afterload reduction")
        ref("Telmisartan","Semintra","ARB",cat,.liquid,"Feline hypertension/proteinuria indications")
        ref("Torsemide","Demadex","Loop diuretic",both,.tablet,"Selected refractory CHF protocols")
        ref("Levothyroxine","Soloxine","Thyroid hormone",dog,.tablet,"Canine hypothyroidism")
        ref("Trilostane","Vetoryl","Adrenal steroidogenesis inhibitor",dog,.capsule,"Canine hyperadrenocorticism")
        ref("Desmopressin","DDAVP","ADH analog",both,.reference,"Central diabetes insipidus/selected hemostatic use")
        ref("Fludrocortisone","Florinef","Mineralocorticoid",dog,.tablet,"Hypoadrenocorticism")
        ref("Desoxycorticosterone pivalate","Percorten-V/Zycortal","Mineralocorticoid",dog,.injection,"Hypoadrenocorticism")
        ref("Mitotane","Lysodren","Adrenocorticolytic",dog,.tablet,"Selected canine hyperadrenocorticism protocols")
        ref("Zonisamide","Zonegran","Anticonvulsant",both,.capsule,"Seizure control")
        ref("Potassium bromide","KBr","Anticonvulsant",dog,.liquid,"Seizure control")
        ref("Pregabalin","Lyrica","Neuropathic analgesic/anxiolytic",both,.capsule,"Neuropathic pain / selected feline anxiety protocols",true)
        ref("Methocarbamol","Robaxin","Muscle relaxant",both,.tablet,"Muscle tremor/spasm protocols")
        ref("Clomipramine","Clomicalm","Tricyclic antidepressant",dog,.tablet,"Separation anxiety with behavior modification")
        ref("Sertraline","Zoloft","SSRI",both,.tablet,"Selected behavioral disorders")
        ref("Paroxetine","Paxil","SSRI",both,.tablet,"Selected behavioral disorders")
        ref("Buspirone","Buspar","Anxiolytic",both,.tablet,"Selected feline/canine anxiety protocols")
        ref("Clonidine","Catapres","Alpha-2 agonist",dog,.tablet,"Selected situational anxiety protocols")
        ref("Selegiline","Anipryl","MAO-B inhibitor",dog,.tablet,"Canine cognitive dysfunction / selected endocrine use")
        ref("Hydroxyzine","Atarax","Antihistamine",both,.tablet,"Selected pruritic/allergic indications")
        ref("Chlorpheniramine","","Antihistamine",both,.tablet,"Selected allergic/pruritic indications")
        ref("Lokivetmab","Cytopoint","Monoclonal antibody",dog,.injection,"Canine atopic dermatitis/pruritus")
        ref("Cyclosporine ophthalmic","Optimmune/compounded","Calcineurin inhibitor",both,.reference,"KCS/immune-mediated ocular surface disease")
        ref("Tacrolimus ophthalmic","compounded","Calcineurin inhibitor",both,.reference,"KCS/immune-mediated ocular surface disease")
        ref("Latanoprost","Xalatan","Prostaglandin analog",dog,.reference,"Selected glaucoma protocols")
        ref("Dorzolamide","Trusopt","Carbonic anhydrase inhibitor",both,.reference,"Selected glaucoma protocols")
        ref("Timolol ophthalmic","Timoptic","Beta blocker",both,.reference,"Selected glaucoma protocols")
        ref("Atropine ophthalmic","","Anticholinergic",both,.reference,"Uveitis/cycloplegia protocols")
        ref("Ofloxacin ophthalmic","Ocuflox","Fluoroquinolone",both,.reference,"Selected bacterial ocular infections")
        ref("Ciprofloxacin ophthalmic","Ciloxan","Fluoroquinolone",both,.reference,"Selected bacterial ocular infections")
        ref("Epinephrine","Adrenalin","Adrenergic agonist",both,.injection,"CPR/anaphylaxis/emergency protocols")
        ref("Atropine injection","","Anticholinergic",both,.injection,"Bradycardia/CPR/anesthesia protocols")
        ref("Glycopyrrolate","Robinul-V","Anticholinergic",both,.injection,"Anesthesia/bradycardia protocols")
        ref("Lidocaine","","Local anesthetic/antiarrhythmic",both,.injection,"Local anesthesia/ventricular arrhythmia/CRI protocols")
        ref("Naloxone","Narcan","Opioid antagonist",both,.injection,"Opioid reversal")
        ref("Mannitol","","Osmotic diuretic",both,.injection,"Intracranial/intraocular pressure protocols")
        ref("Calcium gluconate","","Electrolyte",both,.injection,"Hyperkalemia/hypocalcemia emergency protocols")
        ref("Dextrose","","Glucose",both,.injection,"Hypoglycemia/emergency protocols")
        ref("Potassium chloride","","Electrolyte",both,.injection,"Potassium supplementation protocols")
        ref("Fenbendazole","Panacur","Anthelmintic",both,.reference,"Selected GI parasite protocols")
        ref("Pyrantel pamoate","","Anthelmintic",both,.reference,"Selected nematode protocols")
        ref("Praziquantel","Droncit","Anthelmintic",both,.reference,"Cestode protocols")
        ref("Ivermectin","","Macrocyclic lactone",both,.reference,"Selected parasite protocols; ABCB1/MDR1 risk matters")
        ref("Milbemycin oxime","Interceptor","Macrocyclic lactone",dog,.reference,"Heartworm/intestinal parasite prevention")
        ref("Selamectin","Revolution","Macrocyclic lactone",both,.reference,"Selected ecto/endoparasite prevention")
        ref("Moxidectin","","Macrocyclic lactone",both,.reference,"Selected parasite prevention/treatment")
        ref("Afoxolaner","NexGard","Isoxazoline",dog,.reference,"Flea/tick prevention")
        ref("Fluralaner","Bravecto","Isoxazoline",both,.reference,"Flea/tick prevention")
        ref("Sarolaner","Simparica","Isoxazoline",dog,.reference,"Flea/tick prevention")
        ref("Lotilaner","Credelio","Isoxazoline",both,.reference,"Flea/tick prevention")
        ref("Toceranib phosphate","Palladia","Tyrosine kinase inhibitor",dog,.tablet,"Mast cell tumor/oncology protocols")
        ref("Chlorambucil","Leukeran","Alkylating antineoplastic",both,.tablet,"Selected oncology/immune-mediated protocols")
        ref("Cyclophosphamide","Cytoxan","Alkylating antineoplastic",both,.tablet,"Selected oncology/immune-mediated protocols")
        ref("Vincristine","","Vinca alkaloid",both,.injection,"Selected oncology/IMT protocols")
        ref("Doxorubicin","Adriamycin","Anthracycline",both,.injection,"Selected oncology protocols")
        ref("Lomustine","CCNU","Alkylating antineoplastic",both,.capsule,"Selected oncology protocols")


        return r
    }()

    static func searchMedications(query: String, species: Species, form: MedicationForm) -> [Medication] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MedicationFormulations.organized.filter { m in
            guard m.supports(species) else { return false }
            guard form == .any || m.form == form else { return false }
            if needle.isEmpty { return true }
            let haystack = [m.generic, m.displayName, m.brand, m.drugClass, m.indication, m.form.rawValue].joined(separator: " ").lowercased()
            return haystack.contains(needle)
        }
    }

    static let breeds: [BreedEntry] = [
        BreedEntry(species: .dog, name: "German Shepherd Dog", conditions: "Hip/elbow dysplasia; degenerative myelopathy; exocrine pancreatic insufficiency; GDV", note: "Predisposition is not a diagnosis."),
        BreedEntry(species: .dog, name: "Labrador Retriever", conditions: "Hip/elbow dysplasia; obesity; exercise-induced collapse; cruciate disease; otitis", note: "Body-condition management modifies some risk."),
        BreedEntry(species: .dog, name: "Golden Retriever", conditions: "Cancer predisposition; hip/elbow dysplasia; atopy; hypothyroidism", note: "Associations vary by lineage/population."),
        BreedEntry(species: .dog, name: "French Bulldog", conditions: "Brachycephalic airway syndrome; IVDD; allergies; heat intolerance", note: "Conformation-related disease can be clinically significant."),
        BreedEntry(species: .dog, name: "English Bulldog", conditions: "Brachycephalic airway disease; skin-fold dermatitis; hip dysplasia; ocular disease", note: "Conformation-related risk is common."),
        BreedEntry(species: .dog, name: "Pug", conditions: "Brachycephalic airway disease; ocular disease; patellar luxation; hemivertebrae", note: "Eye and airway assessment are important."),
        BreedEntry(species: .dog, name: "Dachshund", conditions: "Intervertebral disc disease; obesity; periodontal disease", note: "Chondrodystrophic conformation increases IVDD risk."),
        BreedEntry(species: .dog, name: "Great Dane", conditions: "GDV; dilated cardiomyopathy; osteosarcoma; cervical spondylomyelopathy", note: "Giant-breed preventive planning matters."),
        BreedEntry(species: .dog, name: "Doberman Pinscher", conditions: "Dilated cardiomyopathy; von Willebrand disease; cervical spondylomyelopathy; hypothyroidism", note: "Cardiac screening is commonly used in at-risk animals."),
        BreedEntry(species: .dog, name: "Boxer", conditions: "Arrhythmogenic cardiomyopathy; mast cell tumor; lymphoma; brachycephalic airway disease", note: "Cardiac and oncologic vigilance is useful."),
        BreedEntry(species: .dog, name: "Cavalier King Charles Spaniel", conditions: "Myxomatous mitral valve disease; syringomyelia; patellar luxation", note: "Cardiac disease may occur relatively early."),
        BreedEntry(species: .dog, name: "Miniature Schnauzer", conditions: "Hyperlipidemia; pancreatitis; calcium oxalate urolithiasis; diabetes", note: "Diet and metabolic screening can matter."),
        BreedEntry(species: .dog, name: "Yorkshire Terrier", conditions: "Tracheal collapse; portosystemic shunt; patellar luxation; periodontal disease", note: "Toy-breed airway and dental risks are common."),
        BreedEntry(species: .dog, name: "Australian Shepherd", conditions: "MDR1/ABCB1 drug sensitivity; epilepsy; hip dysplasia; inherited eye disease", note: "Genotype can materially change drug safety."),
        BreedEntry(species: .dog, name: "Collie", conditions: "MDR1/ABCB1 drug sensitivity; collie eye anomaly; dermatomyositis", note: "Consider ABCB1 status before certain medications."),
        BreedEntry(species: .dog, name: "Rottweiler", conditions: "Osteosarcoma; hip/elbow dysplasia; cruciate disease; subaortic stenosis", note: "Orthopedic and oncologic risk is notable."),
        BreedEntry(species: .dog, name: "Bernese Mountain Dog", conditions: "Histiocytic sarcoma; other cancers; hip/elbow dysplasia; GDV", note: "Cancer burden is high in some populations."),
        BreedEntry(species: .dog, name: "Standard Poodle", conditions: "Addison disease; GDV; sebaceous adenitis; hip dysplasia", note: "Endocrine disease can be an important differential."),
        BreedEntry(species: .dog, name: "Cocker Spaniel", conditions: "Otitis; chronic hepatitis; cataracts; immune-mediated disease", note: "Ear and eye disease are frequent issues."),
        BreedEntry(species: .dog, name: "Greyhound", conditions: "Osteosarcoma; periodontal disease; breed-specific hematology; anesthesia differences", note: "Interpret some lab values in breed context."),
        BreedEntry(species: .dog, name: "Beagle", conditions: "Idiopathic epilepsy; hypothyroidism; IVDD; glaucoma", note: "Neurologic and ophthalmic presentations deserve breed context."),
        BreedEntry(species: .dog, name: "Basset Hound", conditions: "GDV; otitis externa; glaucoma; IVDD; inherited platelet dysfunction in some lines", note: "Long ears, deep chest, and chondrodystrophic build contribute to several common risks."),
        BreedEntry(species: .dog, name: "Border Collie", conditions: "Idiopathic epilepsy; collie eye anomaly; ABCB1/MDR1 drug sensitivity; hip dysplasia", note: "Genetic testing can clarify selected inherited risks."),
        BreedEntry(species: .dog, name: "Pembroke Welsh Corgi", conditions: "IVDD/chondrodystrophy; degenerative myelopathy; hip dysplasia; progressive retinal atrophy", note: "Spinal and neurologic screening may be relevant as dogs age."),
        BreedEntry(species: .dog, name: "Cardigan Welsh Corgi", conditions: "IVDD/chondrodystrophy; progressive retinal atrophy; degenerative myelopathy; hip dysplasia", note: "Inherited eye and spinal disease associations are documented in the breed."),
        BreedEntry(species: .dog, name: "Shetland Sheepdog", conditions: "ABCB1/MDR1 drug sensitivity; collie eye anomaly; dermatomyositis; von Willebrand disease", note: "Drug-sensitivity genotype can materially affect medication safety."),
        BreedEntry(species: .dog, name: "Australian Cattle Dog", conditions: "Progressive retinal atrophy; congenital deafness; hip/elbow dysplasia; primary lens luxation", note: "Eye, hearing, and orthopedic screening are commonly considered."),
        BreedEntry(species: .dog, name: "Siberian Husky", conditions: "Inherited cataracts/other eye disease; glaucoma; hip dysplasia; zinc-responsive dermatosis", note: "Ophthalmic disease is an important inherited-disease category in this breed."),
        BreedEntry(species: .dog, name: "Alaskan Malamute", conditions: "Hip dysplasia; inherited polyneuropathy; hypothyroidism; zinc-responsive dermatosis", note: "Neuromuscular and orthopedic differentials can be breed-associated."),
        BreedEntry(species: .dog, name: "Newfoundland", conditions: "Subaortic stenosis; cystinuria; hip/elbow dysplasia; dilated cardiomyopathy", note: "Cardiac and urinary screening can be clinically important."),
        BreedEntry(species: .dog, name: "Irish Wolfhound", conditions: "Dilated cardiomyopathy; osteosarcoma; GDV; inherited hepatic/vascular disease in some lines", note: "Giant-breed cardiac, oncologic, and GDV risk deserves early attention."),
        BreedEntry(species: .dog, name: "Saint Bernard", conditions: "GDV; hip/elbow dysplasia; osteosarcoma; cardiomyopathy", note: "Giant-breed orthopedic and gastric-dilatation risks are notable."),
        BreedEntry(species: .dog, name: "Mastiff", conditions: "GDV; hip/elbow dysplasia; osteosarcoma; cardiomyopathy", note: "Large body size modifies orthopedic and oncologic risk."),
        BreedEntry(species: .dog, name: "Rhodesian Ridgeback", conditions: "Dermoid sinus; hip dysplasia; hypothyroidism; degenerative myelopathy in some lines", note: "Dermoid sinus is a distinctive congenital concern in this breed."),
        BreedEntry(species: .dog, name: "Dalmatian", conditions: "Hyperuricosuria/urate urolithiasis; congenital deafness; atopy; copper-associated liver disease in some lines", note: "Urinary purine handling is a major breed-specific consideration."),
        BreedEntry(species: .dog, name: "Weimaraner", conditions: "GDV; hypertrophic osteodystrophy; immune-mediated disease; hip dysplasia", note: "Rapid growth and deep-chested conformation influence several risks."),
        BreedEntry(species: .dog, name: "German Shorthaired Pointer", conditions: "Hip dysplasia; inherited eye disease; von Willebrand disease in some lines; hypothyroidism", note: "Use current breed-club/OFA screening recommendations for breeding animals."),
        BreedEntry(species: .dog, name: "Chesapeake Bay Retriever", conditions: "Hip/elbow dysplasia; progressive retinal atrophy; von Willebrand disease; exercise-induced collapse in some lines", note: "Orthopedic, eye, and inherited-disease testing may be relevant."),
        BreedEntry(species: .dog, name: "Portuguese Water Dog", conditions: "Juvenile dilated cardiomyopathy; GM1 gangliosidosis; progressive retinal atrophy; hip dysplasia", note: "Several DNA-screenable inherited disorders occur in the breed."),
        BreedEntry(species: .dog, name: "West Highland White Terrier", conditions: "Atopic dermatitis; pulmonary fibrosis; craniomandibular osteopathy; chronic skin/ear disease", note: "Dermatologic and respiratory differentials are common breed considerations."),
        BreedEntry(species: .dog, name: "Scottish Terrier", conditions: "Urothelial carcinoma risk; von Willebrand disease; Scottie cramp; hyperadrenocorticism", note: "Urinary signs warrant careful investigation in this breed."),
        BreedEntry(species: .dog, name: "Shih Tzu", conditions: "Brachycephalic airway disease; corneal/ocular disease; IVDD; renal dysplasia in some lines", note: "Airway, eye, and spinal disease can be conformation-associated."),
        BreedEntry(species: .dog, name: "Boston Terrier", conditions: "Brachycephalic airway disease; corneal ulcers; patellar luxation; hemivertebrae", note: "Airway and ocular assessment are particularly important."),
        BreedEntry(species: .dog, name: "Chihuahua", conditions: "Myxomatous mitral valve disease; patellar luxation; hydrocephalus; tracheal collapse", note: "Toy-breed cardiac, airway, and orthopedic risks are common."),
        BreedEntry(species: .dog, name: "Pomeranian", conditions: "Tracheal collapse; patellar luxation; alopecia X; periodontal disease", note: "Airway and dental disease are frequent clinical concerns."),
        BreedEntry(species: .dog, name: "Maltese", conditions: "Portosystemic shunt; patellar luxation; tracheal collapse; periodontal disease", note: "Toy-breed hepatic vascular and airway disorders should remain on the differential list."),
        BreedEntry(species: .dog, name: "Jack Russell Terrier", conditions: "Primary lens luxation; patellar luxation; congenital deafness; hereditary ataxia in some lines", note: "Acute painful red eye can be an emergency when lens luxation is suspected."),
        BreedEntry(species: .dog, name: "Chinese Shar-Pei", conditions: "Shar-Pei autoinflammatory disease/fever; renal amyloidosis; entropion; chronic skin disease", note: "Recurrent fever and inflammatory episodes can have breed-specific significance."),
        BreedEntry(species: .dog, name: "Akita", conditions: "Sebaceous adenitis; autoimmune disease; hypothyroidism; hip dysplasia", note: "Immune-mediated and dermatologic disease associations are recognized."),
        BreedEntry(species: .dog, name: "Samoyed", conditions: "Hereditary glomerulopathy; diabetes mellitus; hip dysplasia; progressive retinal atrophy", note: "Renal and eye screening can be important in affected lines."),
        BreedEntry(species: .dog, name: "Basenji", conditions: "Fanconi syndrome; progressive retinal atrophy; hypothyroidism; inherited hemolytic anemia in some lines", note: "Fanconi screening/testing is a distinctive breed consideration."),
        BreedEntry(species: .dog, name: "Belgian Malinois", conditions: "Idiopathic epilepsy; hip/elbow dysplasia; inherited eye disease", note: "Neurologic and orthopedic screening may be relevant depending on lineage."),
        BreedEntry(species: .dog, name: "Bloodhound", conditions: "GDV; entropion/ectropion; hip/elbow dysplasia; chronic otitis", note: "Deep chest, skin folds, and pendulous ears contribute to recurring risks."),
        BreedEntry(species: .dog, name: "English Springer Spaniel", conditions: "Progressive retinal atrophy; phosphofructokinase deficiency; fucosidosis in some lines; chronic otitis", note: "Several inherited tests are available for affected lines."),
        BreedEntry(species: .cat, name: "Domestic Shorthair", conditions: "Obesity; dental disease; chronic kidney disease with age; diabetes", note: "Broad population, not a genetically uniform breed."),
        BreedEntry(species: .cat, name: "Maine Coon", conditions: "Hypertrophic cardiomyopathy; hip dysplasia; spinal muscular atrophy", note: "HCM screening may be relevant."),
        BreedEntry(species: .cat, name: "Ragdoll", conditions: "Hypertrophic cardiomyopathy; urinary tract disease", note: "HCM variants exist in some lines."),
        BreedEntry(species: .cat, name: "Persian", conditions: "Polycystic kidney disease; brachycephalic airway/ocular disease; dental malocclusion", note: "PKD genetic screening is available."),
        BreedEntry(species: .cat, name: "Siamese", conditions: "Asthma/airway disease; amyloidosis; selected neoplasms; PRA in some lines", note: "Associations vary across populations."),
        BreedEntry(species: .cat, name: "Bengal", conditions: "Hypertrophic cardiomyopathy; PRA; pyruvate kinase deficiency", note: "Genetic tests exist for some inherited conditions."),
        BreedEntry(species: .cat, name: "British Shorthair", conditions: "Hypertrophic cardiomyopathy; obesity; hemophilia B in some lines", note: "Cardiac screening may be relevant."),
        BreedEntry(species: .cat, name: "Scottish Fold", conditions: "Osteochondrodysplasia; degenerative joint disease", note: "Fold phenotype is linked to cartilage and bone disease."),
        BreedEntry(species: .cat, name: "Sphynx", conditions: "Hypertrophic cardiomyopathy; dermatologic/ear issues; temperature sensitivity", note: "Regular cardiac assessment is common in breeding programs."),
        BreedEntry(species: .cat, name: "Abyssinian", conditions: "Renal amyloidosis; pyruvate kinase deficiency; PRA", note: "Genetic testing can help in breeding populations."),
        BreedEntry(species: .cat, name: "Manx", conditions: "Sacrocaudal dysgenesis; megacolon; urinary/fecal dysfunction", note: "Neurologic deficits can relate to spinal malformation."),
        BreedEntry(species: .cat, name: "Norwegian Forest Cat", conditions: "Hypertrophic cardiomyopathy; glycogen storage disease type IV; hip dysplasia", note: "Cardiac screening and breed-specific genetic testing may be relevant."),
        BreedEntry(species: .cat, name: "Burmese", conditions: "Diabetes mellitus; hypokalemic polymyopathy; craniofacial defect in some lines; GM2 gangliosidosis", note: "Risk varies substantially by geographic breeding population."),
        BreedEntry(species: .cat, name: "Devon Rex", conditions: "Hereditary myopathy; hypertrophic cardiomyopathy; patellar luxation", note: "Neuromuscular weakness in young cats can be inherited."),
        BreedEntry(species: .cat, name: "Cornish Rex", conditions: "Hypertrophic cardiomyopathy; patellar luxation; hereditary hypotrichosis/skin-coat disorders in some lines", note: "Cardiac and orthopedic assessment may be relevant."),
        BreedEntry(species: .cat, name: "Himalayan", conditions: "Polycystic kidney disease; brachycephalic airway/ocular disease; dental malocclusion", note: "Persian-related inherited and conformation-associated risks apply."),
        BreedEntry(species: .cat, name: "Exotic Shorthair", conditions: "Polycystic kidney disease; brachycephalic airway/ocular disease; dental disease", note: "Conformation can materially affect breathing, tear drainage, and ocular health."),
        BreedEntry(species: .cat, name: "Oriental Shorthair", conditions: "Amyloidosis; progressive retinal atrophy; asthma/airway disease; selected neoplasms", note: "Many associations overlap with Siamese-related lines."),
        BreedEntry(species: .cat, name: "Balinese", conditions: "Progressive retinal atrophy; amyloidosis; asthma/airway disease", note: "Siamese-related inherited disease associations can be relevant."),
        BreedEntry(species: .cat, name: "Siberian", conditions: "Hypertrophic cardiomyopathy; inherited cardiac disease in some lines", note: "Breeding-line cardiac screening is commonly used."),
        BreedEntry(species: .cat, name: "Somali", conditions: "Renal amyloidosis; pyruvate kinase deficiency; progressive retinal atrophy", note: "Risks overlap with Abyssinian-related lines and include DNA-testable disorders."),
        BreedEntry(species: .cat, name: "Turkish Angora", conditions: "Congenital deafness in some white/blue-eyed lines; hypertrophic cardiomyopathy", note: "Coat/eye-color-associated deafness risk is not present in every individual."),
        BreedEntry(species: .cat, name: "American Shorthair", conditions: "Hypertrophic cardiomyopathy; obesity; dental disease", note: "Broad lineage variation means individual screening still matters."),
        BreedEntry(species: .cat, name: "Selkirk Rex", conditions: "Polycystic kidney disease in some lines; hypertrophic cardiomyopathy; obesity", note: "Inherited risk can reflect Persian/British Shorthair ancestry in some lines."),
        BreedEntry(species: .cat, name: "Ocicat", conditions: "Hypertrophic cardiomyopathy; pyruvate kinase deficiency in some lines; amyloidosis", note: "Genetic and cardiac screening may be considered in breeding populations.")
    ]

    static func searchBreeds(species: Species, query: String) -> [BreedEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return breeds.filter { b in
            guard b.species == species else { return false }
            if needle.isEmpty { return true }
            return (b.name + " " + b.conditions).lowercased().contains(needle)
        }
    }
}



// Product form organization only. Canonical clinical protocols remain unchanged.
struct MedicationFormulation: Codable, Hashable {
    let form: String
    let label: String
    var brand: String? = nil
    var protocolRoutes: [String: String]? = nil
    var strengths: [Double]? = nil
    var concentrations: [Double]? = nil
    var productSource: String? = nil
    var productSources: [String]? = nil
    var keepProtocolConcentration: Bool? = nil
    var bonqat: Bool? = nil
    var customConcentration: Bool? = nil
}

enum MedicationFormulations {
    static let rules: [String: [MedicationFormulation]] = {
        let json = #"""
{
  "Levetiracetam": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "levetiracetam-dog-1": "PO",
        "levetiracetam-cat-1": "PO",
        "levetiracetam-cat-2": "PO \u2014 ER tablet whole"
      },
      "concentrations": [
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3ca9df05-a506-4ec8-a4fe-320f1219ab21",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3ca9df05-a506-4ec8-a4fe-320f1219ab21",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9dca1330-52ca-47a4-a134-ec55c9d5786d"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "levetiracetam-dog-1": "PO",
        "levetiracetam-cat-1": "PO",
        "levetiracetam-cat-2": "PO \u2014 ER tablet whole"
      },
      "strengths": [
        250.0,
        500.0,
        750.0,
        1000.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0a688786-879b-4e27-a46a-5c86bbfa1292",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0a688786-879b-4e27-a46a-5c86bbfa1292",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3ca9df05-a506-4ec8-a4fe-320f1219ab21"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet \u00b7 extended release",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "levetiracetam-dog-2": "PO \u2014 ER tablet whole"
      },
      "strengths": [
        500.0,
        750.0,
        1000.0,
        1500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7cb669d7-d1aa-43b3-a322-0a2eaa13c656",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7cb669d7-d1aa-43b3-a322-0a2eaa13c656",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c508a392-0603-477d-8a45-3ec550371111",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cac83d47-88a2-4447-a0c0-90b44ffda0ac"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "levetiracetam-dog-3": "IV",
        "levetiracetam-cat-3": "IV"
      }
    }
  ],
  "Famotidine": [
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "famotidine-dog-1": "PO",
        "famotidine-cat-1": "PO"
      },
      "concentrations": [
        8.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a88e7069-230c-4105-ade0-a98968e18671",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a88e7069-230c-4105-ade0-a98968e18671",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b2228be0-472b-4e47-9910-af0bf12fde77"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "famotidine-dog-1": "PO",
        "famotidine-cat-1": "PO"
      },
      "strengths": [
        10.0,
        20.0,
        40.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=273deac8-c2b0-423f-8662-4f16d91df216",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=273deac8-c2b0-423f-8662-4f16d91df216",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=58b653eb-6539-4b79-9d22-df6eaf35307f",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=67a6e7f3-04d6-426c-b952-7677a84ace4d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6daf1ebe-b0a2-4413-bf25-3de6eb64b0c6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b1edf3c5-e42c-471b-8771-6c93094822de",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ca039876-f7e5-3e60-da5a-a1f40637a417"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "famotidine-dog-1": "IV"
      },
      "concentrations": [
        0.4,
        4.0,
        10.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5995d726-f3f8-4c2d-af19-1b12e3f769c6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9710995d-b518-40ce-bc2b-8b5dcf002c31",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=97c33213-f415-4718-8466-9aa50371af70",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b6214fc9-a274-ef45-e053-2a95a90ae43a"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5995d726-f3f8-4c2d-af19-1b12e3f769c6"
    }
  ],
  "Ondansetron": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "ondansetron-dog-1": "PO",
        "ondansetron-cat-1": "PO"
      },
      "concentrations": [
        0.8
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=68a4d845-0c1c-4867-bfca-c0fb11dc93cd",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=68a4d845-0c1c-4867-bfca-c0fb11dc93cd"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "ondansetron-dog-1": "PO",
        "ondansetron-cat-1": "PO"
      },
      "strengths": [
        4.0,
        8.0,
        16.0,
        24.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2b9ea1fc-59a4-8189-e063-6394a90a9ae6",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2b9ea1fc-59a4-8189-e063-6394a90a9ae6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=476e704c-95ae-4591-94f7-ee4ab827ff13",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=57578387-1918-4e56-a564-f14fb22340bf",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=eee5217a-eba8-463a-812d-bf3c66f0934f"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "ondansetron-dog-2": "IV",
        "ondansetron-cat-2": "IV"
      },
      "concentrations": [
        2.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=35e0d160-813f-41d7-a382-d2cab6485d9c",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6a11f61b-2318-4382-2b91-4366e4bb53fa",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8cea2f3a-cfa5-4a68-9ff4-b5a5a2085d08",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d89017aa-b8c3-4fd2-8e68-44e2cfd6f290"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=35e0d160-813f-41d7-a382-d2cab6485d9c"
    }
  ],
  "Diphenhydramine": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "diphenhydramine-dog-1": "PO",
        "diphenhydramine-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "diphenhydramine-dog-1": "IM/SC",
        "diphenhydramine-cat-1": "IM/SC"
      }
    }
  ],
  "Cetirizine": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cetirizine-dog-1": "PO",
        "cetirizine-dog-2": "PO",
        "cetirizine-cat-1": "PO",
        "cetirizine-cat-2": "PO"
      },
      "strengths": [
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=59cef432-41ac-768c-e063-6294a90a38fa",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=59cef432-41ac-768c-e063-6294a90a38fa"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cetirizine-dog-1": "PO",
        "cetirizine-dog-2": "PO",
        "cetirizine-cat-1": "PO",
        "cetirizine-cat-2": "PO"
      },
      "strengths": [
        5.0,
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3cf969e6-6bc9-4dae-ab6a-b24c0fc46b25",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3cf969e6-6bc9-4dae-ab6a-b24c0fc46b25",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=487ae0f0-320c-4534-b9e2-0e215f167cea",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=737492bf-96bd-4f7c-aa42-4910746f44bb"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral solution",
      "protocolRoutes": {
        "cetirizine-dog-1": "PO",
        "cetirizine-dog-2": "PO",
        "cetirizine-cat-1": "PO",
        "cetirizine-cat-2": "PO"
      },
      "concentrations": [
        1
      ]
    }
  ],
  "Furosemide": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "furosemide-dog-2": "PO",
        "furosemide-cat-2": "PO"
      },
      "concentrations": [
        8.0,
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4a746634-379b-4847-a965-7607d2a71bed",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4a746634-379b-4847-a965-7607d2a71bed",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9e493331-dddd-496e-abf8-61747fb67aba"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "furosemide-dog-2": "PO",
        "furosemide-cat-2": "PO"
      },
      "strengths": [
        20.0,
        40.0,
        80.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9e493331-dddd-496e-abf8-61747fb67aba",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9e493331-dddd-496e-abf8-61747fb67aba"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "furosemide-dog-1": "IV/IM",
        "furosemide-dog-3": "IV CRI",
        "furosemide-cat-1": "IV/IM",
        "furosemide-cat-3": "IV CRI"
      },
      "concentrations": [
        10.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1b9117d5-0dd9-4577-a1fd-bb0aaf7e68ec",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2f547f7c-0322-465c-9764-43f955d98ab2",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=421aa6d5-623b-4dc2-abd5-bb9e7765bf37",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d63c1277-dd7e-4d21-9e80-68143f55e2dc",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ddfc41a9-37d4-49c1-bbf3-969a98cd649c",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e5880bf4-5037-4813-b7cc-656a6832ecb5"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1b9117d5-0dd9-4577-a1fd-bb0aaf7e68ec"
    }
  ],
  "Amoxicillin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "amoxicillin-dog-1": "PO",
        "amoxicillin-cat-1": "PO"
      },
      "strengths": [
        250.0,
        500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b07b5ac4-253e-4c83-91c3-3fdc46e91a0f",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b07b5ac4-253e-4c83-91c3-3fdc46e91a0f"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "amoxicillin-dog-1": "PO",
        "amoxicillin-cat-1": "PO"
      },
      "concentrations": [
        25.0,
        40.0,
        50.0,
        80.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b07b5ac4-253e-4c83-91c3-3fdc46e91a0f",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b07b5ac4-253e-4c83-91c3-3fdc46e91a0f"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "amoxicillin-dog-1": "PO",
        "amoxicillin-cat-1": "PO"
      },
      "strengths": [
        500.0,
        875.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4eee2b38-ca84-421d-87e1-031bc5a3f3a7",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4eee2b38-ca84-421d-87e1-031bc5a3f3a7",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b07b5ac4-253e-4c83-91c3-3fdc46e91a0f"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "amoxicillin-dog-1": "SC/IV",
        "amoxicillin-cat-1": "SC/IV"
      }
    }
  ],
  "Enrofloxacin": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "enrofloxacin-dog-1": "PO",
        "enrofloxacin-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "enrofloxacin-dog-1": "IV/SC",
        "enrofloxacin-cat-1": "IV/SC"
      }
    }
  ],
  "Orbifloxacin": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "orbifloxacin-dog-1": "PO tablet",
        "orbifloxacin-cat-1": "PO tablet"
      }
    },
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "protocolRoutes": {
        "orbifloxacin-dog-2": "PO suspension",
        "orbifloxacin-cat-2": "PO suspension"
      }
    }
  ],
  "Pantoprazole": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "pantoprazole-dog-1": "PO",
        "pantoprazole-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "pantoprazole-dog-1": "IV",
        "pantoprazole-cat-1": "IV"
      }
    }
  ],
  "Metoclopramide": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "metoclopramide-dog-1": "PO",
        "metoclopramide-cat-1": "PO"
      },
      "concentrations": [
        1.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0034a97a-fb05-418a-a234-de278907cd2a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0034a97a-fb05-418a-a234-de278907cd2a"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "metoclopramide-dog-1": "PO",
        "metoclopramide-cat-1": "PO"
      },
      "strengths": [
        5.0,
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=447dbb34-7903-4e6a-be31-48a0b0e0d2f5",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=447dbb34-7903-4e6a-be31-48a0b0e0d2f5"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "metoclopramide-dog-1": "SC/IM",
        "metoclopramide-dog-2": "IV CRI",
        "metoclopramide-cat-1": "SC/IM",
        "metoclopramide-cat-2": "IV CRI"
      },
      "concentrations": [
        5.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cc739885-e10e-4bcb-a781-c726c518f3d1",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=dc4a13f8-1e9b-4c75-82c0-bcd11f0a9a66",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f50c8fb4-23c4-4762-95bb-e4ca7b289a4d"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cc739885-e10e-4bcb-a781-c726c518f3d1"
    }
  ],
  "Dexamethasone": [
    {
      "form": "Liquid",
      "label": "Oral elixir",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "dexamethasone-dog-1": "PO",
        "dexamethasone-cat-1": "PO"
      },
      "concentrations": [
        0.1
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7cf5c17c-a80b-4547-83b2-0d53e2b933f7",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7cf5c17c-a80b-4547-83b2-0d53e2b933f7"
      ],
      "customConcentration": true
    },
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "dexamethasone-dog-1": "PO",
        "dexamethasone-cat-1": "PO"
      },
      "concentrations": [
        0.1
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b15200fb-1826-472b-a907-e677a272513b",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b15200fb-1826-472b-a907-e677a272513b"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "dexamethasone-dog-1": "PO",
        "dexamethasone-cat-1": "PO"
      },
      "strengths": [
        0.25,
        0.5,
        0.75,
        1.0,
        1.5,
        2.0,
        4.0,
        6.0,
        20.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=05c77a4c-c508-babd-e063-6294a90a450a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=05c77a4c-c508-babd-e063-6294a90a450a",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6b9cf32c-6d60-4853-bbfd-2304ffc2c129",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a41e6e26-9ebb-4b06-866e-a24af21c644c",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b15200fb-1826-472b-a907-e677a272513b"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "dexamethasone-dog-2": "IV",
        "dexamethasone-cat-2": "IV"
      },
      "concentrations": [
        4.0,
        10.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0277cc0a-2fd4-4605-a310-b613be84ee26",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3c05089c-5a25-40c3-9abc-b2e40696bcdc",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4680d517-ed5a-4137-819c-122ee962a464",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=836f8017-d023-410b-8515-ec776e73ca59",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c9d9ab76-6bc6-433d-aad7-8d49064ed745",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=df77fab1-f58c-46db-e053-2a95a90a5416"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0277cc0a-2fd4-4605-a310-b613be84ee26"
    }
  ],
  "Methylprednisolone": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "methylprednisolone-cat-1": "PO",
        "methylprednisolone-dog-1": "PO"
      },
      "strengths": [
        2.0,
        4.0,
        8.0,
        16.0,
        32.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bdd048bb-7e6c-45c7-b51a-075e83ca9f5b",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bdd048bb-7e6c-45c7-b51a-075e83ca9f5b"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "methylprednisolone-cat-2": "IM"
      }
    }
  ],
  "Hydralazine": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "hydralazine-dog-1": "PO",
        "hydralazine-dog-2": "PO"
      },
      "strengths": [
        10.0,
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c7f9bd0-6c0a-4521-b77a-3582faa96874",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c7f9bd0-6c0a-4521-b77a-3582faa96874",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f9f56326-6d72-47d3-89ac-3625b8a6d713"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "hydralazine-cat-1": "SC"
      }
    }
  ],
  "Pregabalin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "protocolRoutes": {
        "pregabalin-dog-1": "PO",
        "pregabalin-cat-1": "PO",
        "pregabalin-cat-2": "PO"
      },
      "strengths": [
        25,
        50,
        75,
        100,
        150,
        200,
        225,
        300
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d4734e7d-5079-455e-8ff5-8f4539c998a9"
    },
    {
      "form": "Liquid",
      "label": "Oral solution \u00b7 20 mg/mL",
      "protocolRoutes": {
        "pregabalin-dog-1": "PO",
        "pregabalin-cat-1": "PO",
        "pregabalin-cat-2": "PO"
      },
      "concentrations": [
        20
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d4734e7d-5079-455e-8ff5-8f4539c998a9"
    },
    {
      "form": "Liquid",
      "label": "Compounded oral suspension",
      "protocolRoutes": {
        "pregabalin-dog-1": "PO",
        "pregabalin-cat-1": "PO",
        "pregabalin-cat-2": "PO"
      },
      "concentrations": [
        50
      ],
      "brand": "Compounded",
      "customConcentration": true
    },
    {
      "form": "Liquid",
      "label": "Oral solution \u00b7 Bonqat 50 mg/mL",
      "protocolRoutes": {
        "pregabalin-cat-bonqat": "PO"
      },
      "concentrations": [
        50
      ],
      "bonqat": true,
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4f7f35b4-59ec-4a3c-8c71-d28cf0c4f0eb",
      "brand": "Bonqat"
    }
  ],
  "Methocarbamol": [
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "methocarbamol-dog-1": "PO",
        "methocarbamol-cat-1": "PO"
      },
      "concentrations": [
        150.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=62de7345-613b-4838-96e5-aceca3cea6b2",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=62de7345-613b-4838-96e5-aceca3cea6b2"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "methocarbamol-dog-1": "PO",
        "methocarbamol-cat-1": "PO"
      },
      "strengths": [
        500.0,
        750.0,
        1000.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1dd56e3d-7ca7-1443-e063-6294a90a13c5",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1dd56e3d-7ca7-1443-e063-6294a90a13c5",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2df34fa7-9cdc-4be4-ac6f-577122462606",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=70c5342c-9597-4fe6-863c-f8ae4adc063a",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d8f10211-f96e-4cf3-9b49-986eb51b703d"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "methocarbamol-dog-2": "IV",
        "methocarbamol-cat-2": "IV"
      },
      "concentrations": [
        100.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b60000fc-e99b-4994-9d36-3907e0da9e06",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bc16295e-f3aa-4ed5-9fd6-ac4c750e0bba",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c88898af-5cd8-7bed-a03e-2ab4488e2040",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d48d76af-b55a-4908-95ff-e7de615c0513",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d9e4748f-11c5-4d87-b260-1be94febe806"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b60000fc-e99b-4994-9d36-3907e0da9e06"
    }
  ],
  "Hydroxyzine": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "hydroxyzine-dog-1": "PO",
        "hydroxyzine-cat-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=06068fff-2e79-4721-bcc7-b0938aa20e7a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=06068fff-2e79-4721-bcc7-b0938aa20e7a"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "hydroxyzine-dog-1": "PO",
        "hydroxyzine-cat-1": "PO"
      },
      "concentrations": [
        2.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4590101d-7fb2-478b-acc5-bc9bdbb38ca9",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4590101d-7fb2-478b-acc5-bc9bdbb38ca9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=87d4bbff-0498-4c26-86cb-7ce173afa0b6"
      ],
      "customConcentration": true
    },
    {
      "form": "Liquid",
      "label": "Oral syrup",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "hydroxyzine-dog-1": "PO",
        "hydroxyzine-cat-1": "PO"
      },
      "concentrations": [
        2.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=53b2d731-f38a-47c0-9e5c-abd3b45e2fe1",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=53b2d731-f38a-47c0-9e5c-abd3b45e2fe1"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "hydroxyzine-dog-1": "PO",
        "hydroxyzine-cat-1": "PO"
      },
      "strengths": [
        10.0,
        25.0,
        50.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2fc9b08a-e675-dbc5-e063-6294a90ad054",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2fc9b08a-e675-dbc5-e063-6294a90ad054",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=47bda4fe-ddb7-4140-900a-970373cc7acc",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5dea636d-dee6-47d4-b83c-b9f0c0b1b6ca",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7534a3bb-b4cd-415f-8612-53b37dc6d55f",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7f76580c-96a0-4b56-8986-ff5488bb9869",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=93d117dd-e2bf-4daa-abe3-d4fefed3313c"
      ]
    }
  ],
  "Cyclophosphamide": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cyclophosphamide-dog-1": "PO",
        "cyclophosphamide-dog-2": "PO",
        "cyclophosphamide-cat-1": "PO",
        "cyclophosphamide-cat-2": "PO"
      },
      "strengths": [
        25.0,
        50.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8135b917-882f-4b4c-99b7-fa8ea54af4bf",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8135b917-882f-4b4c-99b7-fa8ea54af4bf"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cyclophosphamide-dog-1": "PO",
        "cyclophosphamide-dog-2": "PO",
        "cyclophosphamide-cat-1": "PO",
        "cyclophosphamide-cat-2": "PO"
      },
      "strengths": [
        50.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=769ded74-6186-40a8-8e44-ceff67287451",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=769ded74-6186-40a8-8e44-ceff67287451"
      ]
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "cyclophosphamide-cat-1": "IV"
      }
    }
  ],
  "Gabapentin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "strengths": [
        100,
        200,
        300,
        400
      ],
      "brand": "Neurontin / generics",
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4cc6615b-5447-9c0e-e063-6394a90a2883"
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "strengths": [
        600,
        800
      ]
    }
  ],
  "Alprazolam": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "alprazolam-dog-1": "PO",
        "alprazolam-cat-1": "PO"
      },
      "strengths": [
        0.25,
        0.5,
        1.0,
        2.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d9b0e228-17cf-40d7-b62e-5050311c571c",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d9b0e228-17cf-40d7-b62e-5050311c571c"
      ]
    }
  ],
  "Amlodipine": [
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "amlodipine-dog-1": "PO",
        "amlodipine-cat-1": "PO"
      },
      "concentrations": [
        1.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=df673a4d-acb8-444c-a472-c87ab8cbd366",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=df673a4d-acb8-444c-a472-c87ab8cbd366"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "amlodipine-dog-1": "PO",
        "amlodipine-cat-1": "PO"
      },
      "strengths": [
        2.5,
        5.0,
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5a0b3dd4-91f5-4173-a992-e91b1cac6a18",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5a0b3dd4-91f5-4173-a992-e91b1cac6a18"
      ]
    }
  ],
  "Atenolol": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "atenolol-dog-1": "PO",
        "atenolol-cat-1": "PO",
        "atenolol-cat-2": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8dd93a47-d14c-49be-9c22-97c0cdbec75a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8dd93a47-d14c-49be-9c22-97c0cdbec75a"
      ]
    }
  ],
  "Azithromycin": [
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "azithromycin-dog-1": "PO",
        "azithromycin-cat-1": "PO"
      },
      "concentrations": [
        20.0,
        40.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c9de2e9-c20c-4660-a272-a22019f9fb02",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c9de2e9-c20c-4660-a272-a22019f9fb02"
      ],
      "customConcentration": true
    },
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "azithromycin-dog-1": "PO",
        "azithromycin-cat-1": "PO"
      },
      "concentrations": [
        20.0,
        40.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2b821631-0df2-0fb2-e054-00144ff8d46c",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2b821631-0df2-0fb2-e054-00144ff8d46c",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=db52b91e-79f7-4cc1-9564-f2eee8e31c45",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f97d2e7e-ccfd-4f04-85ba-549b37f6aa7b"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "azithromycin-dog-1": "PO",
        "azithromycin-cat-1": "PO"
      },
      "strengths": [
        250.0,
        500.0,
        600.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d5129e4-8b94-4a4d-baa9-be0d6b32d714",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d5129e4-8b94-4a4d-baa9-be0d6b32d714",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=16da30a2-d11c-7e8c-e063-6294a90a62e3",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1cec44fa-9597-3e58-e063-6394a90ae326",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=20ae108a-00c5-a984-e063-6394a90aaaae",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2cc93e72-95ce-965b-e063-6394a90a8917",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9c44af6d-8a9a-cb4c-e053-2a95a90afdac",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=db52b91e-79f7-4cc1-9564-f2eee8e31c45"
      ]
    }
  ],
  "Benazepril": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "benazepril-dog-1": "PO",
        "benazepril-cat-1": "PO"
      },
      "strengths": [
        5.0,
        10.0,
        20.0,
        40.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=67c64de1-5579-46e4-82ee-c9bbee708e02",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=67c64de1-5579-46e4-82ee-c9bbee708e02",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=910dac3a-728c-4f94-a514-e2b8f4680d39",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bb91223e-ffa5-4a3a-b191-fe121250c20c"
      ]
    }
  ],
  "Buspirone": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "buspirone-dog-1": "PO",
        "buspirone-cat-1": "PO"
      },
      "strengths": [
        5.0,
        7.5,
        10.0,
        15.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f101c5f3-d533-474d-a8bf-90d054933d16",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f101c5f3-d533-474d-a8bf-90d054933d16"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "buspirone-dog-1": "PO",
        "buspirone-cat-1": "PO"
      },
      "strengths": [
        2.5,
        5.0,
        7.5,
        10.0,
        12.5,
        15.0,
        30.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c516eec-65d9-4481-8823-ae6b6da84062",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c516eec-65d9-4481-8823-ae6b6da84062",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b9aa144c-cb36-4069-9eaa-7c150298cdd7"
      ]
    }
  ],
  "Cephalexin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cephalexin-dog-1": "PO",
        "cephalexin-cat-1": "PO"
      },
      "strengths": [
        250.0,
        333.0,
        500.0,
        750.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4fec8daf-6e09-4153-926f-64709dbdd26c",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4fec8daf-6e09-4153-926f-64709dbdd26c"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cephalexin-dog-1": "PO",
        "cephalexin-cat-1": "PO"
      },
      "concentrations": [
        25.0,
        50.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8a09bccd-1864-4dc3-9c31-6187d8e0fc99",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8a09bccd-1864-4dc3-9c31-6187d8e0fc99",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bb28751c-bd1b-4e7f-8271-a14c1b4314e3"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "cephalexin-dog-1": "PO",
        "cephalexin-cat-1": "PO"
      },
      "strengths": [
        250.0,
        500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=36882c6d-7b6f-41e3-8c54-e3b0073b8c07",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=36882c6d-7b6f-41e3-8c54-e3b0073b8c07",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e46059e1-3ce9-4a3c-80ce-464b140600ce"
      ]
    }
  ],
  "Chlorambucil": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "chlorambucil-dog-1": "PO",
        "chlorambucil-cat-1": "PO",
        "chlorambucil-cat-2": "PO"
      },
      "strengths": [
        2.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=58a3c995-5ad6-465d-8437-5970c9088213",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=58a3c995-5ad6-465d-8437-5970c9088213"
      ]
    }
  ],
  "Clindamycin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clindamycin-dog-1": "PO",
        "clindamycin-cat-1": "PO"
      },
      "strengths": [
        25.0,
        75.0,
        150.0,
        300.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=39c00714-331d-49b1-a675-653b82b10c98",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=39c00714-331d-49b1-a675-653b82b10c98",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e8167412-882e-4143-93c6-49e68adbcf16"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral liquid",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clindamycin-dog-1": "PO",
        "clindamycin-cat-1": "PO"
      },
      "concentrations": [
        25.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a2224602-6f04-4b83-968a-8c193230998f",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a2224602-6f04-4b83-968a-8c193230998f"
      ],
      "customConcentration": true
    },
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clindamycin-dog-1": "PO",
        "clindamycin-cat-1": "PO"
      },
      "concentrations": [
        15.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b35e3714-44d1-4e6a-a124-555ad259fec1",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b35e3714-44d1-4e6a-a124-555ad259fec1"
      ],
      "customConcentration": true
    }
  ],
  "Clomipramine": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clomipramine-dog-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        75.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ebad19b5-e5dd-4f77-ab97-d20ce0f24cb9",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ebad19b5-e5dd-4f77-ab97-d20ce0f24cb9"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clomipramine-dog-1": "PO"
      },
      "strengths": [
        5.0,
        20.0,
        80.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bed54123-2083-465f-97f3-0a796f2a37c7",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bed54123-2083-465f-97f3-0a796f2a37c7"
      ]
    }
  ],
  "Clonidine": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clonidine-dog-1": "PO"
      },
      "concentrations": [
        0.02,
        0.05
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=826de1dc-378e-4c90-86d1-e33f7a4248cd",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=826de1dc-378e-4c90-86d1-e33f7a4248cd",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c36d94f5-a30d-4997-b141-e79a4ea45ecf"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clonidine-dog-1": "PO"
      },
      "strengths": [
        0.05,
        0.1,
        0.2,
        0.3
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c83e4e4f-bd0e-449d-958a-dc0d570a01ba",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c83e4e4f-bd0e-449d-958a-dc0d570a01ba"
      ]
    }
  ],
  "Clopidogrel": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "clopidogrel-dog-1": "PO",
        "clopidogrel-cat-1": "PO",
        "clopidogrel-cat-2": "PO"
      },
      "strengths": [
        75.0,
        300.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=86ee71f2-850e-4c8e-87f3-c7a618d59d95",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=86ee71f2-850e-4c8e-87f3-c7a618d59d95",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b573aefa-e337-478f-97e4-eb8472a7e497",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d03cfc18-c9e4-41f8-b54d-6a7564c32afb"
      ]
    }
  ],
  "Digoxin": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "digoxin-dog-1": "PO",
        "digoxin-dog-2": "PO",
        "digoxin-cat-1": "PO",
        "digoxin-cat-2": "PO",
        "digoxin-cat-3": "PO"
      },
      "concentrations": [
        0.05
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ce62a741-a981-4880-8ce3-93269606a730",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ce62a741-a981-4880-8ce3-93269606a730"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "digoxin-dog-1": "PO",
        "digoxin-dog-2": "PO",
        "digoxin-cat-1": "PO",
        "digoxin-cat-2": "PO",
        "digoxin-cat-3": "PO"
      },
      "strengths": [
        0.0625,
        0.125,
        0.25
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2bcd56ee-4497-4b8d-84db-a1470c77827b",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2bcd56ee-4497-4b8d-84db-a1470c77827b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=48cad559-c17b-4d41-a154-e664e958c1c0"
      ]
    }
  ],
  "Diltiazem": [
    {
      "form": "Capsule",
      "label": "Capsule \u00b7 extended release",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "diltiazem-dog-2": "PO",
        "diltiazem-cat-2": "PO"
      },
      "strengths": [
        60.0,
        90.0,
        120.0,
        180.0,
        240.0,
        300.0,
        360.0,
        420.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=090aa3a9-910e-4f96-b748-783109aa96e6",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=090aa3a9-910e-4f96-b748-783109aa96e6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1042fa13-e6af-46b9-8008-6c941f0978b1",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9942f1a2-f66d-4d9e-9794-49bee8abf5ab",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d88e3546-3984-4dc9-893a-a29e95804550"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "diltiazem-dog-1": "PO",
        "diltiazem-cat-1": "PO"
      },
      "strengths": [
        30.0,
        60.0,
        90.0,
        120.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=69ca7cae-fdf3-413a-900b-95cf6e9e7b63",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=69ca7cae-fdf3-413a-900b-95cf6e9e7b63",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8329d0ac-d68c-48d2-9cbc-e1a1b60192d9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f3e7ecef-f360-4987-a4f5-933214130ab2"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet \u00b7 extended release",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "diltiazem-dog-2": "PO",
        "diltiazem-cat-2": "PO"
      },
      "strengths": [
        120.0,
        180.0,
        240.0,
        300.0,
        360.0,
        420.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f7137458-0db3-7ecd-e053-6394a90a5f95",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f7137458-0db3-7ecd-e053-6394a90a5f95"
      ]
    }
  ],
  "Doxycycline": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "doxycycline-dog-1": "PO",
        "doxycycline-dog-2": "PO",
        "doxycycline-cat-1": "PO",
        "doxycycline-cat-2": "PO"
      },
      "strengths": [
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8486639-7eb9-4610-9cd4-0e922045d592",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8486639-7eb9-4610-9cd4-0e922045d592"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "doxycycline-dog-1": "PO",
        "doxycycline-dog-2": "PO",
        "doxycycline-cat-1": "PO",
        "doxycycline-cat-2": "PO"
      },
      "concentrations": [
        5.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8486639-7eb9-4610-9cd4-0e922045d592",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8486639-7eb9-4610-9cd4-0e922045d592",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e0e80435-1b6a-4361-8c8a-e432f8f23a1b"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "doxycycline-dog-1": "PO",
        "doxycycline-dog-2": "PO",
        "doxycycline-cat-1": "PO",
        "doxycycline-cat-2": "PO"
      },
      "strengths": [
        20.0,
        50.0,
        75.0,
        100.0,
        150.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=294c6fc3-e7ca-46ea-b062-a27dd7b0bc97",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=294c6fc3-e7ca-46ea-b062-a27dd7b0bc97",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2deeee4f-b342-a178-e063-6394a90af897",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3b9888a2-ca16-43f7-ab6d-f03188ec2c0d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9f00b2c9-e628-4265-8530-3258dd3cdcd5",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b3cd7b44-db40-4ce5-895e-d4c85a0068ae",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8486639-7eb9-4610-9cd4-0e922045d592",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bc321932-b600-4659-a499-1853991b4ab9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fbd0a22f-b365-c0a2-e053-6394a90a1e07",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fd58dbe5-aab2-4378-b054-d5c60d87074e"
      ]
    }
  ],
  "Enalapril": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "enalapril-dog-1": "PO"
      },
      "concentrations": [
        1.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c7934b45-eb6b-44c1-bd2c-ef0fa10850c1",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c7934b45-eb6b-44c1-bd2c-ef0fa10850c1"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "enalapril-dog-1": "PO"
      },
      "strengths": [
        2.5,
        5.0,
        10.0,
        20.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8fe8dc52-dee6-4d33-b798-e90128011f46",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8fe8dc52-dee6-4d33-b798-e90128011f46"
      ]
    }
  ],
  "Fludrocortisone": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "fludrocortisone-dog-1": "PO"
      },
      "strengths": [
        0.1
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6c4a7d2d-00a4-4d80-ab4c-2afd4e4f614e",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6c4a7d2d-00a4-4d80-ab4c-2afd4e4f614e"
      ]
    }
  ],
  "Levothyroxine": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "levothyroxine-dog-1": "PO",
        "levothyroxine-dog-2": "PO"
      },
      "strengths": [
        0.025,
        0.05,
        0.075,
        0.088,
        0.1,
        0.112,
        0.125,
        0.137,
        0.15,
        0.175,
        0.2,
        0.3
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=18717e58-89fb-4e2f-93b6-d6ac3e988d37",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=18717e58-89fb-4e2f-93b6-d6ac3e988d37",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b8c20f76-3ee6-4b29-b77f-ed4ad1baaed9"
      ]
    }
  ],
  "Lomustine": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "lomustine-dog-1": "PO",
        "lomustine-cat-1": "PO"
      },
      "strengths": [
        10.0,
        40.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=916dfac8-da11-40e4-9e44-a909e29a6b5f",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=916dfac8-da11-40e4-9e44-a909e29a6b5f"
      ]
    }
  ],
  "Metronidazole": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "metronidazole-dog-1": "PO",
        "metronidazole-dog-2": "PO",
        "metronidazole-dog-3": "PO",
        "metronidazole-cat-1": "PO",
        "metronidazole-cat-2": "PO"
      },
      "strengths": [
        375.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f053ad94-d884-457c-9c35-4e0df1d26eea",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f053ad94-d884-457c-9c35-4e0df1d26eea"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "metronidazole-dog-1": "PO",
        "metronidazole-dog-2": "PO",
        "metronidazole-dog-3": "PO",
        "metronidazole-cat-1": "PO",
        "metronidazole-cat-2": "PO"
      },
      "concentrations": [
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e20c14eb-5361-4a93-ab46-a7bd9aeb9b98",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e20c14eb-5361-4a93-ab46-a7bd9aeb9b98"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "metronidazole-dog-1": "PO",
        "metronidazole-dog-2": "PO",
        "metronidazole-dog-3": "PO",
        "metronidazole-cat-1": "PO",
        "metronidazole-cat-2": "PO"
      },
      "strengths": [
        125.0,
        250.0,
        500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2ae49bf4-a23b-bdcc-e063-6294a90a80a9",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2ae49bf4-a23b-bdcc-e063-6294a90a80a9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9219588b-0a99-40b9-bdd4-ced6d6efebed"
      ]
    }
  ],
  "Minocycline": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "minocycline-dog-1": "PO",
        "minocycline-cat-1": "PO"
      },
      "strengths": [
        50.0,
        75.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9013ca48-15f2-43cd-a51d-91cf65c72a7c",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9013ca48-15f2-43cd-a51d-91cf65c72a7c"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "minocycline-dog-1": "PO",
        "minocycline-cat-1": "PO"
      },
      "strengths": [
        50.0,
        75.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3539f84e-b489-4914-96c1-ac3731032971",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3539f84e-b489-4914-96c1-ac3731032971",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=799a9871-3249-471e-b88d-5d8f7d4b96ad"
      ]
    }
  ],
  "Mirtazapine oral": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "mirtazapine-oral-cat-1": "PO",
        "mirtazapine-oral-dog-1": "PO",
        "mirtazapine-oral-dog-2": "PO",
        "mirtazapine-oral-dog-3": "PO",
        "mirtazapine-oral-dog-4": "PO"
      },
      "strengths": [
        7.5,
        15.0,
        30.0,
        45.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=98ad1917-a094-44f5-a28f-a64a8cfcd887",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=98ad1917-a094-44f5-a28f-a64a8cfcd887",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b4b9b66e-87a1-4dbb-9eaf-71221bcb2265",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f23631be-c7ae-46e9-b771-a70be17bc9f0"
      ]
    }
  ],
  "Mitotane": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "mitotane-dog-1": "PO",
        "mitotane-dog-2": "PO"
      },
      "strengths": [
        500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f0cd76e9-460c-450e-b094-172e636f340a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f0cd76e9-460c-450e-b094-172e636f340a"
      ]
    }
  ],
  "Paroxetine": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "paroxetine-dog-1": "PO",
        "paroxetine-cat-1": "PO"
      },
      "strengths": [
        7.5
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c5836c3-2099-452e-b6af-d2d50dc359fd",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=2c5836c3-2099-452e-b6af-d2d50dc359fd"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "paroxetine-dog-1": "PO",
        "paroxetine-cat-1": "PO"
      },
      "concentrations": [
        2.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=134e76f0-45cf-47eb-b6e1-cdb3bb522a0a",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=134e76f0-45cf-47eb-b6e1-cdb3bb522a0a",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=26d37a39-1c53-461c-8834-c67fbffcfe99"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "paroxetine-dog-1": "PO",
        "paroxetine-cat-1": "PO"
      },
      "strengths": [
        10.0,
        20.0,
        30.0,
        40.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4acd3e7a-4f19-4428-9452-48ce370cb3db",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4acd3e7a-4f19-4428-9452-48ce370cb3db",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b5a8f864-a53d-48d9-aca6-6b64017fb168"
      ]
    }
  ],
  "Selegiline": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "selegiline-dog-1": "PO"
      },
      "strengths": [
        5.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e42d99b0-c62e-49d4-b792-1301bb539b92",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e42d99b0-c62e-49d4-b792-1301bb539b92"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "selegiline-dog-1": "PO"
      },
      "strengths": [
        5.0,
        10.0,
        15.0,
        30.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=84e25a59-1db6-42bf-b27e-a25c4883a141",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=84e25a59-1db6-42bf-b27e-a25c4883a141",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f286c854-3b8c-44a8-b3b5-c828dbabb207"
      ]
    }
  ],
  "Sertraline": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sertraline-dog-1": "PO",
        "sertraline-cat-1": "PO"
      },
      "strengths": [
        150.0,
        200.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3a3efb5f-b24a-438d-9253-371ff3b5417d",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3a3efb5f-b24a-438d-9253-371ff3b5417d"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sertraline-dog-1": "PO",
        "sertraline-cat-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=de1f85ac-df1b-4b7b-8e18-48ebdc8b9279",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=de1f85ac-df1b-4b7b-8e18-48ebdc8b9279",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fda754f6-d0f3-4dce-a17a-927d64f912f7"
      ]
    }
  ],
  "Sildenafil": [
    {
      "form": "Liquid",
      "label": "Oral suspension (after reconstitution)",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sildenafil-dog-1": "PO",
        "sildenafil-cat-1": "PO"
      },
      "concentrations": [
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3bb9363e-b28d-4019-8aae-539233dca214",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3bb9363e-b28d-4019-8aae-539233dca214",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8526e8f2-4bb4-430b-9e38-68ee68caa5a4",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9de84092-ebe6-436c-a925-88a6e3861eba"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sildenafil-dog-1": "PO",
        "sildenafil-cat-1": "PO"
      },
      "strengths": [
        20.0,
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=31c0f8ab-ed2e-4ead-a8c0-4055f6c43783",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=31c0f8ab-ed2e-4ead-a8c0-4055f6c43783",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3bb9363e-b28d-4019-8aae-539233dca214",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6d8dbaa6-d61a-46ae-a641-f664104f4714",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=dc998a9c-0770-111b-e053-2a95a90a88a4"
      ]
    }
  ],
  "Spironolactone": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "spironolactone-dog-1": "PO",
        "spironolactone-dog-2": "PO",
        "spironolactone-cat-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=852684dc-e1c6-4caa-bccb-10ac90bbb3bb",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=852684dc-e1c6-4caa-bccb-10ac90bbb3bb",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=963af399-feb7-49d2-a59c-c19edad9c682",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fb66327e-8261-46ae-b39a-4fa79d520844"
      ]
    }
  ],
  "Sucralfate": [
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sucralfate-dog-1": "PO",
        "sucralfate-cat-1": "PO"
      },
      "concentrations": [
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3054ce94-78a2-4da4-8b14-95311b412ab2",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3054ce94-78a2-4da4-8b14-95311b412ab2"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "sucralfate-dog-1": "PO",
        "sucralfate-cat-1": "PO"
      },
      "strengths": [
        1000.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=989ca8a8-3ad6-4ee4-aa9c-eed731828753",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=989ca8a8-3ad6-4ee4-aa9c-eed731828753"
      ]
    }
  ],
  "Telmisartan": [
    {
      "form": "Liquid",
      "label": "Oral solution",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "telmisartan-cat-1": "PO",
        "telmisartan-cat-2": "PO",
        "telmisartan-cat-3": "PO"
      },
      "concentrations": [
        10.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f436a826-9f5b-4269-b4ec-97d5522eaca6",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f436a826-9f5b-4269-b4ec-97d5522eaca6"
      ],
      "customConcentration": true
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "telmisartan-cat-1": "PO",
        "telmisartan-cat-2": "PO",
        "telmisartan-cat-3": "PO"
      },
      "strengths": [
        20.0,
        40.0,
        80.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9c22a318-d1f2-4788-9331-66fed71ebf38",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9c22a318-d1f2-4788-9331-66fed71ebf38"
      ]
    }
  ],
  "Torsemide": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "torsemide-dog-1": "PO",
        "torsemide-cat-1": "PO",
        "torsemide-cat-2": "PO"
      },
      "strengths": [
        5.0,
        10.0,
        20.0,
        40.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=05eaa163-b6e9-438a-85f8-6a60e743d460",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=05eaa163-b6e9-438a-85f8-6a60e743d460",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=234ff9d7-a02e-417f-a1f9-94038783cc77"
      ]
    }
  ],
  "Tramadol": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "tramadol-dog-1": "PO",
        "tramadol-cat-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        75.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=24aea499-c6f1-9200-e063-6394a90a9db6",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=24aea499-c6f1-9200-e063-6394a90a9db6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=93b12089-3a0f-4b57-abb1-2429cf31995d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a6cbd5de-8ae5-49e3-b89b-e35536b115d8",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b5852b90-e415-47ef-8f73-87266b58e033"
      ]
    }
  ],
  "Ursodiol": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "ursodiol-dog-1": "PO",
        "ursodiol-cat-1": "PO"
      },
      "strengths": [
        150.0,
        200.0,
        300.0,
        400.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3617fb7a-1f57-4276-bebb-ae6ba4252d4e",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3617fb7a-1f57-4276-bebb-ae6ba4252d4e",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=476179dc-b410-4305-881b-470511765647",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6163fc42-5910-4e19-9e32-3d8e81f50128"
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "ursodiol-dog-1": "PO",
        "ursodiol-cat-1": "PO"
      },
      "strengths": [
        250.0,
        500.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e8fc4fc2-fe5c-4cba-b6e0-5ceaf2157a61",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e8fc4fc2-fe5c-4cba-b6e0-5ceaf2157a61",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fb79b62a-b450-4d7a-be28-5ee4d174fd58"
      ]
    }
  ],
  "Zonisamide": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "zonisamide-dog-1": "PO",
        "zonisamide-cat-1": "PO"
      },
      "strengths": [
        25.0,
        50.0,
        100.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5ab5b6aa-4bdc-4ec6-ba23-44caf2db953e",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=5ab5b6aa-4bdc-4ec6-ba23-44caf2db953e"
      ]
    },
    {
      "form": "Liquid",
      "label": "Oral suspension",
      "brand": "Generic / see product label",
      "protocolRoutes": {
        "zonisamide-dog-1": "PO",
        "zonisamide-cat-1": "PO"
      },
      "concentrations": [
        20.0
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ac16fa15-32e9-4f92-8bc6-d8d41ae002c6",
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ac16fa15-32e9-4f92-8bc6-d8d41ae002c6"
      ],
      "customConcentration": true
    }
  ],
  "Butorphanol": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "butorphanol-dog-1": "IV/IM/SC",
        "butorphanol-dog-2": "IV",
        "butorphanol-dog-3": "IV CRI",
        "butorphanol-cat-1": "IV/IM/SC",
        "butorphanol-cat-2": "IV",
        "butorphanol-cat-3": "IV CRI"
      },
      "concentrations": [
        1.0,
        2.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9822ca3f-aee2-46e5-8a96-495400e65d10"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9822ca3f-aee2-46e5-8a96-495400e65d10"
    }
  ],
  "Hydromorphone": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "hydromorphone-dog-1": "IV/IM/SC",
        "hydromorphone-dog-2": "IV",
        "hydromorphone-dog-3": "IV CRI",
        "hydromorphone-cat-1": "IV/IM/SC",
        "hydromorphone-cat-2": "IV",
        "hydromorphone-cat-3": "IV CRI"
      },
      "concentrations": [
        0.2,
        1.0,
        2.0,
        4.0,
        10.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=31d5a37a-0e90-4e88-be14-75c877be9de2",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9eebd88a-5632-460f-b7b6-26c8a180540d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e034eb96-03e0-46e1-8b92-5e1f94555e7b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f9ca2ef5-46d8-475a-a26e-f7c8becd6db7"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=31d5a37a-0e90-4e88-be14-75c877be9de2"
    }
  ],
  "Fentanyl": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "fentanyl-dog-1": "IV",
        "fentanyl-dog-2": "IV CRI",
        "fentanyl-cat-1": "IV",
        "fentanyl-cat-2": "IV CRI"
      },
      "concentrations": [
        0.05
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c10e465-4117-48ba-a454-23ccb7a3fcc7",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=38d0c14a-a0c1-44cc-a939-0304eb8037d6",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ce5db1c2-feb1-4ad2-847a-d02e865bd47e"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c10e465-4117-48ba-a454-23ccb7a3fcc7"
    }
  ],
  "Ketamine": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "ketamine-dog-1": "IV",
        "ketamine-dog-3": "IV",
        "ketamine-dog-2": "IV CRI",
        "ketamine-cat-1": "IV",
        "ketamine-cat-3": "IV",
        "ketamine-cat-2": "IV CRI"
      },
      "concentrations": [
        10.0,
        50.0,
        100.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=902c3785-a3cb-472b-ac15-394ac646271d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bb912318-2e22-4469-b0a2-774803ee1bb8",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cc67b0fd-ca73-49f6-b5ca-705dc7331776"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=902c3785-a3cb-472b-ac15-394ac646271d"
    }
  ],
  "Midazolam": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "midazolam-dog-1": "IV/IM",
        "midazolam-dog-2": "IV",
        "midazolam-dog-3": "intranasal",
        "midazolam-dog-4": "IV CRI",
        "midazolam-cat-1": "IV/IM",
        "midazolam-cat-2": "IV",
        "midazolam-cat-3": "intranasal",
        "midazolam-cat-4": "IV CRI"
      },
      "concentrations": [
        1.0,
        5.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1cc9ba6e-fa1b-405e-9de8-720c567b2a73",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4155a60a-b023-4f4a-acae-7bb8fe9dc0c1",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=74666098-1ca8-4c06-8fc4-5de870b1b514",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8675cdb1-c7f5-40cf-b1e0-0960b7ab117b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=9221894f-d840-46f2-a11c-6b71358d3b5b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=adfe8ece-496d-4118-9990-a1d44d0ac7d9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c546cfd4-4f2b-4b94-aa47-995595f1a146"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1cc9ba6e-fa1b-405e-9de8-720c567b2a73"
    }
  ],
  "Diazepam": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "diazepam-dog-1": "IV",
        "diazepam-dog-2": "per rectum",
        "diazepam-dog-3": "IV CRI",
        "diazepam-cat-1": "IV",
        "diazepam-cat-3": "IV CRI"
      },
      "concentrations": [
        5.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a0813073-d0b0-4fd7-b307-56f69c910c82",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f466f8a3-f31c-44f4-b0e8-444464f20f66",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=fa352464-14c8-49e9-b8b7-5a968b1cfa93"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a0813073-d0b0-4fd7-b307-56f69c910c82"
    }
  ],
  "Dexmedetomidine": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "dexmedetomidine-dog-1": "IV",
        "dexmedetomidine-dog-2": "IM",
        "dexmedetomidine-cat-1": "IM"
      },
      "concentrations": [
        0.004,
        0.1
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d2710f2-ee47-4114-ab5c-8dca74cdcb8d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=42cbeadf-fea3-d2ae-e063-6394a90ad549",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8c162541-986b-4b30-866c-b2631ba2c975",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ada70a68-3e52-4b94-e053-2995a90aa1e0",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=aea9a3ad-c244-42be-9cd3-5df83fe2b522",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f140de5a-f13d-46b4-a742-049c63e474f5"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d2710f2-ee47-4114-ab5c-8dca74cdcb8d"
    }
  ],
  "Alfaxalone": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "alfaxalone-dog-1": "IV",
        "alfaxalone-cat-1": "IV"
      },
      "concentrations": [
        10.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f412f5c3-5ba8-43c2-8920-510f34e67f53"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f412f5c3-5ba8-43c2-8920-510f34e67f53"
    }
  ],
  "Epinephrine": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "epinephrine-dog-1": "IV/IO",
        "epinephrine-cat-1": "IV/IO"
      },
      "concentrations": [
        0.1,
        1.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=04f07f15-55e2-411b-abb8-07eab37f5664",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=386519ba-7a44-4edd-9eb1-748419b7a71b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4f83895f-638c-4515-af03-7c41ae60a42e",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6180fb40-7fca-4602-b3da-ce62b8cd2470",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=677c33a2-4e16-406e-e053-2991aa0a4594",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6add7604-71f6-4d8a-9447-17ad01fa839d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6e811e28-0199-4df7-a916-5940c632401d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7499cbca-b8fe-4fc3-a318-13859ab989a7",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=7663c49d-1b1d-755d-e053-2991aa0a4ee3",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c0d1def8-9f47-0d3e-e053-2995a90af955",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=db18519b-82a9-435b-85c7-a040d644f057"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=04f07f15-55e2-411b-abb8-07eab37f5664"
    }
  ],
  "Atropine injection": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "atropine-injection-dog-1": "IV/IM/SC",
        "atropine-injection-dog-2": "IV/IO",
        "atropine-injection-cat-1": "IV/IM/SC",
        "atropine-injection-cat-2": "IV/IO"
      },
      "concentrations": [
        0.05,
        0.1,
        0.4,
        1.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4c15d3cc-7888-4c82-b3f8-a5d93c5523df",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=532aa441-92ec-42d6-862a-639f8cfe9951",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=6fee1727-52b7-4f73-ab45-ef47d6a1c5bb",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=768dc21a-b7d9-144c-e053-2991aa0af889",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a66eecf9-2d8b-4e2d-8a05-d718dcbc3542",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ad8916e7-206e-409e-2582-30d072845dd4",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c82cb295-ffce-47d6-97ad-a8aa723f4e4f",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d4839e54-b350-4643-8e6e-f0437f5349d6"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4c15d3cc-7888-4c82-b3f8-a5d93c5523df"
    }
  ],
  "Glycopyrrolate": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "glycopyrrolate-dog-1": "IV/IM/SC",
        "glycopyrrolate-cat-1": "IV/IM/SC"
      },
      "concentrations": [
        0.2
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4ecb3435-58e5-46cb-b8c2-85b5fd955f83",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=765490fa-8378-40c8-9fa7-b0bfa2e1a0a9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ccafb5c2-86dd-4bb2-883a-c13e3171227c"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4ecb3435-58e5-46cb-b8c2-85b5fd955f83"
    }
  ],
  "Lidocaine": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "lidocaine-dog-1": "IV",
        "lidocaine-dog-2": "IV CRI",
        "lidocaine-cat-1": "IV",
        "lidocaine-cat-2": "IV CRI"
      },
      "concentrations": [
        5.0,
        10.0,
        15.0,
        20.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c0790ec-effd-4d8a-9874-8ca0b31e54d0",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=1631e5ca-03d0-4d3b-91e3-2dc14f4eb0e1",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=240c4744-e58c-4c08-93ad-8d6418c4f8a9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3b2dd84e-cee8-4e58-d494-395a65a353a0",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=a5d4b206-cc53-470f-9bca-abfc6ea5cc99",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ad1ef0a8-88db-4648-c098-d009eaeb4e5b",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ba082c2f-64f4-419d-9c88-74f203316e17",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d5e0d06f-ba1e-44d4-aa89-39d6c146dc23",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e0e479e6-4c94-44d0-8074-d0ee7b2bde22",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=f824b48c-7039-4ce1-b3df-b3597aba5beb"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0c0790ec-effd-4d8a-9874-8ca0b31e54d0"
    }
  ],
  "Naloxone": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "naloxone-dog-1": "IV/IO",
        "naloxone-cat-1": "IV/IO"
      },
      "concentrations": [
        0.4,
        1.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=201fdedf-1736-4e52-9d7d-de14292547fd",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=958577c3-d2c4-26ad-e053-2a95a90ad73a",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e6467385-6990-498c-8a0e-f4a40ef33cb7"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=201fdedf-1736-4e52-9d7d-de14292547fd"
    }
  ],
  "Mannitol": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "mannitol-dog-1": "IV infusion",
        "mannitol-dog-2": "IV infusion",
        "mannitol-cat-1": "IV infusion",
        "mannitol-cat-2": "IV infusion"
      },
      "concentrations": [
        100.0,
        200.0,
        250.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d914965-7001-45cb-ba51-d7c5964b05bc",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=430669d7-9ad1-9a04-e063-6394a90ababb",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=999ce711-2d5b-0d7d-e053-2995a90a2689"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=0d914965-7001-45cb-ba51-d7c5964b05bc"
    }
  ],
  "Calcium gluconate": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "calcium-gluconate-dog-1": "slow IV",
        "calcium-gluconate-cat-1": "slow IV"
      },
      "concentrations": [
        100.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8b77c3d2-992d-4261-8421-9cfd07328fbf"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8b77c3d2-992d-4261-8421-9cfd07328fbf"
    }
  ],
  "Dextrose": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "dextrose-dog-1": "slow IV",
        "dextrose-cat-1": "slow IV"
      },
      "concentrations": [
        50.0,
        100.0,
        200.0,
        250.0,
        300.0,
        400.0,
        500.0,
        700.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=10e98cb0-31a5-4ad1-3eaa-aa4af387a42d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=36e9478c-5df0-4b47-b97d-de3626d7cb29",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3bb406a9-f5cb-403a-b1bb-5c4facbea3d5",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=4ed365da-4e62-4329-c1b9-c197ab4fb6e1",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=50603082-bce5-49eb-9737-e04239cfb695",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=672264e3-9709-4bba-2a9d-12bf70c7396a",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8b25b7e0-703e-4b43-a4eb-52863511602d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8e7046f8-841e-465a-af69-af9fb3d6799d",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=b5cb7a5a-bbe8-4217-a82e-da818f7771c9",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=bd250a46-d229-4e80-b5a1-b34169ccecc4",
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cb578dba-094c-4787-951d-763d12fd06e1"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=10e98cb0-31a5-4ad1-3eaa-aa4af387a42d"
    }
  ],
  "Vincristine": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "vincristine-dog-1": "IV only",
        "vincristine-cat-1": "IV only"
      },
      "concentrations": [
        1.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=49596de6-ab18-49d1-9e5b-30968fc21c36"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=49596de6-ab18-49d1-9e5b-30968fc21c36"
    }
  ],
  "Doxorubicin": [
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "doxorubicin-dog-1": "IV",
        "doxorubicin-dog-2": "IV",
        "doxorubicin-cat-1": "IV"
      },
      "concentrations": [
        2.0
      ],
      "keepProtocolConcentration": true,
      "productSources": [
        "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=36924f82-6c05-4989-9f41-a398c0ad48e6"
      ],
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=36924f82-6c05-4989-9f41-a398c0ad48e6"
    }
  ]
}
"""#
        return try! JSONDecoder().decode([String: [MedicationFormulation]].self, from: Data(json.utf8))
    }()
    static let organized: [Medication] = ClinicalData.medications.flatMap { original in
        guard let variants = rules[original.generic] else { return [original] }
        return variants.map { variant in
            let form = MedicationForm(rawValue: variant.form)!
            var medication = Medication(generic: original.generic, brand: variant.brand ?? original.brand,
                drugClass: original.drugClass, species: variant.bonqat == true ? [.cat] : Set(original.species.filter { species in
                    variant.protocolRoutes == nil || BuiltInProtocolCatalog.all.contains { $0.species == species && variant.protocolRoutes?[$0.id] != nil }
                }), form: form,
                indication: original.indication, kind: original.kind, minDose: original.minDose,
                maxDose: original.maxDose, frequency: original.frequency, route: original.route,
                notes: original.notes, source: original.source,
                strengths: variant.strengths ?? (form == original.form ? original.strengths : []),
                concentration: variant.customConcentration == true ? nil : variant.keepProtocolConcentration == true ? original.concentration : variant.concentrations?.first ?? (form == original.form ? original.concentration : nil),
                controlled: original.controlled)
            medication.formulation = variant
            return medication
        }
    }
    static func definition(_ definition: ProtocolMedicationDefinition, for medication: Medication) -> ProtocolMedicationDefinition {
        guard let variant = medication.formulation else { return definition }
        var result = definition
        let id = result.medicationKey.replacingOccurrences(of: "builtin|", with: "")
        result.route = variant.protocolRoutes?[id] ?? result.route
        if [.tablet, .capsule].contains(medication.form) {
            result.strengths = variant.strengths ?? result.strengths
            result.concentration = nil
        } else {
            result.strengths = []
            result.concentration = variant.customConcentration == true ? nil : variant.keepProtocolConcentration == true ? result.concentration : variant.concentrations?.first ?? (medication.generic == "Pregabalin" ? nil : result.concentration)
        }
        return result
    }
}
