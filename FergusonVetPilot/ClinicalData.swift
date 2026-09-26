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
            let haystack = [m.generic, m.brand, m.drugClass, m.indication, m.form.rawValue].joined(separator: " ").lowercased()
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
    var bonqat: Bool? = nil
    var customConcentration: Bool? = nil
}

enum MedicationFormulations {
    static let rules: [String: [MedicationFormulation]] = {
        let json = #"""
{
  "Levetiracetam": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "levetiracetam-dog-1": "PO",
        "levetiracetam-dog-2": "PO \u2014 ER tablet whole",
        "levetiracetam-cat-1": "PO",
        "levetiracetam-cat-2": "PO \u2014 ER tablet whole"
      }
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
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "famotidine-dog-1": "PO",
        "famotidine-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "famotidine-dog-1": "IV"
      }
    }
  ],
  "Ondansetron": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "ondansetron-dog-1": "PO",
        "ondansetron-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "ondansetron-dog-2": "IV",
        "ondansetron-cat-2": "IV"
      }
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
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "cetirizine-dog-1": "PO",
        "cetirizine-dog-2": "PO",
        "cetirizine-cat-1": "PO",
        "cetirizine-cat-2": "PO"
      }
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
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "furosemide-dog-1": "IV/IM",
        "furosemide-dog-3": "IV CRI",
        "furosemide-cat-1": "IV/IM",
        "furosemide-cat-3": "IV CRI"
      }
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "furosemide-dog-2": "PO",
        "furosemide-cat-2": "PO"
      }
    }
  ],
  "Amoxicillin": [
    {
      "form": "Capsule",
      "label": "Capsule",
      "protocolRoutes": {
        "amoxicillin-dog-1": "PO",
        "amoxicillin-cat-1": "PO"
      }
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
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "metoclopramide-dog-1": "PO",
        "metoclopramide-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "metoclopramide-dog-1": "SC/IM",
        "metoclopramide-dog-2": "IV CRI",
        "metoclopramide-cat-1": "SC/IM",
        "metoclopramide-cat-2": "IV CRI"
      }
    }
  ],
  "Dexamethasone": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "dexamethasone-dog-1": "PO",
        "dexamethasone-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "dexamethasone-dog-2": "IV",
        "dexamethasone-cat-2": "IV"
      }
    }
  ],
  "Methylprednisolone": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "methylprednisolone-cat-1": "PO",
        "methylprednisolone-dog-1": "PO"
      }
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
      "protocolRoutes": {
        "hydralazine-dog-1": "PO",
        "hydralazine-dog-2": "PO"
      }
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
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "methocarbamol-dog-1": "PO",
        "methocarbamol-cat-1": "PO"
      }
    },
    {
      "form": "Injection",
      "label": "Injection",
      "protocolRoutes": {
        "methocarbamol-dog-2": "IV",
        "methocarbamol-cat-2": "IV"
      }
    }
  ],
  "Hydroxyzine": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "hydroxyzine-dog-1": "PO",
        "hydroxyzine-cat-1": "PO"
      },
      "productSource": "https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=7279ad5a-0a49-432d-8fa2-17e4c6ecbadc"
    }
  ],
  "Cyclophosphamide": [
    {
      "form": "Tablet",
      "label": "Tablet",
      "protocolRoutes": {
        "cyclophosphamide-dog-1": "PO",
        "cyclophosphamide-dog-2": "PO",
        "cyclophosphamide-cat-1": "PO",
        "cyclophosphamide-cat-2": "PO"
      }
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
        300,
        400
      ]
    },
    {
      "form": "Tablet",
      "label": "Tablet",
      "strengths": [
        600,
        800
      ]
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
                concentration: variant.customConcentration == true ? nil : variant.concentrations?.first ?? (form == original.form ? original.concentration : nil),
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
            result.concentration = variant.customConcentration == true ? nil : variant.concentrations?.first ?? (medication.generic == "Pregabalin" ? nil : result.concentration)
        }
        return result
    }
}
