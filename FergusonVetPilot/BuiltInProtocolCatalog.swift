import Foundation

enum BuiltInProtocolCatalog {
    static let all: [BuiltInProtocolPreset] = [
        BuiltInProtocolPreset(
            id: "metronidazole-dog-1", generic: "Metronidazole", species: .dog,
            label: "GI / anaerobic protocol 10–15 mg/kg", doseBasis: .mgKg, minDose: 10, maxDose: 15,
            frequency: "q12h", route: "PO", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual GI/antimicrobial guidance.", notes: "Indication-specific extra-label protocol; neurologic toxicity can occur with excessive exposure or prolonged high dosing. Do not substitute this branch for giardiasis or hepatic encephalopathy.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metronidazole-dog-2", generic: "Metronidazole", species: .dog,
            label: "Giardiasis 25 mg/kg", doseBasis: .mgKg, minDose: 25, maxDose: 25,
            frequency: "q12h for 5 days", route: "PO", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual giardiasis guidance.", notes: "Canine giardiasis branch only. Confirm diagnosis and current antiparasitic strategy; avoid unnecessary antimicrobial exposure.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metronidazole-dog-3", generic: "Metronidazole", species: .dog,
            label: "Hepatic encephalopathy 7.5 mg/kg", doseBasis: .mgKg, minDose: 7.5, maxDose: 7.5,
            frequency: "q8–12h", route: "PO", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual hepatic encephalopathy guidance.", notes: "Hepatic encephalopathy branch only; hepatic dysfunction can alter drug handling. Monitor neurologic status and clinical response.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metronidazole-cat-1", generic: "Metronidazole", species: .cat,
            label: "GI / anaerobic protocol 10–15 mg/kg", doseBasis: .mgKg, minDose: 10, maxDose: 15,
            frequency: "q12h", route: "PO", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual GI/antimicrobial guidance.", notes: "Indication-specific extra-label protocol; neurologic toxicity can occur with excessive exposure or prolonged high dosing. Hepatic encephalopathy uses a lower separate branch.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metronidazole-cat-2", generic: "Metronidazole", species: .cat,
            label: "Hepatic encephalopathy 7.5 mg/kg", doseBasis: .mgKg, minDose: 7.5, maxDose: 7.5,
            frequency: "q8–12h", route: "PO", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual hepatic encephalopathy guidance.", notes: "Hepatic encephalopathy branch only; hepatic dysfunction can alter drug handling. Monitor neurologic status and clinical response.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "doxycycline-dog-1", generic: "Doxycycline", species: .dog,
            label: "Respiratory bacterial indication: divided daily regimen", doseBasis: .mgKg, minDose: 5.0, maxDose: 5.0,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://doi.org/10.1111/jvim.14627", notes: "Cats need food/water after tablets/capsules; duration organism-specific Extra-label branches; antimicrobial stewardship Research preload rule: 5–10 mg/kg PO q12–24h; 10 mg/kg q12h for selected vector/Wolbachia protocols",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "doxycycline-dog-2", generic: "Doxycycline", species: .dog,
            label: "Respiratory bacterial indication: once-daily regimen", doseBasis: .mgKg, minDose: 10.0, maxDose: 10.0,
            frequency: "q24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://doi.org/10.1111/jvim.14627", notes: "Cats need food/water after tablets/capsules; duration organism-specific Extra-label branches; antimicrobial stewardship Research preload rule: 5–10 mg/kg PO q12–24h; 10 mg/kg q12h for selected vector/Wolbachia protocols",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "doxycycline-cat-1", generic: "Doxycycline", species: .cat,
            label: "Respiratory bacterial indication: divided daily regimen", doseBasis: .mgKg, minDose: 5, maxDose: 5,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://doi.org/10.1111/jvim.14627", notes: "Cats need food/water after tablets/capsules; duration organism-specific Extra-label branches; antimicrobial stewardship Research preload rule: 5–10 mg/kg PO q12–24h; 10 mg/kg q12h for selected vector/Wolbachia protocols",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "doxycycline-cat-2", generic: "Doxycycline", species: .cat,
            label: "Selected feline heartworm/Wolbachia regimen", doseBasis: .mgKg, minDose: 10.0, maxDose: 10.0,
            frequency: "q12h for 28 days", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/circulatory-system/heartworm-disease/heartworm-disease-in-dogs-cats-and-ferrets", notes: "Cats need food/water after tablets/capsules; duration organism-specific Extra-label branches; antimicrobial stewardship Research preload rule: 5–10 mg/kg PO q12–24h; 10 mg/kg q12h for selected vector/Wolbachia protocols",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "prednisone-prednisolone-dog-1", generic: "Prednisone/prednisolone", species: .dog,
            label: "0.5–1 mg/kg anti-inflammatory; immunosuppressive higher", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q24h initially; taper/alternate-day interval by response", route: "PO", strengths: [20], concentration: nil,
            sourceReference: "MSD corticosteroid/immune protocols.", notes: "Require indication; taper; NSAID interaction Extra-label use common; do not auto-select immunosuppressive vs anti-inflammatory dose Research preload rule: Anti-inflammatory 0.5–1 mg/kg/day; immunosuppression ~2–4 mg/kg/day by species/indication",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "prednisone-prednisolone-cat-1", generic: "Prednisone/prednisolone", species: .cat,
            label: "Prednisolone 1–2 mg/kg anti-inflammatory; immunosuppressive higher", doseBasis: .mgKg, minDose: 1.0, maxDose: 2.0,
            frequency: "q24h initially; taper by response", route: "PO", strengths: [20], concentration: nil,
            sourceReference: "MSD corticosteroid/immune protocols.", notes: "Require indication; taper; NSAID interaction Extra-label use common; do not auto-select immunosuppressive vs anti-inflammatory dose Research preload rule: Anti-inflammatory 0.5–1 mg/kg/day; immunosuppression ~2–4 mg/kg/day by species/indication",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-dog-1", generic: "Levetiracetam", species: .dog,
            label: "Immediate-release 20–60 mg/kg", doseBasis: .mgKg, minDose: 20, maxDose: 60,
            frequency: "q8h", route: "PO", strengths: [250, 500, 750, 1000], concentration: nil,
            sourceReference: "MSD Veterinary Manual epilepsy guidance.", notes: "Immediate-release oral branch. Do not substitute extended-release tablets at this frequency.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-dog-2", generic: "Levetiracetam", species: .dog,
            label: "Extended-release 30 mg/kg", doseBasis: .mgKg, minDose: 30, maxDose: 30,
            frequency: "q12h", route: "PO — ER tablet whole", strengths: [500, 750], concentration: nil,
            sourceReference: "MSD Veterinary Manual epilepsy guidance.", notes: "Extended-release branch. ER tablets must remain whole; do not crush, break, or chew.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-dog-3", generic: "Levetiracetam", species: .dog,
            label: "Status/cluster IV 30–60 mg/kg", doseBasis: .mgKg, minDose: 30, maxDose: 60,
            frequency: "over 5–15 min", route: "IV", strengths: [], concentration: 100,
            sourceReference: "MSD Veterinary Manual epilepsy guidance.", notes: "Emergency IV branch for status epilepticus or cluster seizures. Verify the injectable product concentration before administration.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-cat-1", generic: "Levetiracetam", species: .cat,
            label: "Immediate-release 20–60 mg/kg", doseBasis: .mgKg, minDose: 20, maxDose: 60,
            frequency: "q8h", route: "PO", strengths: [250, 500, 750, 1000], concentration: nil,
            sourceReference: "MSD Veterinary Manual epilepsy guidance.", notes: "Immediate-release oral branch. Do not crush or substitute an extended-release product.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-cat-2", generic: "Levetiracetam", species: .cat,
            label: "Specialist protocol required — feline ER regimen unverified", doseBasis: .mgKg, minDose: 30, maxDose: 30,
            frequency: "q12h", route: "PO — ER tablet whole", strengths: [500, 750], concentration: nil,
            sourceReference: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5980453/", notes: "Automatic calculation blocked pending species-specific regimen review. Healthy-cat pharmacokinetic studies are not evidence of clinical seizure efficacy; ER tablets cannot be split.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "levetiracetam-cat-3", generic: "Levetiracetam", species: .cat,
            label: "Status/cluster IV 30–60 mg/kg", doseBasis: .mgKg, minDose: 30, maxDose: 60,
            frequency: "over 5–15 min", route: "IV", strengths: [], concentration: 100,
            sourceReference: "MSD Veterinary Manual epilepsy guidance.", notes: "Emergency IV branch for status epilepticus or cluster seizures. Verify the injectable product concentration before administration.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "omeprazole-dog-1", generic: "Omeprazole", species: .dog,
            label: "0.5–1 mg/kg q24h", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD GI pharmacology.", notes: "IV/CRI is separate protocol Extra-label veterinary use Research preload rule: 0.5–1 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "omeprazole-cat-1", generic: "Omeprazole", species: .cat,
            label: "0.5–1 mg/kg PO q12–24h", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q12-24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD GI pharmacology.", notes: "IV/CRI is separate protocol Extra-label veterinary use Research preload rule: 0.5–1 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "famotidine-dog-1", generic: "Famotidine", species: .dog,
            label: "0.5–1 mg/kg q24h", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q24h", route: "PO/IV", strengths: [40], concentration: 10.0,
            sourceReference: "MSD GI pharmacology; prolonged continuous use can develop tachyphylaxis.", notes: "Chronic H2 response can change Extra-label veterinary use Research preload rule: 0.5–1 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "famotidine-cat-1", generic: "Famotidine", species: .cat,
            label: "0.5–1 mg/kg PO q12–24h", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q12-24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD GI pharmacology; prolonged continuous use can develop tachyphylaxis.", notes: "Oral branch only. Verify the actual oral liquid concentration if used; injectable 10 mg/mL is not an oral default. Response may diminish with repeated H2-blocker use.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ondansetron-dog-1", generic: "Ondansetron", species: .dog,
            label: "Oral antiemetic regimen", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.2,
            frequency: "q12–24h", route: "PO", strengths: [8], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Route/indication and QT risk need rule Extra-label veterinary use Research preload rule: PO 0.1–0.2 mg/kg; IV approximately 0.1–0.5 mg/kg q8–12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ondansetron-dog-2", generic: "Ondansetron", species: .dog,
            label: "Intravenous antiemetic regimen", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.15,
            frequency: "q8–12h", route: "IV", strengths: [], concentration: 2.0,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Route/indication and QT risk need rule Extra-label veterinary use Research preload rule: PO 0.1–0.2 mg/kg; IV approximately 0.1–0.5 mg/kg q8–12h",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ondansetron-cat-1", generic: "Ondansetron", species: .cat,
            label: "Oral antiemetic regimen", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.2,
            frequency: "q12–24h", route: "PO", strengths: [8], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Route/indication and QT risk need rule Extra-label veterinary use Research preload rule: PO 0.1–0.2 mg/kg; IV approximately 0.1–0.5 mg/kg q8–12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ondansetron-cat-2", generic: "Ondansetron", species: .cat,
            label: "Intravenous antiemetic regimen", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.15,
            frequency: "q8–12h", route: "IV", strengths: [], concentration: 2.0,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Route/indication and QT risk need rule Extra-label veterinary use Research preload rule: PO 0.1–0.2 mg/kg; IV approximately 0.1–0.5 mg/kg q8–12h",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diphenhydramine-dog-1", generic: "Diphenhydramine", species: .dog,
            label: "2–4 mg/kg", doseBasis: .mgKg, minDose: 2.0, maxDose: 4.0,
            frequency: "q8-12h", route: "PO/IM/SC", strengths: [50,12.5], concentration: 50.0,
            sourceReference: "MSD antihistamine table.", notes: "Sedation; avoid combination cold products Extra-label; combination OTC products must be excluded Research preload rule: 2–4 mg/kg PO/IM/SC q8–12h PRN",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "diphenhydramine-cat-1", generic: "Diphenhydramine", species: .cat,
            label: "2–4 mg/kg", doseBasis: .mgKg, minDose: 2.0, maxDose: 4.0,
            frequency: "q8-12h", route: "PO/IM/SC", strengths: [50,12.5], concentration: 50.0,
            sourceReference: "MSD antihistamine table.", notes: "Sedation; avoid combination cold products Extra-label; combination OTC products must be excluded Research preload rule: 2–4 mg/kg PO/IM/SC q8–12h PRN",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cetirizine-dog-1", generic: "Cetirizine", species: .dog,
            label: "1 mg/kg or 10–20 mg/dog — 1 mg/kg branch", doseBasis: .mgKg, minDose: 1.0, maxDose: 1.0,
            frequency: "q12-24h", route: "PO", strengths: [10], concentration: 1.0,
            sourceReference: "MSD: dogs 1 mg/kg or 10–20 mg, cats 1 mg/kg or 5 mg.", notes: "Avoid pseudoephedrine combinations Extra-label Research preload rule: 1 mg/kg PO q12–24h; fixed-dose alternatives by species",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cetirizine-dog-2", generic: "Cetirizine", species: .dog,
            label: "1 mg/kg or 10–20 mg/dog — 10-20 mg/dog branch", doseBasis: .fixedMg, minDose: 10.0, maxDose: 20.0,
            frequency: "q12-24h", route: "PO", strengths: [10], concentration: 1.0,
            sourceReference: "MSD: dogs 1 mg/kg or 10–20 mg, cats 1 mg/kg or 5 mg.", notes: "Avoid pseudoephedrine combinations Extra-label Research preload rule: 1 mg/kg PO q12–24h; fixed-dose alternatives by species",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cetirizine-cat-1", generic: "Cetirizine", species: .cat,
            label: "1 mg/kg or 5 mg/cat — 1 mg/kg branch", doseBasis: .mgKg, minDose: 1.0, maxDose: 1.0,
            frequency: "q12-24h", route: "PO", strengths: [10], concentration: 1.0,
            sourceReference: "MSD: dogs 1 mg/kg or 10–20 mg, cats 1 mg/kg or 5 mg.", notes: "Avoid pseudoephedrine combinations Extra-label Research preload rule: 1 mg/kg PO q12–24h; fixed-dose alternatives by species",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cetirizine-cat-2", generic: "Cetirizine", species: .cat,
            label: "1 mg/kg or 5 mg/cat — 5 mg/cat branch", doseBasis: .fixedMg, minDose: 5.0, maxDose: 5.0,
            frequency: "q12-24h", route: "PO", strengths: [10], concentration: 1.0,
            sourceReference: "MSD: dogs 1 mg/kg or 10–20 mg, cats 1 mg/kg or 5 mg.", notes: "Avoid pseudoephedrine combinations Extra-label Research preload rule: 1 mg/kg PO q12–24h; fixed-dose alternatives by species",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-dog-1", generic: "Furosemide", species: .dog,
            label: "Acute pulmonary edema", doseBasis: .mgKg, minDose: 2, maxDose: 4,
            frequency: "q1-6h initially to effect", route: "IV/IM", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal values, hydration, electrolytes Product/route verification; renal/electrolyte monitoring Research preload rule: Acute, chronic and CRI branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-dog-2", generic: "Furosemide", species: .dog,
            label: "Chronic CHF", doseBasis: .mgKg, minDose: 1, maxDose: 6,
            frequency: "q8-12h", route: "PO", strengths: [80], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal values, hydration, electrolytes. MSD cardiac table lists a maximum total chronic oral dose of 12 mg/kg/day in dogs; verify the selected interval does not exceed that daily ceiling.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-dog-3", generic: "Furosemide", species: .dog,
            label: "CRI", doseBasis: .mgKgHr, minDose: 0.25, maxDose: 1,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal values, hydration, electrolytes Product/route verification; renal/electrolyte monitoring Research preload rule: Acute, chronic and CRI branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-cat-1", generic: "Furosemide", species: .cat,
            label: "Acute pulmonary edema", doseBasis: .mgKg, minDose: 0.5, maxDose: 2,
            frequency: "q1-8h to effect", route: "IV/IM", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal values, hydration, electrolytes Product/route verification; renal/electrolyte monitoring Research preload rule: Acute, chronic and CRI branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-cat-2", generic: "Furosemide", species: .cat,
            label: "Chronic CHF", doseBasis: .mgKg, minDose: 1, maxDose: 2,
            frequency: "q12-24h", route: "PO", strengths: [80], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal values, hydration, electrolytes. MSD cardiac table lists a maximum total chronic oral dose of 6 mg/kg/day in cats; verify the selected interval does not exceed that daily ceiling.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "furosemide-cat-3", generic: "Furosemide", species: .cat,
            label: "Acute pulmonary edema CRI", doseBasis: .mgKgHr, minDose: 0.25, maxDose: 0.6,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Acute monitored CRI branch. Monitor respiratory status, hydration, renal values, and electrolytes; taper as clinical signs resolve.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "spironolactone-dog-1", generic: "Spironolactone", species: .dog,
            label: "Adjunctive CHF: twice-daily regimen", doseBasis: .mgKg, minDose: 1.0, maxDose: 2.0,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/pharmacology/systemic-pharmacotherapeutics-of-the-cardiovascular-system/diuretics-for-use-in-animals", notes: "K/renal monitoring Extra-label branches; electrolyte monitoring Research preload rule: 1–2 mg/kg q12–24h; dog diuretic range up to 4 mg/kg/day",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "spironolactone-dog-2", generic: "Spironolactone", species: .dog,
            label: "Adjunctive CHF: once-daily regimen", doseBasis: .mgKg, minDose: 2.0, maxDose: 2.0,
            frequency: "q24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/pharmacology/systemic-pharmacotherapeutics-of-the-cardiovascular-system/diuretics-for-use-in-animals", notes: "K/renal monitoring Extra-label branches; electrolyte monitoring Research preload rule: 1–2 mg/kg q12–24h; dog diuretic range up to 4 mg/kg/day",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "spironolactone-cat-1", generic: "Spironolactone", species: .cat,
            label: "1–2 mg/kg q12–24h", doseBasis: .mgKg, minDose: 1.0, maxDose: 2.0,
            frequency: "q12-24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/pharmacology/systemic-pharmacotherapeutics-of-the-cardiovascular-system/diuretics-for-use-in-animals", notes: "K/renal monitoring Extra-label branches; electrolyte monitoring Research preload rule: 1–2 mg/kg q12–24h; dog diuretic range up to 4 mg/kg/day",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "benazepril-dog-1", generic: "Benazepril", species: .dog,
            label: "~0.25–0.5 mg/kg", doseBasis: .mgKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q12-24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD cardiovascular guidance.", notes: "Creatinine/K/BP Extra-label branches Research preload rule: 0.25–0.5 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "benazepril-cat-1", generic: "Benazepril", species: .cat,
            label: "Twice-daily cardiac regimen", doseBasis: .mgKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q12h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Creatinine/K/BP Extra-label branches Research preload rule: 0.25–0.5 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "enalapril-dog-1", generic: "Enalapril", species: .dog,
            label: "~0.25–0.5 mg/kg", doseBasis: .mgKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q12-24h", route: "PO", strengths: [20], concentration: nil,
            sourceReference: "MSD cardiovascular guidance.", notes: "Renal/K/BP Product/indication labeling varies Research preload rule: 0.25–0.5 mg/kg PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "methimazole-transdermal-cat-1", generic: "Methimazole transdermal", species: .cat,
            label: "1.25–2.5 mg/cat transdermal q12h", doseBasis: .fixedMg, minDose: 1.25, maxDose: 2.5,
            frequency: "q12h", route: "Transdermal", strengths: [], concentration: nil,
            sourceReference: "Veterinary hyperthyroidism literature; compounded/extra-label formulation, so pharmacy concentration must be confirmed.", notes: "T4/CBC/chemistry; bioavailability varies Compounded/extra-label; concentration mandatory Research preload rule: 1.25–2.5 mg/cat transdermal q12h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "insulin-glargine-dog-1", generic: "Insulin glargine", species: .dog,
            label: "Glargine U-100 starting protocol 0.25–0.5 U/kg", doseBasis: .unitsKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q12h", route: "SC", strengths: [], concentration: 100,
            sourceReference: "https://www.aaha.org/resources/2026-aaha-diabetes-management-guidelines-for-dogs/section-4-insulin-treatment/", notes: "AAHA branch: enter veterinarian-estimated ideal weight. Displayed units are unrounded reference arithmetic; review whole-unit rounding and glucose monitoring. U-300 requires a separate regimen.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "insulin-glargine-cat-1", generic: "Insulin glargine", species: .cat,
            label: "Glargine U-100 common starting dose 1 U/cat", doseBasis: .fixedUnits, minDose: 1, maxDose: 1,
            frequency: "q12h", route: "SC", strengths: [], concentration: 100,
            sourceReference: "https://www.aaha.org/resources/2026-aaha-diabetes-management-guidelines-for-cats/section-7-insulin-treatment-and-monitoring/", notes: "Fixed-dose starting reference for glargine U-100 only. Match the delivery device; titrate from glucose and clinical response. Do not substitute U-300.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "insulin-pzi-dog-1", generic: "Insulin PZI", species: .dog,
            label: "Initial labeled/starting branch", doseBasis: .unitsKg, minDose: 0.5, maxDose: 1,
            frequency: "q24h", route: "SC", strengths: [], concentration: 40.0,
            sourceReference: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8dbc0e47-8df9-4484-903b-70fdd26f7998", notes: "FDA-label starting branch. Start insulin-naive dogs at the lower end; transitions require close monitoring. Use a U-40 syringe. Review hypoglycemia risk before every dose.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "insulin-pzi-dog-2", generic: "Insulin PZI", species: .dog,
            label: "AAHA canine q12h starting protocol 0.25–0.5 U/kg", doseBasis: .unitsKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q12h", route: "SC", strengths: [], concentration: 40,
            sourceReference: "https://www.aaha.org/resources/2026-aaha-diabetes-management-guidelines-for-dogs/section-4-insulin-treatment/", notes: "AAHA branch using estimated ideal weight; review whole-unit rounding. This differs from labeled once-daily initiation. Prolonged action requires close glucose monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "insulin-pzi-cat-1", generic: "Insulin PZI", species: .cat,
            label: "PROZINC FDA-label initial 0.2–0.7 U/kg", doseBasis: .unitsKg, minDose: 0.2, maxDose: 0.7,
            frequency: "q12h", route: "SC", strengths: [], concentration: 40,
            sourceReference: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8dbc0e47-8df9-4484-903b-70fdd26f7998", notes: "FDA-label initial-dose branch; administer SC with a U-40 syringe. Review food intake, hypoglycemia and glucose monitoring. This is not a ketoacidosis protocol.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "insulin-pzi-cat-2", generic: "Insulin PZI", species: .cat,
            label: "AAHA common feline starting dose 1 U/cat", doseBasis: .fixedUnits, minDose: 1, maxDose: 1,
            frequency: "q12h", route: "SC", strengths: [], concentration: 40,
            sourceReference: "https://www.aaha.org/resources/2026-aaha-diabetes-management-guidelines-for-cats/section-7-insulin-treatment-and-monitoring/", notes: "Common fixed starting reference for PZI U-40. Match the delivery device and titrate from glucose and clinical response.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "phenobarbital-dog-1", generic: "Phenobarbital", species: .dog,
            label: "2–5 mg/kg", doseBasis: .mgKg, minDose: 2.0, maxDose: 5.0,
            frequency: "q12h", route: "PO", strengths: [97.2], concentration: nil,
            sourceReference: "MSD epilepsy guidance; serum monitoring required.", notes: "Serum concentrations/liver monitoring **CIV**; controlled-drug records Research preload rule: 2–5 mg/kg PO q12h",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "phenobarbital-cat-1", generic: "Phenobarbital", species: .cat,
            label: "2–5 mg/kg", doseBasis: .mgKg, minDose: 2.0, maxDose: 5.0,
            frequency: "q12h", route: "PO", strengths: [97.2], concentration: nil,
            sourceReference: "MSD epilepsy guidance; serum monitoring required.", notes: "Serum concentrations/liver monitoring **CIV**; controlled-drug records Research preload rule: 2–5 mg/kg PO q12h",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "tramadol-dog-1", generic: "Tramadol", species: .dog,
            label: "Dog 4–10 mg/kg q6–8h", doseBasis: .mgKg, minDose: 4.0, maxDose: 10.0,
            frequency: "q6-8h", route: "PO", strengths: [50], concentration: nil,
            sourceReference: "MSD analgesic guidance; analgesic efficacy in dogs is variable.", notes: "Serotonergic interactions/seizure threshold; species metabolism differs **CIV**. Canine analgesic response is variable; use the dose range only when tramadol is the selected veterinarian-directed plan.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "tramadol-cat-1", generic: "Tramadol", species: .cat,
            label: "1–2 mg/kg q12h supported", doseBasis: .mgKg, minDose: 1.0, maxDose: 2.0,
            frequency: "q12h", route: "PO", strengths: [50], concentration: nil,
            sourceReference: "MSD analgesic guidance; analgesic efficacy in dogs is variable.", notes: "Serotonergic interactions/seizure threshold; species metabolism differs **CIV**. Canine analgesic response is variable; use the dose range only when tramadol is the selected veterinarian-directed plan.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-dog-1", generic: "Buprenorphine", species: .dog,
            label: "Injectable 0.005–0.03 mg/kg", doseBasis: .mgKg, minDose: 0.005, maxDose: 0.03,
            frequency: "q4–6h", route: "IV/IM", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Dogs.", notes: "DEA Schedule III. Conventional 0.3 mg/mL injectable branch; do not interchange with concentrated long-acting feline products.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-dog-2", generic: "Buprenorphine", species: .dog,
            label: "CRI loading 0.005–0.01 mg/kg", doseBasis: .mgKg, minDose: 0.005, maxDose: 0.01,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Dogs.", notes: "DEA Schedule III. CRI loading selector; pair only with the matching monitored IV CRI branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-dog-3", generic: "Buprenorphine", species: .dog,
            label: "CRI 0.002–0.004 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.002, maxDose: 0.004,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Dogs.", notes: "DEA Schedule III. Monitored CRI branch; verify final diluted concentration and pump settings.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-cat-1", generic: "Buprenorphine", species: .cat,
            label: "Injectable/transmucosal 0.01–0.03 mg/kg", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.03,
            frequency: "q4–8h", route: "IV/IM/transmucosal", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule III. Conventional 0.3 mg/mL formulation branch. Do not interchange with long-acting 1.8 mg/mL feline injection.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-cat-2", generic: "Buprenorphine", species: .cat,
            label: "CRI loading 0.005–0.01 mg/kg", doseBasis: .mgKg, minDose: 0.005, maxDose: 0.01,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule III. CRI loading selector; pair only with the matching monitored IV CRI branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-cat-3", generic: "Buprenorphine", species: .cat,
            label: "CRI 0.002–0.004 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.002, maxDose: 0.004,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 0.3,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule III. Monitored CRI branch; verify final diluted concentration and pump settings.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "buprenorphine-cat-4", generic: "Buprenorphine", species: .cat,
            label: "Long-acting feline injection 0.24 mg/kg", doseBasis: .mgKg, minDose: 0.24, maxDose: 0.24,
            frequency: "q24h for up to 3 days", route: "SC", strengths: [], concentration: 1.8,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule III. Long-acting 1.8 mg/mL feline product branch; never substitute the 0.3 mg/mL conventional formulation without recalculation/product verification.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-dog-1", generic: "Butorphanol", species: .dog,
            label: "0.2–0.4 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "q1-2h", route: "IV/IM/SC", strengths: [], concentration: 10.0,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "Short duration; opioid monitoring **CIV** Research preload rule: 0.2–0.4 mg/kg IV/IM/SC; CRI branch",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-dog-2", generic: "Butorphanol", species: .dog,
            label: "CRI loading 0.2 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.2,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 10,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Dogs.", notes: "DEA Schedule IV. CRI loading selector; dogs with ABCB1-1Δ may require dose reduction.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-dog-3", generic: "Butorphanol", species: .dog,
            label: "CRI 0.1–0.24 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.1, maxDose: 0.24,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 10,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "DEA Schedule IV. Monitored CRI branch; verify final dilution and pump settings. Dogs with ABCB1-1Δ may require dose reduction.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-cat-1", generic: "Butorphanol", species: .cat,
            label: "0.2–0.4 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "q1-2h", route: "IV/IM/SC", strengths: [], concentration: 10.0,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "Short duration; opioid monitoring **CIV** Research preload rule: 0.2–0.4 mg/kg IV/IM/SC; CRI branch",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-cat-2", generic: "Butorphanol", species: .cat,
            label: "CRI loading 0.2–0.4 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 10,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule IV. CRI loading selector; monitored opioid administration required.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "butorphanol-cat-3", generic: "Butorphanol", species: .cat,
            label: "CRI 0.1–0.24 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.1, maxDose: 0.24,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 10,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "DEA Schedule IV. Monitored CRI branch; verify final dilution and pump settings. Dogs with ABCB1-1Δ may require dose reduction.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-dog-1", generic: "Hydromorphone", species: .dog,
            label: "Intermittent 0.05–0.2 mg/kg", doseBasis: .mgKg, minDose: 0.05, maxDose: 0.2,
            frequency: "q2–4h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual analgesic guidance.", notes: "DEA Schedule II. Monitor respiratory/CNS effects and emesis/panting; enter the exact product mg/mL if converting to volume.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-dog-2", generic: "Hydromorphone", species: .dog,
            label: "CRI loading 0.025–0.05 mg/kg", doseBasis: .mgKg, minDose: 0.025, maxDose: 0.05,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual selected analgesics for dogs.", notes: "DEA Schedule II. Loading selector for the matching monitored CRI.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-dog-3", generic: "Hydromorphone", species: .dog,
            label: "CRI 0.03 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.03, maxDose: 0.03,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual selected analgesics for dogs.", notes: "DEA Schedule II. Monitored CRI; enter final prepared concentration in mg/mL to calculate mL/hr.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-cat-1", generic: "Hydromorphone", species: .cat,
            label: "Intermittent 0.05–0.1 mg/kg", doseBasis: .mgKg, minDose: 0.05, maxDose: 0.1,
            frequency: "q2–6h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual selected analgesics for cats.", notes: "DEA Schedule II. Cats commonly vomit at analgesic doses; monitor respiratory/CNS effects. Enter exact product mg/mL for volume conversion.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-cat-2", generic: "Hydromorphone", species: .cat,
            label: "CRI loading 0.025 mg/kg", doseBasis: .mgKg, minDose: 0.025, maxDose: 0.025,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual selected analgesics for cats.", notes: "DEA Schedule II. Loading selector for the matching monitored CRI.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "hydromorphone-cat-3", generic: "Hydromorphone", species: .cat,
            label: "CRI 0.01–0.05 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.01, maxDose: 0.05,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual selected analgesics for cats.", notes: "DEA Schedule II. Monitored CRI; enter final prepared concentration in mg/mL to calculate mL/hr.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fentanyl-dog-1", generic: "Fentanyl", species: .dog,
            label: "Analgesic IV loading dose 0.01 mg/kg", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.01,
            frequency: "once", route: "IV", strengths: [], concentration: 0.05,
            sourceReference: "MSD Veterinary Manual selected analgesics for dogs.", notes: "DEA Schedule II; respiratory depression and monitored administration. This branch is the IV analgesic loading dose for the selected CRI protocol.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fentanyl-dog-2", generic: "Fentanyl", species: .dog,
            label: "Analgesic CRI 0.01 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.01, maxDose: 0.01,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 0.05,
            sourceReference: "MSD Veterinary Manual selected analgesics for dogs.", notes: "DEA Schedule II; monitored CRI. Default injectable concentration is represented as 0.05 mg/mL (50 mcg/mL); verify the exact product before use.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fentanyl-cat-1", generic: "Fentanyl", species: .cat,
            label: "CRI loading dose", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.01,
            frequency: "once", route: "IV", strengths: [], concentration: 0.05,
            sourceReference: "MSD Veterinary Manual selected analgesics for cats.", notes: "Respiratory depression; delayed patch onset **CII**; human-product extra-label; formulation-specific Research preload rule: IV loading/CRI and transdermal branches",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fentanyl-cat-2", generic: "Fentanyl", species: .cat,
            label: "Analgesic CRI", doseBasis: .mgKgHr, minDose: 0.01, maxDose: 0.01,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 0.05,
            sourceReference: "MSD Veterinary Manual selected analgesics for cats.", notes: "Respiratory depression; delayed patch onset **CII**; human-product extra-label; formulation-specific Research preload rule: IV loading/CRI and transdermal branches",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-dog-1", generic: "Ketamine", species: .dog,
            label: "Perioperative analgesic adjunct 3–5 mg/kg IV", doseBasis: .mgKg, minDose: 3, maxDose: 5,
            frequency: "to effect", route: "IV", strengths: [], concentration: 100.0,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/selected-analgesics-for-use-in-dogs", notes: "Keep induction and analgesic CRI separate **CIII**; dose-to-effect/protocol dependent Research preload rule: Anesthetic/co-induction and low-dose analgesic CRI branches",
            confidence: "High for workflow", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-dog-3", generic: "Ketamine", species: .dog,
            label: "Analgesic CRI loading 0.5–1 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 1,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 100,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Dogs.", notes: "DEA Schedule III. Low-dose analgesic CRI loading branch; keep separate from the 3–5 mg/kg perioperative adjunct branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-dog-2", generic: "Ketamine", species: .dog,
            label: "Analgesic CRI", doseBasis: .mgKgHr, minDose: 0.12, maxDose: 0.6,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 100.0,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "Keep induction and analgesic CRI separate **CIII**; dose-to-effect/protocol dependent Research preload rule: Anesthetic/co-induction and low-dose analgesic CRI branches",
            confidence: "High for workflow", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-cat-1", generic: "Ketamine", species: .cat,
            label: "Perioperative analgesic adjunct 3–5 mg/kg IV", doseBasis: .mgKg, minDose: 3, maxDose: 5,
            frequency: "to effect", route: "IV", strengths: [], concentration: 100.0,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/selected-analgesics-for-use-in-cats", notes: "Keep induction and analgesic CRI separate **CIII**; dose-to-effect/protocol dependent Research preload rule: Anesthetic/co-induction and low-dose analgesic CRI branches",
            confidence: "High for workflow", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-cat-3", generic: "Ketamine", species: .cat,
            label: "Analgesic CRI loading 0.5–1 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 1,
            frequency: "once before CRI", route: "IV", strengths: [], concentration: 100,
            sourceReference: "MSD Veterinary Manual Selected Analgesics for Use in Cats.", notes: "DEA Schedule III. Low-dose analgesic CRI loading branch; keep separate from the 3–5 mg/kg perioperative adjunct branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ketamine-cat-2", generic: "Ketamine", species: .cat,
            label: "Analgesic CRI", doseBasis: .mgKgHr, minDose: 0.1, maxDose: 0.6,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 100.0,
            sourceReference: "MSD Veterinary Manual selected analgesics guidance.", notes: "Keep induction and analgesic CRI separate **CIII**; dose-to-effect/protocol dependent Research preload rule: Anesthetic/co-induction and low-dose analgesic CRI branches",
            confidence: "High for workflow", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-dog-1", generic: "Midazolam", species: .dog,
            label: "Anesthesia/sedation adjunct 0.1–0.3 mg/kg", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.3,
            frequency: "per monitored anesthetic protocol", route: "IV/IM", strengths: [], concentration: 5,
            sourceReference: "Veterinary anesthesia literature plus MSD emergency seizure guidance for benzodiazepine safety context.", notes: "DEA Schedule IV. Dose-to-effect combinations can increase respiratory/CNS depression; this selector is not the seizure-rescue branch.",
            confidence: "Moderate-high", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-dog-2", generic: "Midazolam", species: .dog,
            label: "Emergency seizure IV 0.1–0.25 mg/kg", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.25,
            frequency: "rescue dose; repeat/CRI only per emergency protocol", route: "IV", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Emergency seizure-rescue selector; monitored setting required.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-dog-3", generic: "Midazolam", species: .dog,
            label: "Emergency seizure intranasal 0.2 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.2,
            frequency: "rescue dose", route: "intranasal", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Intranasal seizure-rescue branch; verify product concentration and delivery technique.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-dog-4", generic: "Midazolam", species: .dog,
            label: "Emergency seizure CRI 0.25–0.4 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.25, maxDose: 0.4,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. For prolonged/repeated seizures in a monitored setting; verify final concentration and pump settings.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-cat-1", generic: "Midazolam", species: .cat,
            label: "Anesthesia/sedation adjunct 0.1–0.3 mg/kg", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.3,
            frequency: "per monitored anesthetic protocol", route: "IV/IM", strengths: [], concentration: 5,
            sourceReference: "Veterinary anesthesia literature plus MSD emergency seizure guidance for benzodiazepine safety context.", notes: "DEA Schedule IV. Dose-to-effect combinations can increase respiratory/CNS depression; this selector is not the seizure-rescue branch.",
            confidence: "Moderate-high", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-cat-2", generic: "Midazolam", species: .cat,
            label: "Emergency seizure IV 0.1–0.25 mg/kg", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.25,
            frequency: "rescue dose; repeat/CRI only per emergency protocol", route: "IV", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Emergency seizure-rescue selector; monitored setting required.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-cat-3", generic: "Midazolam", species: .cat,
            label: "Emergency seizure intranasal 0.2 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.2,
            frequency: "rescue dose", route: "intranasal", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Intranasal seizure-rescue branch; verify product concentration and delivery technique.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "midazolam-cat-4", generic: "Midazolam", species: .cat,
            label: "Emergency seizure CRI 0.25–0.4 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.25, maxDose: 0.4,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. For prolonged/repeated seizures in a monitored setting; verify final concentration and pump settings.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diazepam-dog-1", generic: "Diazepam", species: .dog,
            label: "Emergency seizure IV 0.5 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 0.5,
            frequency: "rescue dose", route: "IV", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Monitor CNS/respiratory status. Chronic oral diazepam is avoided in cats because of rare potentially fatal hepatic injury.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diazepam-dog-2", generic: "Diazepam", species: .dog,
            label: "Emergency seizure rectal 1–2 mg/kg", doseBasis: .mgKg, minDose: 1, maxDose: 2,
            frequency: "rescue dose", route: "per rectum", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Rectal rescue selector; verify concentration and administration technique.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diazepam-dog-3", generic: "Diazepam", species: .dog,
            label: "Emergency seizure CRI 0.2–2 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.2, maxDose: 2,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Dedicated catheter and light protection are required per emergency guidance; monitored setting only.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diazepam-cat-1", generic: "Diazepam", species: .cat,
            label: "Emergency seizure IV 0.5 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 0.5,
            frequency: "rescue dose", route: "IV", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Monitor CNS/respiratory status. Chronic oral diazepam is avoided in cats because of rare potentially fatal hepatic injury.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "diazepam-cat-3", generic: "Diazepam", species: .cat,
            label: "Emergency seizure CRI 0.2–2 mg/kg/hr", doseBasis: .mgKgHr, minDose: 0.2, maxDose: 2,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 5,
            sourceReference: "MSD Veterinary Manual emergency seizure guidance.", notes: "DEA Schedule IV. Dedicated catheter and light protection are required per emergency guidance; monitored setting only.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "alprazolam-dog-1", generic: "Alprazolam", species: .dog,
            label: "Dog 0.02–0.1 mg/kg PRN", doseBasis: .mgKg, minDose: 0.02, maxDose: 0.1,
            frequency: "q6h as needed", route: "PO", strengths: [2], concentration: nil,
            sourceReference: "MSD Veterinary Manual behavior guidance.", notes: "Sedation/disinhibition; withdrawal **CIV**; extra-label Research preload rule: Dog 0.02–0.1 mg/kg PRN; cat 0.125–0.25 mg/cat PRN",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "alprazolam-cat-1", generic: "Alprazolam", species: .cat,
            label: "cat 0.125–0.25 mg/cat PRN", doseBasis: .fixedMg, minDose: 0.125, maxDose: 0.25,
            frequency: "q8–24h as needed", route: "PO", strengths: [2], concentration: nil,
            sourceReference: "MSD Veterinary Manual behavior guidance.", notes: "Sedation/disinhibition; withdrawal **CIV**; extra-label Research preload rule: Dog 0.02–0.1 mg/kg PRN; cat 0.125–0.25 mg/cat PRN",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexmedetomidine-dog-1", generic: "Dexmedetomidine", species: .dog,
            label: "Manufacturer canine IV sedation/analgesia 375 mcg/m²", doseBasis: .mgM2, minDose: 0.375, maxDose: 0.375,
            frequency: "once", route: "IV", strengths: [], concentration: 0.5,
            sourceReference: "Dexmedetomidine veterinary prescribing information / DailyMed.", notes: "Canine label dose is BSA-based, not one universal mcg/kg value. 375 mcg/m² = 0.375 mg/m². Verify cardiovascular/respiratory contraindications and availability of reversal/monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexmedetomidine-dog-2", generic: "Dexmedetomidine", species: .dog,
            label: "Manufacturer canine IM sedation/analgesia 500 mcg/m²", doseBasis: .mgM2, minDose: 0.5, maxDose: 0.5,
            frequency: "once", route: "IM", strengths: [], concentration: 0.5,
            sourceReference: "Dexmedetomidine veterinary prescribing information / DailyMed.", notes: "Canine label dose is BSA-based. 500 mcg/m² = 0.5 mg/m². Verify cardiovascular/respiratory contraindications and availability of reversal/monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexmedetomidine-cat-1", generic: "Dexmedetomidine", species: .cat,
            label: "Manufacturer feline IM 40 mcg/kg", doseBasis: .mcgKg, minDose: 40, maxDose: 40,
            frequency: "once", route: "IM", strengths: [], concentration: 0.5,
            sourceReference: "Dexmedetomidine veterinary prescribing information / DailyMed.", notes: "0.5 mg/mL injectable product. VetPilot converts the 40 mcg/kg dose to mg before volume conversion. Verify cardiovascular/respiratory contraindications and monitored setting.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "propofol-dog-1", generic: "Propofol", species: .dog,
            label: "IV induction to effect", doseBasis: .mgKg, minDose: 2.6, maxDose: 5.5,
            frequency: "titrate to effect", route: "IV", strengths: [], concentration: 10.0,
            sourceReference: "Veterinary anesthesia sources; fixed dose must not override effect titration.", notes: "Apnea/hypotension; monitored setting **Dose to effect**; cannot safely auto-select full induction dose Research preload rule: IV induction titrated to effect, approximately dog 2.6–5.5 mg/kg and cat 4–8 mg/kg",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "propofol-cat-1", generic: "Propofol", species: .cat,
            label: "IV induction to effect", doseBasis: .mgKg, minDose: 4, maxDose: 8,
            frequency: "titrate to effect", route: "IV", strengths: [], concentration: 10.0,
            sourceReference: "Veterinary anesthesia sources; fixed dose must not override effect titration.", notes: "Apnea/hypotension; monitored setting **Dose to effect**; cannot safely auto-select full induction dose Research preload rule: IV induction titrated to effect, approximately dog 2.6–5.5 mg/kg and cat 4–8 mg/kg",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "alfaxalone-dog-1", generic: "Alfaxalone", species: .dog,
            label: "IV induction to effect", doseBasis: .mgKg, minDose: 1.5, maxDose: 3,
            frequency: "titrate to effect", route: "IV", strengths: [], concentration: 10.0,
            sourceReference: "Veterinary anesthesia literature; 10 mg/mL formulation.", notes: "Premedication drastically changes requirement **Dose to effect** Research preload rule: Dog ~1.5–3 mg/kg; cat ~2–5 mg/kg IV to effect",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "alfaxalone-cat-1", generic: "Alfaxalone", species: .cat,
            label: "IV induction to effect", doseBasis: .mgKg, minDose: 2, maxDose: 5,
            frequency: "titrate to effect", route: "IV", strengths: [], concentration: 10.0,
            sourceReference: "Veterinary anesthesia literature; 10 mg/mL formulation.", notes: "Premedication drastically changes requirement **Dose to effect** Research preload rule: Dog ~1.5–3 mg/kg; cat ~2–5 mg/kg IV to effect",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "amoxicillin-dog-1", generic: "Amoxicillin", species: .dog,
            label: "11–30 mg/kg", doseBasis: .mgKg, minDose: 11, maxDose: 30,
            frequency: "q8–24h", route: "PO/SC/IV", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual penicillin dosage table.", notes: "Antimicrobial branch; indication, site, culture/susceptibility, route, renal function, and stewardship can alter the selected regimen.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "amoxicillin-cat-1", generic: "Amoxicillin", species: .cat,
            label: "11–30 mg/kg", doseBasis: .mgKg, minDose: 11, maxDose: 30,
            frequency: "q8–24h", route: "PO/SC/IV", strengths: [250, 500], concentration: nil,
            sourceReference: "MSD Veterinary Manual penicillin dosage table.", notes: "Antimicrobial branch; indication, site, culture/susceptibility, route, renal function, and stewardship can alter the selected regimen.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-dog-1", generic: "Ampicillin", species: .dog,
            label: "Ampicillin sodium injection", doseBasis: .mgKg, minDose: 10, maxDose: 40,
            frequency: "q6-12h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/dosages-of-penicillins", notes: "Sodium formulation only. Verify reconstitution and route. Ampicillin trihydrate suspension is a different product and must not be given IV.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-cat-1", generic: "Ampicillin", species: .cat,
            label: "Ampicillin sodium injection", doseBasis: .mgKg, minDose: 6.6, maxDose: 20,
            frequency: "q8-12h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/dosages-of-penicillins", notes: "Sodium formulation only. Verify reconstitution and route. Ampicillin trihydrate suspension is a different product and must not be given IV.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-sulbactam-dog-1", generic: "Ampicillin + sulbactam", species: .dog,
            label: "10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h — 10-30 mg/kg branch", doseBasis: .mgKg, minDose: 10.0, maxDose: 30.0,
            frequency: "q6-8h", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD penicillin table.", notes: "Must define combined-product mg convention Extra-label Research preload rule: 10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-sulbactam-dog-2", generic: "Ampicillin + sulbactam", species: .dog,
            label: "10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h — 3.75-8.3 mg/kg/h branch", doseBasis: .mgKgHr, minDose: 3.75, maxDose: 8.3,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "MSD penicillin table.", notes: "Must define combined-product mg convention Extra-label Research preload rule: 10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-sulbactam-cat-1", generic: "Ampicillin + sulbactam", species: .cat,
            label: "10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h — 10-30 mg/kg branch", doseBasis: .mgKg, minDose: 10.0, maxDose: 30.0,
            frequency: "q6-8h", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD penicillin table.", notes: "Must define combined-product mg convention Extra-label Research preload rule: 10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ampicillin-sulbactam-cat-2", generic: "Ampicillin + sulbactam", species: .cat,
            label: "10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h — 3.75-8.3 mg/kg/h branch", doseBasis: .mgKgHr, minDose: 3.75, maxDose: 8.3,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "MSD penicillin table.", notes: "Must define combined-product mg convention Extra-label Research preload rule: 10–30 mg/kg IV q6–8h; CRI 3.75–8.3 mg/kg/h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cephalexin-dog-1", generic: "Cephalexin", species: .dog,
            label: "Skin/soft-tissue common template", doseBasis: .mgKg, minDose: 20, maxDose: 30,
            frequency: "q12h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD cephalosporin/antistaphylococcal tables.", notes: "Culture/site/renal function Veterinary/human products; label status depends product Research preload rule: Dog 15–45; cat 15–35 mg/kg q6–12h; skin template typically 20–30 q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cephalexin-cat-1", generic: "Cephalexin", species: .cat,
            label: "Common oral range", doseBasis: .mgKg, minDose: 15, maxDose: 35,
            frequency: "q6-12h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD cephalosporin/antistaphylococcal tables.", notes: "Culture/site/renal function Veterinary/human products; label status depends product Research preload rule: Dog 15–45; cat 15–35 mg/kg q6–12h; skin template typically 20–30 q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cefazolin-dog-1", generic: "Cefazolin", species: .dog,
            label: "Intermittent injectable antimicrobial regimen", doseBasis: .mgKg, minDose: 15.0, maxDose: 35.0,
            frequency: "q6-8h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/dosages-of-cephalosporins", notes: "Enter reconstituted mg/mL for volume calculation. Vial mass is not a tablet strength. Surgical prophylaxis and intraoperative redosing need their own procedure-specific plan.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cefazolin-cat-1", generic: "Cefazolin", species: .cat,
            label: "Intermittent injectable antimicrobial regimen", doseBasis: .mgKg, minDose: 15.0, maxDose: 35.0,
            frequency: "q6-8h", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/dosages-of-cephalosporins", notes: "Enter reconstituted mg/mL for volume calculation. Vial mass is not a tablet strength. Surgical prophylaxis and intraoperative redosing need their own procedure-specific plan.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clindamycin-dog-1", generic: "Clindamycin", species: .dog,
            label: "Common selected infection range", doseBasis: .mgKg, minDose: 10, maxDose: 20,
            frequency: "q12h", route: "PO", strengths: [300], concentration: nil,
            sourceReference: "MSD antimicrobial table.", notes: "Feline esophageal precautions Some veterinary-labeled uses; indication matters Research preload rule: Dog 10–20; cat 12.5–25 mg/kg q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clindamycin-cat-1", generic: "Clindamycin", species: .cat,
            label: "Common selected infection range", doseBasis: .mgKg, minDose: 12.5, maxDose: 25,
            frequency: "q12h", route: "PO", strengths: [300], concentration: nil,
            sourceReference: "MSD antimicrobial table.", notes: "Feline esophageal precautions Some veterinary-labeled uses; indication matters Research preload rule: Dog 10–20; cat 12.5–25 mg/kg q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "enrofloxacin-dog-1", generic: "Enrofloxacin", species: .dog,
            label: "Canine antimicrobial range", doseBasis: .mgKg, minDose: 5, maxDose: 20,
            frequency: "q24h", route: "PO/IV/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/dosages-of-quinolones", notes: "Feline retinal toxicity; stewardship Cat dose guard essential; fluoroquinolone stewardship Research preload rule: Dog 5–20 mg/kg q24h; **cat hard ceiling 5 mg/kg/day**",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "enrofloxacin-cat-1", generic: "Enrofloxacin", species: .cat,
            label: "Feline hard maximum", doseBasis: .mgKg, minDose: 5, maxDose: 5,
            frequency: "q24h", route: "PO/IV/SC", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/dosages-of-quinolones", notes: "Feline retinal toxicity; stewardship Cat dose guard essential; fluoroquinolone stewardship Research preload rule: Dog 5–20 mg/kg q24h; **cat hard ceiling 5 mg/kg/day**",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "marbofloxacin-dog-1", generic: "Marbofloxacin", species: .dog,
            label: "General fluoroquinolone table 2.75–5.5 mg/kg", doseBasis: .mgKg, minDose: 2.75, maxDose: 5.5,
            frequency: "q24h", route: "PO", strengths: [25, 50, 100, 200], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Use culture/susceptibility when feasible and reserve fluoroquinolones appropriately. A separate indication-specific dermatology regimen may differ.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "marbofloxacin-dog-2", generic: "Marbofloxacin", species: .dog,
            label: "Canine antistaphylococcal/skin branch 2 mg/kg", doseBasis: .mgKg, minDose: 2, maxDose: 2,
            frequency: "q24h", route: "PO", strengths: [25, 50, 100, 200], concentration: nil,
            sourceReference: "MSD Veterinary Manual antistaphylococcal antimicrobial table.", notes: "Indication-specific canine branch. Keep separate from the broader 2.75–5.5 mg/kg general fluoroquinolone table.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "marbofloxacin-cat-1", generic: "Marbofloxacin", species: .cat,
            label: "General fluoroquinolone table 2.75–5.5 mg/kg", doseBasis: .mgKg, minDose: 2.75, maxDose: 5.5,
            frequency: "q24h", route: "PO", strengths: [25, 50, 100, 200], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Use culture/susceptibility when feasible and reserve fluoroquinolones appropriately. Confirm feline product/indication and neurologic/retinal precautions.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "orbifloxacin-dog-1", generic: "Orbifloxacin", species: .dog,
            label: "Tablet 2.5–7.5 mg/kg", doseBasis: .mgKg, minDose: 2.5, maxDose: 7.5,
            frequency: "q24h", route: "PO tablet", strengths: [22.7, 68, 136], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Tablet branch. Use culture/susceptibility when feasible; formulation matters.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "orbifloxacin-dog-2", generic: "Orbifloxacin", species: .dog,
            label: "Oral suspension 7.5 mg/kg", doseBasis: .mgKg, minDose: 7.5, maxDose: 7.5,
            frequency: "q24h", route: "PO suspension", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Suspension-specific branch; enter the actual product mg/mL before volume conversion.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "orbifloxacin-cat-1", generic: "Orbifloxacin", species: .cat,
            label: "Tablet 2.5–7.5 mg/kg", doseBasis: .mgKg, minDose: 2.5, maxDose: 7.5,
            frequency: "q24h", route: "PO tablet", strengths: [22.7, 68, 136], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Tablet branch. Use culture/susceptibility when feasible and verify feline formulation/retinal precautions.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "orbifloxacin-cat-2", generic: "Orbifloxacin", species: .cat,
            label: "Oral suspension 7.5 mg/kg", doseBasis: .mgKg, minDose: 7.5, maxDose: 7.5,
            frequency: "q24h", route: "PO suspension", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual fluoroquinolone guidance.", notes: "Suspension-specific branch; enter the actual product mg/mL before volume conversion and verify feline retinal precautions.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "azithromycin-dog-1", generic: "Azithromycin", species: .dog,
            label: "10 mg/kg q24h", doseBasis: .mgKg, minDose: 10.0, maxDose: 10.0,
            frequency: "q24h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD antimicrobial table.", notes: "Selected susceptible-infection branch. Use culture/susceptibility and stewardship when feasible; duration is indication-specific.",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "azithromycin-cat-1", generic: "Azithromycin", species: .cat,
            label: "10 mg/kg q24h", doseBasis: .mgKg, minDose: 10.0, maxDose: 10.0,
            frequency: "q24h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD antimicrobial table.", notes: "Selected susceptible-infection branch. Use culture/susceptibility and stewardship when feasible; duration is indication-specific.",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "minocycline-dog-1", generic: "Minocycline", species: .dog,
            label: "5–10 mg/kg", doseBasis: .mgKg, minDose: 5, maxDose: 10,
            frequency: "q12h", route: "PO", strengths: [50, 100], concentration: nil,
            sourceReference: "MSD Veterinary Manual tetracycline guidance.", notes: "Indication and organism determine duration; apply antimicrobial stewardship and patient-specific hepatic/renal considerations.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "minocycline-cat-1", generic: "Minocycline", species: .cat,
            label: "5–10 mg/kg PO q12h", doseBasis: .mgKg, minDose: 5.0, maxDose: 10.0,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD tetracycline guidance.", notes: "Tetracycline precautions Extra-label Research preload rule: 5–10 mg/kg PO q12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "trimethoprim-sulfamethoxazole-dog-1", generic: "Trimethoprim-sulfamethoxazole", species: .dog,
            label: "Selected skin/antistaphylococcal protocol 15–30 mg/kg combined drug", doseBasis: .mgKg, minDose: 15.0, maxDose: 30.0,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD antimicrobial table.", notes: "Selected skin/antistaphylococcal protocol; dose is combined trimethoprim-sulfamethoxazole. Monitor for sulfonamide adverse effects; indication and duration matter.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "trimethoprim-sulfamethoxazole-dog-2", generic: "Trimethoprim-sulfamethoxazole", species: .dog,
            label: "General potentiated-sulfonamide table 30–45 mg/kg combined drug", doseBasis: .mgKg, minDose: 30, maxDose: 45,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Dosages of Potentiated Sulfonamides.", notes: "Extra-label dog branch; dosage is based on total combined drug. Monitor for sulfonamide adverse effects and use culture/susceptibility when feasible.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "trimethoprim-sulfamethoxazole-cat-1", generic: "Trimethoprim-sulfamethoxazole", species: .cat,
            label: "15 mg/kg combined drug", doseBasis: .mgKg, minDose: 15, maxDose: 15,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Dosages of Potentiated Sulfonamides.", notes: "Extra-label feline branch; dosage is based on total combined drug. Monitor for sulfonamide adverse effects.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "trimethoprim-sulfamethoxazole-cat-2", generic: "Trimethoprim-sulfamethoxazole", species: .cat,
            label: "Selected skin/antistaphylococcal protocol 15–30 mg/kg combined drug", doseBasis: .mgKg, minDose: 15.0, maxDose: 30.0,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual antistaphylococcal antimicrobial table.", notes: "Selected skin/antistaphylococcal protocol. Dose is combined trimethoprim-sulfamethoxazole; monitor for sulfonamide adverse effects and use culture/susceptibility when feasible.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "chloramphenicol-dog-1", generic: "Chloramphenicol", species: .dog,
            label: "Common antimicrobial range", doseBasis: .mgKg, minDose: 25, maxDose: 50,
            frequency: "q8h", route: "PO", strengths: [250], concentration: nil,
            sourceReference: "MSD species-specific table.", notes: "Human exposure hazard; marrow effects Human-exposure precautions; extra-label companion-animal use Research preload rule: Dog 25–50 mg/kg q8h; cat 12.5–20 mg/kg q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "chloramphenicol-cat-1", generic: "Chloramphenicol", species: .cat,
            label: "Common antimicrobial range", doseBasis: .mgKg, minDose: 12.5, maxDose: 20,
            frequency: "q12h", route: "PO", strengths: [250], concentration: nil,
            sourceReference: "MSD species-specific table.", notes: "Human exposure hazard; marrow effects Human-exposure precautions; extra-label companion-animal use Research preload rule: Dog 25–50 mg/kg q8h; cat 12.5–20 mg/kg q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sucralfate-dog-1", generic: "Sucralfate", species: .dog,
            label: "GI mucosal protectant", doseBasis: .fixedMg, minDose: 500, maxDose: 1000,
            frequency: "q6–8h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/antiulcerative-drugs", notes: "Separate from interacting oral drugs Extra-label veterinary use Research preload rule: Dog 0.5–1 g; cat 0.25–0.5 g q6–12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sucralfate-cat-1", generic: "Sucralfate", species: .cat,
            label: "GI mucosal protectant", doseBasis: .fixedMg, minDose: 250, maxDose: 500,
            frequency: "q8–12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/antiulcerative-drugs", notes: "Separate from interacting oral drugs Extra-label veterinary use Research preload rule: Dog 0.5–1 g; cat 0.25–0.5 g q6–12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "pantoprazole-dog-1", generic: "Pantoprazole", species: .dog,
            label: "0.7–1 mg/kg", doseBasis: .mgKg, minDose: 0.7, maxDose: 1.0,
            frequency: "q12-24h", route: "PO/IV", strengths: [40], concentration: nil,
            sourceReference: "MSD GI pharmacology.", notes: "Route/indication selector Extra-label Research preload rule: 0.7–1 mg/kg IV/PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "pantoprazole-cat-1", generic: "Pantoprazole", species: .cat,
            label: "0.7–1 mg/kg", doseBasis: .mgKg, minDose: 0.7, maxDose: 1.0,
            frequency: "q12-24h", route: "PO/IV", strengths: [40], concentration: nil,
            sourceReference: "MSD GI pharmacology.", notes: "Route/indication selector Extra-label Research preload rule: 0.7–1 mg/kg IV/PO q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metoclopramide-dog-1", generic: "Metoclopramide", species: .dog,
            label: "0.1–0.5 mg/kg q6–8h; CRI 0.01–0.02 mg/kg/h — 0.1-0.5 mg/kg branch", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.5,
            frequency: "q6–8h", route: "PO/SC/IM", strengths: [10], concentration: 5.0,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Intermittent antiemetic/prokinetic branch. Do not use with GI obstruction; route and indication should be selected before administration.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metoclopramide-dog-2", generic: "Metoclopramide", species: .dog,
            label: "0.1–0.5 mg/kg q6–8h; CRI 0.01–0.02 mg/kg/h — 0.01-0.02 mg/kg/h branch", doseBasis: .mgKgHr, minDose: 0.01, maxDose: 0.02,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Use the final diluted infusion concentration, not stock ampoule concentration, for pump-rate math. Requires a prescribed rate, obstruction exclusion, pump verification and neurologic monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "metoclopramide-cat-1", generic: "Metoclopramide", species: .cat,
            label: "0.1–0.5 mg/kg q6–8h; CRI 0.01–0.02 mg/kg/h — 0.1-0.5 mg/kg branch", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.5,
            frequency: "q6–8h", route: "PO/SC/IM", strengths: [10], concentration: 5.0,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Intermittent antiemetic/prokinetic branch. Do not use with GI obstruction; route and indication should be selected before administration.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "metoclopramide-cat-2", generic: "Metoclopramide", species: .cat,
            label: "0.1–0.5 mg/kg q6–8h; CRI 0.01–0.02 mg/kg/h — 0.01-0.02 mg/kg/h branch", doseBasis: .mgKgHr, minDose: 0.01, maxDose: 0.02,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: nil,
            sourceReference: "https://www.merckvetmanual.com/multimedia/table/antiemetic-drugs", notes: "Use the final diluted infusion concentration, not stock ampoule concentration, for pump-rate math. Requires a prescribed rate, obstruction exclusion, pump verification and neurologic monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "cisapride-dog-1", generic: "Cisapride", species: .dog,
            label: "GI motility", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.5,
            frequency: "q8-12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary prokinetic reference; compounded product.", notes: "QT/drug interactions Compounded; concentration cannot be assumed Research preload rule: Dog 0.1–0.5 mg/kg; cat 2.5–5 mg/cat q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cisapride-cat-1", generic: "Cisapride", species: .cat,
            label: "Feline megacolon/prokinetic", doseBasis: .mgKg, minDose: 0.5, maxDose: 1,
            frequency: "q8-12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary prokinetic reference; compounded product.", notes: "QT/drug interactions Compounded; concentration cannot be assumed Research preload rule: Dog 0.1–0.5 mg/kg; cat 2.5–5 mg/cat q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cisapride-cat-2", generic: "Cisapride", species: .cat,
            label: "Feline fixed-dose alternative", doseBasis: .fixedMg, minDose: 2.5, maxDose: 5,
            frequency: "q8h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary prokinetic reference; compounded product.", notes: "QT/drug interactions Compounded; concentration cannot be assumed Research preload rule: Dog 0.1–0.5 mg/kg; cat 2.5–5 mg/cat q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lactulose-dog-1", generic: "Lactulose", species: .dog,
            label: "Constipation / stool-softening", doseBasis: .mLKg, minDose: 0.25, maxDose: 0.5,
            frequency: "q6-8h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD laxative guidance.", notes: "Stool/electrolyte guided Titrate to clinical endpoint Research preload rule: Dog 0.25–0.5 mL/kg q6–8h; feline titration branch",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lactulose-cat-1", generic: "Lactulose", species: .cat,
            label: "Constipation / megacolon", doseBasis: .mLKg, minDose: 0.5, maxDose: 0.5,
            frequency: "q8-12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD laxative guidance.", notes: "Stool/electrolyte guided Titrate to clinical endpoint Research preload rule: Dog 0.25–0.5 mL/kg q6–8h; feline titration branch",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ursodiol-dog-1", generic: "Ursodiol", species: .dog,
            label: "10–15 mg/kg/day", doseBasis: .mgKg, minDose: 10.0, maxDose: 15.0,
            frequency: "q24h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD hepatobiliary pharmacology.", notes: "Avoid complete biliary obstruction Extra-label Research preload rule: 15 mg/kg PO q24h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ursodiol-cat-1", generic: "Ursodiol", species: .cat,
            label: "15 mg/kg PO q24h", doseBasis: .mgKg, minDose: 15.0, maxDose: 15.0,
            frequency: "q24h", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD hepatobiliary pharmacology.", notes: "Avoid complete biliary obstruction Extra-label Research preload rule: 15 mg/kg PO q24h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mirtazapine-oral-cat-1", generic: "Mirtazapine oral", species: .cat,
            label: "Feline oral appetite stimulation", doseBasis: .fixedMg, minDose: 1.88, maxDose: 1.88,
            frequency: "q72h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Veterinary GI/appetite-stimulation literature.", notes: "Serotonergic; renal/hepatic effects Extra-label; feline oral vs Mirataz must be separated Research preload rule: Cat 1.88 mg/cat q48–72h; dog weight-band dosing",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mirtazapine-oral-dog-1", generic: "Mirtazapine oral", species: .dog,
            label: "Dogs <7 kg", doseBasis: .fixedMg, minDose: 3.75, maxDose: 3.75,
            frequency: "q24h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Veterinary GI/appetite-stimulation literature.", notes: "Serotonergic; renal/hepatic effects Extra-label; feline oral vs Mirataz must be separated Research preload rule: Cat 1.88 mg/cat q48–72h; dog weight-band dosing",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mirtazapine-oral-dog-2", generic: "Mirtazapine oral", species: .dog,
            label: "Dogs >7-15 kg", doseBasis: .fixedMg, minDose: 7.5, maxDose: 7.5,
            frequency: "q24h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Veterinary GI/appetite-stimulation literature.", notes: "Serotonergic; renal/hepatic effects Extra-label; feline oral vs Mirataz must be separated Research preload rule: Cat 1.88 mg/cat q48–72h; dog weight-band dosing",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mirtazapine-oral-dog-3", generic: "Mirtazapine oral", species: .dog,
            label: "Dogs >15-30 kg", doseBasis: .fixedMg, minDose: 15, maxDose: 15,
            frequency: "q24h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Veterinary GI/appetite-stimulation literature.", notes: "Serotonergic; renal/hepatic effects Extra-label; feline oral vs Mirataz must be separated Research preload rule: Cat 1.88 mg/cat q48–72h; dog weight-band dosing",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mirtazapine-oral-dog-4", generic: "Mirtazapine oral", species: .dog,
            label: "Dogs >30 kg", doseBasis: .fixedMg, minDose: 30, maxDose: 30,
            frequency: "q24h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Veterinary GI/appetite-stimulation literature.", notes: "Serotonergic; renal/hepatic effects Extra-label; feline oral vs Mirataz must be separated Research preload rule: Cat 1.88 mg/cat q48–72h; dog weight-band dosing",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "dexamethasone-dog-1", generic: "Dexamethasone", species: .dog,
            label: "Anti-inflammatory 0.05–0.2 mg/kg; selected immune protocol 0.2–0.4 mg/kg — 0.05-0.2 mg/kg branch", doseBasis: .mgKg, minDose: 0.05, maxDose: 0.2,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Veterinary corticosteroid literature.", notes: "Dose-intensity template only. Dexamethasone route and interval vary materially by indication/formulation; veterinarian must select and verify the intended clinical protocol before use.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexamethasone-dog-2", generic: "Dexamethasone", species: .dog,
            label: "Anti-inflammatory 0.05–0.2 mg/kg; selected immune protocol 0.2–0.4 mg/kg — 0.2-0.4 mg/kg branch", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Veterinary corticosteroid literature.", notes: "Dose-intensity template only. Dexamethasone route and interval vary materially by indication/formulation; veterinarian must select and verify the intended clinical protocol before use.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexamethasone-cat-1", generic: "Dexamethasone", species: .cat,
            label: "Anti-inflammatory 0.05–0.2 mg/kg; selected immune protocol 0.2–0.4 mg/kg — 0.05-0.2 mg/kg branch", doseBasis: .mgKg, minDose: 0.05, maxDose: 0.2,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Veterinary corticosteroid literature.", notes: "Dose-intensity template only. Dexamethasone route and interval vary materially by indication/formulation; veterinarian must select and verify the intended clinical protocol before use.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dexamethasone-cat-2", generic: "Dexamethasone", species: .cat,
            label: "Anti-inflammatory 0.05–0.2 mg/kg; selected immune protocol 0.2–0.4 mg/kg — 0.2-0.4 mg/kg branch", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Veterinary corticosteroid literature.", notes: "Dose-intensity template only. Dexamethasone route and interval vary materially by indication/formulation; veterinarian must select and verify the intended clinical protocol before use.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "methylprednisolone-cat-1", generic: "Methylprednisolone", species: .cat,
            label: "Feline atopic skin syndrome induction", doseBasis: .mgKg, minDose: 1.4, maxDose: 1.5,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Secondary veterinary literature; Moderate confidence", notes: "Do not interchange depot/soluble rules Formulation/route distinctions Research preload rule: Anti-inflammatory and feline dermatologic branches",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "methylprednisolone-cat-2", generic: "Methylprednisolone", species: .cat,
            label: "Feline asthma depot branch", doseBasis: .fixedMg, minDose: 20, maxDose: 20,
            frequency: "q3wk", route: "IM", strengths: [], concentration: nil,
            sourceReference: "Secondary veterinary literature; Moderate confidence", notes: "Do not interchange depot/soluble rules Formulation/route distinctions Research preload rule: Anti-inflammatory and feline dermatologic branches",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "methylprednisolone-dog-1", generic: "Methylprednisolone", species: .dog,
            label: "Anti-inflammatory oral-equivalent branch", doseBasis: .mgKg, minDose: 0.4, maxDose: 0.8,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Secondary veterinary literature; Moderate confidence", notes: "Do not interchange depot/soluble rules Formulation/route distinctions Research preload rule: Anti-inflammatory and feline dermatologic branches",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "triamcinolone-dog-1", generic: "Triamcinolone", species: .dog,
            label: "Anti-inflammatory 0.1–0.2; immunosuppressive 0.2–0.4 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Secondary veterinary literature; Moderate confidence", notes: "Moderate-confidence dose-intensity template. Route, formulation (including depot/topical products), and interval are not interchangeable; veterinarian protocol confirmation is required before use.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "triamcinolone-cat-1", generic: "Triamcinolone", species: .cat,
            label: "Anti-inflammatory 0.1–0.2; immunosuppressive 0.2–0.4 mg/kg", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "veterinarian-selected protocol", route: "indication/formulation-specific", strengths: [], concentration: nil,
            sourceReference: "Secondary veterinary literature; Moderate confidence", notes: "Moderate-confidence dose-intensity template. Route, formulation (including depot/topical products), and interval are not interchangeable; veterinarian protocol confirmation is required before use.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "amlodipine-dog-1", generic: "Amlodipine", species: .dog,
            label: "Once-daily hypertension regimen", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.4,
            frequency: "q24h", route: "PO", strengths: [10], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "BP monitoring FDA-approved feline product now exists; small-patient/product restrictions matter Research preload rule: Dog 0.1–0.4 mg/kg/day; cat ~0.125–0.5 mg/kg/day",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "amlodipine-cat-1", generic: "Amlodipine", species: .cat,
            label: "Initial long-term hypertension dose", doseBasis: .mgKg, minDose: 0.125, maxDose: 0.125,
            frequency: "q24h", route: "PO", strengths: [10], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Starting dose only. Blood-pressure response determines gradual weekly titration; a higher maintenance dose requires an explicitly reviewed protocol.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "atenolol-dog-1", generic: "Atenolol", species: .dog,
            label: "Cardiac/tachyarrhythmia", doseBasis: .mgKg, minDose: 0.2, maxDose: 1.5,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiovascular guidance.", notes: "HR/BP Extra-label; titrate to physiologic response Research preload rule: Dog 0.2–1.5 mg/kg q12h; cat 1–2.5 mg/kg or 6.25–12.5 mg/cat",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "atenolol-cat-1", generic: "Atenolol", species: .cat,
            label: "Cardiac/tachyarrhythmia", doseBasis: .mgKg, minDose: 1, maxDose: 2.5,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiovascular guidance.", notes: "HR/BP Extra-label; titrate to physiologic response Research preload rule: Dog 0.2–1.5 mg/kg q12h; cat 1–2.5 mg/kg or 6.25–12.5 mg/cat",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "atenolol-cat-2", generic: "Atenolol", species: .cat,
            label: "Feline fixed-dose alternative", doseBasis: .fixedMg, minDose: 6.25, maxDose: 12.5,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiovascular guidance.", notes: "HR/BP Extra-label; titrate to physiologic response Research preload rule: Dog 0.2–1.5 mg/kg q12h; cat 1–2.5 mg/kg or 6.25–12.5 mg/cat",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "diltiazem-dog-1", generic: "Diltiazem", species: .dog,
            label: "Immediate release", doseBasis: .mgKg, minDose: 0.5, maxDose: 3,
            frequency: "q8h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Never interchange IR and ER calculation IR and sustained-release doses not interchangeable Research preload rule: IR and ER branches by species",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "diltiazem-dog-2", generic: "Diltiazem", species: .dog,
            label: "Extended release", doseBasis: .mgKg, minDose: 2, maxDose: 4,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Never interchange IR and ER calculation IR and sustained-release doses not interchangeable Research preload rule: IR and ER branches by species",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "diltiazem-cat-1", generic: "Diltiazem", species: .cat,
            label: "Immediate release", doseBasis: .mgKg, minDose: 1.5, maxDose: 3,
            frequency: "q8-12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Never interchange IR and ER calculation IR and sustained-release doses not interchangeable Research preload rule: IR and ER branches by species",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "diltiazem-cat-2", generic: "Diltiazem", species: .cat,
            label: "Extended release fixed dose", doseBasis: .fixedMg, minDose: 30, maxDose: 60,
            frequency: "q12-24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Never interchange IR and ER calculation IR and sustained-release doses not interchangeable Research preload rule: IR and ER branches by species",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clopidogrel-dog-1", generic: "Clopidogrel", species: .dog,
            label: "Maintenance antithrombotic", doseBasis: .mgKg, minDose: 1, maxDose: 4,
            frequency: "q24h", route: "PO", strengths: [75], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Bleeding/perioperative management Extra-label Research preload rule: Dog 1–4 mg/kg q24h; cat 18.75 mg q24h after optional load",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clopidogrel-cat-1", generic: "Clopidogrel", species: .cat,
            label: "Maintenance feline antithrombotic", doseBasis: .fixedMg, minDose: 18.75, maxDose: 18.75,
            frequency: "q24h", route: "PO", strengths: [75], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Bleeding/perioperative management Extra-label Research preload rule: Dog 1–4 mg/kg q24h; cat 18.75 mg q24h after optional load",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clopidogrel-cat-2", generic: "Clopidogrel", species: .cat,
            label: "Optional feline loading dose", doseBasis: .fixedMg, minDose: 37.5, maxDose: 75,
            frequency: "once", route: "PO", strengths: [75], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Bleeding/perioperative management Extra-label Research preload rule: Dog 1–4 mg/kg q24h; cat 18.75 mg q24h after optional load",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "digoxin-dog-1", generic: "Digoxin", species: .dog,
            label: "MSD dog/cat cardiac table 0.0025–0.005 mg/kg", doseBasis: .mgKg, minDose: 0.0025, maxDose: 0.005,
            frequency: "q12h", route: "PO", strengths: [0.125, 0.25], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Narrow therapeutic index. Cardiac table states do not exceed 0.25 mg/dog per dose. Dose by lean body weight where appropriate; adjust for renal function and use serum digoxin monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "digoxin-dog-2", generic: "Digoxin", species: .dog,
            label: "MSD systemic pharmacotherapy broader range 0.003–0.011 mg/kg", doseBasis: .mgKg, minDose: 0.003, maxDose: 0.011,
            frequency: "q12h", route: "PO", strengths: [0.125, 0.25], concentration: nil,
            sourceReference: "MSD Veterinary Manual systemic cardiovascular pharmacotherapy table.", notes: "This separate MSD table gives a broader range and explicitly says to round down to limit toxicosis. Do not interchange this selector with the more conservative dog/cat cardiac-table branch without veterinarian review; TDM and renal/lean-body-weight assessment required.",
            confidence: "High — source divergence shown", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "digoxin-cat-1", generic: "Digoxin", species: .cat,
            label: "Cat <3 kg: 0.01 mg/kg", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.01,
            frequency: "q48h", route: "PO", strengths: [0.125], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Use this selector only for cats <3 kg. Narrow therapeutic index; renal function, clinical response, and serum digoxin concentration guide ongoing dosing.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "digoxin-cat-2", generic: "Digoxin", species: .cat,
            label: "Cat 3–6 kg: 0.03125 mg/cat", doseBasis: .fixedMg, minDose: 0.03125, maxDose: 0.03125,
            frequency: "q24–48h", route: "PO", strengths: [0.125], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "One-quarter of a 0.125 mg tablet. Use only for the 3–6 kg feline selector; narrow therapeutic index and TDM/renal monitoring required.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "digoxin-cat-3", generic: "Digoxin", species: .cat,
            label: "Cat >6 kg: 0.03125 mg/cat", doseBasis: .fixedMg, minDose: 0.03125, maxDose: 0.03125,
            frequency: "q12–24h", route: "PO", strengths: [0.125], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "One-quarter of a 0.125 mg tablet. Use only for the >6 kg feline selector; narrow therapeutic index and TDM/renal monitoring required.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "sildenafil-dog-1", generic: "Sildenafil", species: .dog,
            label: "1–3 mg/kg", doseBasis: .mgKg, minDose: 1.0, maxDose: 3.0,
            frequency: "q8h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "BP/nitrate interaction Extra-label Research preload rule: Approximately 1–3 mg/kg q8–12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sildenafil-cat-1", generic: "Sildenafil", species: .cat,
            label: "1–3 mg/kg", doseBasis: .mgKg, minDose: 1.0, maxDose: 3.0,
            frequency: "q8h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "BP/nitrate interaction Extra-label Research preload rule: Approximately 1–3 mg/kg q8–12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "hydralazine-dog-1", generic: "Hydralazine", species: .dog,
            label: "Initial oral dose; subsequent titration requires review", doseBasis: .mgKg, minDose: 0.5, maxDose: 0.5,
            frequency: "once", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Close BP monitoring BP-guided; no one-size default Research preload rule: Dog 0.5 mg/kg start → 1–3 q12h; acute feline branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "hydralazine-dog-2", generic: "Hydralazine", species: .dog,
            label: "Maintenance/titration", doseBasis: .mgKg, minDose: 1, maxDose: 3,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Close BP monitoring BP-guided; no one-size default Research preload rule: Dog 0.5 mg/kg start → 1–3 q12h; acute feline branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "hydralazine-cat-1", generic: "Hydralazine", species: .cat,
            label: "Acute feline hypertension", doseBasis: .fixedMg, minDose: 0.2, maxDose: 0.5,
            frequency: "once; may repeat after 15 min if needed", route: "SC", strengths: [], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Close BP monitoring BP-guided; no one-size default Research preload rule: Dog 0.5 mg/kg start → 1–3 q12h; acute feline branch",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "telmisartan-cat-1", generic: "Telmisartan", species: .cat,
            label: "Systemic hypertension initial: 1.5 mg/kg PO q12h for 14 days", doseBasis: .mgKg, minDose: 1.5, maxDose: 1.5,
            frequency: "q12h for 14 days", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac/RAAS guidance.", notes: "Initial feline systemic-hypertension branch. Monitor blood pressure, renal function and potassium; then use the maintenance branch if appropriate.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "telmisartan-cat-2", generic: "Telmisartan", species: .cat,
            label: "Systemic hypertension maintenance: 2 mg/kg PO q24h", doseBasis: .mgKg, minDose: 2.0, maxDose: 2.0,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD cardiac/RAAS guidance.", notes: "Maintenance feline systemic-hypertension branch after the labeled/guideline initial phase. Monitor blood pressure, renal function and potassium.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "telmisartan-cat-3", generic: "Telmisartan", species: .cat,
            label: "CKD-associated proteinuria: 1 mg/kg PO q24h", doseBasis: .mgKg, minDose: 1, maxDose: 1,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Angiotensin II Receptor Antagonists for Use in Animals.", notes: "Proteinuria branch; do not substitute for the feline systemic-hypertension regimen. Monitor renal function, potassium and blood pressure.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "torsemide-dog-1", generic: "Torsemide", species: .dog,
            label: "Refractory CHF", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.4,
            frequency: "q12-24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Renal/electrolyte monitoring Extra-label/product dependent Research preload rule: Dog 0.1–0.4; cat 0.05–0.25 mg/kg q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "torsemide-cat-1", generic: "Torsemide", species: .cat,
            label: "Refractory CHF", doseBasis: .mgKg, minDose: 0.05, maxDose: 0.25,
            frequency: "q12-24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD cardiac guidance.", notes: "Renal/electrolyte monitoring Extra-label/product dependent Research preload rule: Dog 0.1–0.4; cat 0.05–0.25 mg/kg q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "torsemide-cat-2", generic: "Torsemide", species: .cat,
            label: "Feline fixed-dose alternative", doseBasis: .fixedMg, minDose: 1.25, maxDose: 1.25,
            frequency: "q12–24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "https://www.msdvetmanual.com/multimedia/table/cardiac-medications-of-dogs-and-cats", notes: "Renal/electrolyte monitoring Extra-label/product dependent Research preload rule: Dog 0.1–0.4; cat 0.05–0.25 mg/kg q12–24h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levothyroxine-dog-1", generic: "Levothyroxine", species: .dog,
            label: "22 mcg/kg (0.022 mg/kg) PO q24h", doseBasis: .mgKg, minDose: 0.022, maxDose: 0.022,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary endocrine guidance; T4 monitoring determines final maintenance dose.", notes: "Give consistently relative to food and monitor thyroid concentrations/clinical response; lifelong replacement is typical.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "levothyroxine-dog-2", generic: "Levothyroxine", species: .dog,
            label: "11 mcg/kg (0.011 mg/kg) PO q12h divided regimen", doseBasis: .mgKg, minDose: 0.011, maxDose: 0.011,
            frequency: "q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary endocrine guidance; T4 monitoring determines final maintenance dose.", notes: "Divided-dose equivalent of approximately 22 mcg/kg/day; monitor thyroid concentrations/clinical response and keep administration relative to food consistent.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "trilostane-dog-1", generic: "Trilostane", species: .dog,
            label: "2.2–6.7 mg/kg q24h with food, start low", doseBasis: .mgKg, minDose: 2.2, maxDose: 6.7,
            frequency: "q24h with food", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Current VETORYL manufacturer information.", notes: "FDA-labeled starting branch. Start with the lowest possible capsule combination; individual dose adjustment and close endocrine/electrolyte monitoring are essential.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-dog-1", generic: "Desmopressin", species: .dog,
            label: "Hemostatic support 0.3–1 mcg/kg", doseBasis: .mcgKg, minDose: 0.3, maxDose: 1.0,
            frequency: "once", route: "SC/IV", strengths: [], concentration: nil,
            sourceReference: "MSD CDI and hemostatic guidance.", notes: "One-time hemostatic branch; repeated dosing has diminished effect and can cause water retention/hyponatremia. Do not use this branch for central diabetes insipidus.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-cat-1", generic: "Desmopressin", species: .cat,
            label: "Hemostatic support 0.3–1 mcg/kg", doseBasis: .mcgKg, minDose: 0.3, maxDose: 1.0,
            frequency: "once", route: "SC/IV", strengths: [], concentration: nil,
            sourceReference: "MSD CDI and hemostatic guidance.", notes: "One-time hemostatic branch; repeated dosing has diminished effect and can cause water retention/hyponatremia. Do not use this branch for central diabetes insipidus.",
            confidence: "Moderate", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-dog-2", generic: "Desmopressin", species: .dog,
            label: "Central diabetes insipidus oral 0.1–0.2 mg/dog", doseBasis: .fixedMg, minDose: 0.1, maxDose: 0.2,
            frequency: "q8–12h initially; titrate to minimum effective dose", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Diabetes Insipidus in Animals.", notes: "CDI branch. Water must remain freely available; titrate from clinical response and water intake. Do not substitute this mg/patient branch for the mcg/kg hemostatic protocol.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-dog-3", generic: "Desmopressin", species: .dog,
            label: "Central diabetes insipidus 0.1 mg/mL solution: 2 drops", doseBasis: .dropsEye, minDose: 2, maxDose: 2,
            frequency: "q12–24h after titration", route: "nasal mucosa/conjunctival sac", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Diabetes Insipidus in Animals.", notes: "Use the 0.1 mg/mL desmopressin solution described by the reference. Water must remain freely available and dose interval is titrated to response.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-cat-2", generic: "Desmopressin", species: .cat,
            label: "CDI therapeutic trial oral 0.1–0.2 mg/cat", doseBasis: .fixedMg, minDose: 0.1, maxDose: 0.2,
            frequency: "q12h for monitored therapeutic trial", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Diabetes Insipidus in Animals.", notes: "Feline monitored therapeutic-trial branch. Maintain free access to water and reassess water intake/urine output; subsequent dosing is response-guided.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "desmopressin-cat-3", generic: "Desmopressin", species: .cat,
            label: "CDI therapeutic trial 0.1 mg/mL solution: 1–4 drops", doseBasis: .dropsEye, minDose: 1, maxDose: 4,
            frequency: "q12h for monitored therapeutic trial", route: "conjunctival sac", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Diabetes Insipidus in Animals.", notes: "Feline monitored therapeutic-trial branch using the 0.1 mg/mL solution described by the reference. Maintain free access to water.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fludrocortisone-dog-1", generic: "Fludrocortisone", species: .dog,
            label: "~0.02 mg/kg/day PO, q24h or divided", doseBasis: .mgKg, minDose: 0.02, maxDose: 0.02,
            frequency: "q24h", route: "PO", strengths: [0.1], concentration: nil,
            sourceReference: "MSD hypoadrenocorticism guidance.", notes: "Na/K guided Extra-label, lab-driven Research preload rule: ~0.02 mg/kg/day PO, q24h or divided",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "desoxycorticosterone-pivalate-dog-1", generic: "Desoxycorticosterone pivalate", species: .dog,
            label: "2.2 mg/kg SC initial", doseBasis: .mgKg, minDose: 2.2, maxDose: 2.2,
            frequency: "initial dose; reassess ~day 10 and ~day 25 before subsequent dosing", route: "SC", strengths: [], concentration: 25.0,
            sourceReference: "Current ZYCORTAL manufacturer source.", notes: "ZYCORTAL 25 mg/mL initial dose. Second/subsequent dose and interval must be adjusted from clinical response and Na/K monitoring; glucocorticoid replacement may also be required.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "mitotane-dog-1", generic: "Mitotane", species: .dog,
            label: "Loading 25 mg/kg", doseBasis: .mgKg, minDose: 25, maxDose: 25,
            frequency: "q12h during loading phase", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD Veterinary Manual hyperadrenocorticism guidance.", notes: "Loading phase only; transition is determined by clinical response and adrenal-function testing. Risk of hypoadrenocorticism/adrenal crisis requires veterinarian-directed monitoring.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "mitotane-dog-2", generic: "Mitotane", species: .dog,
            label: "Maintenance total 25–50 mg/kg/week", doseBasis: .mgKg, minDose: 25, maxDose: 50,
            frequency: "total per week; divide per monitored protocol", route: "PO", strengths: [500], concentration: nil,
            sourceReference: "MSD Veterinary Manual hyperadrenocorticism guidance.", notes: "Weekly TOTAL maintenance dose, not q12h. Divide according to the veterinarian's monitored maintenance protocol and adrenal-function testing.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "zonisamide-dog-1", generic: "Zonisamide", species: .dog,
            label: "5–10 mg/kg", doseBasis: .mgKg, minDose: 5.0, maxDose: 10.0,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD epilepsy guidance.", notes: "Monitor response/adverse effects Extra-label Research preload rule: 5–10 mg/kg PO q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "zonisamide-cat-1", generic: "Zonisamide", species: .cat,
            label: "5–10 mg/kg", doseBasis: .mgKg, minDose: 5.0, maxDose: 10.0,
            frequency: "q12h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD epilepsy guidance.", notes: "Monitor response/adverse effects Extra-label Research preload rule: 5–10 mg/kg PO q12h",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "potassium-bromide-dog-1", generic: "Potassium bromide", species: .dog,
            label: "Maintenance ~11–30 mg/kg q24h; loading separate", doseBasis: .mgKg, minDose: 11.0, maxDose: 30.0,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD epilepsy guidance; not recommended in cats because of severe respiratory adverse effects.", notes: "Labeled maintenance branch. Serum bromide and chloride intake affect therapy; not recommended in cats because of severe respiratory adverse effects.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "pregabalin-dog-1", generic: "Pregabalin", species: .dog,
            label: "Pain/neuropathic pain", doseBasis: .mgKg, minDose: 2, maxDose: 5,
            frequency: "q8-12h", route: "PO", strengths: [150], concentration: nil,
            sourceReference: "MSD feline behavior guidance.", notes: "Sedation/ataxia, renal adjustment **CV** federally; FDA-approved feline pre-visit product exists Research preload rule: Dog pain 2–5 mg/kg q8–12h; cat 1–2 mg/kg, situational 5–10 mg/kg once",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "pregabalin-cat-1", generic: "Pregabalin", species: .cat,
            label: "Feline anxiety: extra-label as-needed regimen", doseBasis: .mgKg, minDose: 1, maxDose: 2,
            frequency: "q12h as needed", route: "PO", strengths: [150], concentration: nil,
            sourceReference: "MSD feline behavior guidance.", notes: "Extra-label feline behavioral regimen; not a chronic pain range or the BONQAT 5 mg/kg single-event label. Sedation/ataxia and renal function require review. DEA Schedule V.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "pregabalin-cat-2", generic: "Pregabalin", species: .cat,
            label: "Situational anxiety", doseBasis: .mgKg, minDose: 5, maxDose: 10,
            frequency: "once 90 min before stress", route: "PO", strengths: [150], concentration: nil,
            sourceReference: "MSD feline behavior guidance.", notes: "Sedation/ataxia, renal adjustment **CV** federally; FDA-approved feline pre-visit product exists Research preload rule: Dog pain 2–5 mg/kg q8–12h; cat 1–2 mg/kg, situational 5–10 mg/kg once",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "methocarbamol-dog-1", generic: "Methocarbamol", species: .dog,
            label: "Oral total daily dose 66–132 mg/kg/day divided 2–3 times", doseBasis: .mgKg, minDose: 66.0, maxDose: 132.0,
            frequency: "divide total daily amount into 2–3 doses/day", route: "PO", strengths: [750], concentration: nil,
            sourceReference: "MSD muscle-relaxant table.", notes: "Calculator result is the TOTAL DAILY oral amount; divide it into 2–3 administrations. Do not administer the displayed daily total as each individual dose.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "methocarbamol-dog-2", generic: "Methocarbamol", species: .dog,
            label: "Tetanus/strychnine protocol 44 mg/kg IV increment", doseBasis: .mgKg, minDose: 44.0, maxDose: 44.0,
            frequency: "repeat increments only to monitored response; max 330 mg/kg/day", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD muscle-relaxant table.", notes: "Monitored IV severe-tremor/toxin branch. Each calculator result is one 44 mg/kg increment; do not exceed the cited total daily ceiling of 330 mg/kg/day.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "methocarbamol-cat-1", generic: "Methocarbamol", species: .cat,
            label: "Oral total daily dose 66–132 mg/kg/day divided 2–3 times", doseBasis: .mgKg, minDose: 66.0, maxDose: 132.0,
            frequency: "divide total daily amount into 2–3 doses/day", route: "PO", strengths: [750], concentration: nil,
            sourceReference: "MSD muscle-relaxant table.", notes: "Calculator result is the TOTAL DAILY oral amount; divide it into 2–3 administrations. Do not administer the displayed daily total as each individual dose.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "methocarbamol-cat-2", generic: "Methocarbamol", species: .cat,
            label: "Tetanus/strychnine protocol 44 mg/kg IV increment", doseBasis: .mgKg, minDose: 44.0, maxDose: 44.0,
            frequency: "repeat increments only to monitored response; max 330 mg/kg/day", route: "IV", strengths: [], concentration: nil,
            sourceReference: "MSD muscle-relaxant table.", notes: "Monitored IV severe-tremor/toxin branch. Each calculator result is one 44 mg/kg increment; do not exceed the cited total daily ceiling of 330 mg/kg/day.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "clomipramine-dog-1", generic: "Clomipramine", species: .dog,
            label: "2–4 mg/kg/day", doseBasis: .mgKg, minDose: 2.0, maxDose: 4.0,
            frequency: "q24h total daily dose; may divide q12h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD canine behavior guidance; FDA-approved indication is canine separation anxiety.", notes: "Canine label total daily dose branch. Serotonergic/TCA interactions and cardiac/seizure precautions apply; behavior plan and monitoring remain necessary.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sertraline-dog-1", generic: "Sertraline", species: .dog,
            label: "Canine behavioral disorders", doseBasis: .mgKg, minDose: 0.5, maxDose: 4,
            frequency: "q24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD dog behavior guidance; feline use extra-label.", notes: "Delayed onset, serotonin syndrome, taper Extra-label Research preload rule: Dog 0.5–4 mg/kg q24h; feline lower-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sertraline-cat-1", generic: "Sertraline", species: .cat,
            label: "Feline clinic-reviewed SSRI template", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.5,
            frequency: "q24h", route: "PO", strengths: [100], concentration: nil,
            sourceReference: "MSD dog behavior guidance; feline use extra-label.", notes: "Delayed onset, serotonin syndrome, taper Extra-label Research preload rule: Dog 0.5–4 mg/kg q24h; feline lower-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "paroxetine-dog-1", generic: "Paroxetine", species: .dog,
            label: "Canine behavioral disorders", doseBasis: .mgKg, minDose: 1, maxDose: 2,
            frequency: "q24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD dog/cat behavior sources.", notes: "Serotonergic/withdrawal Extra-label Research preload rule: Dog 1–2 mg/kg q24h; feline lower-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "paroxetine-cat-1", generic: "Paroxetine", species: .cat,
            label: "Feline clinic-reviewed SSRI template", doseBasis: .mgKg, minDose: 0.5, maxDose: 1,
            frequency: "q24h", route: "PO", strengths: [40], concentration: nil,
            sourceReference: "MSD dog/cat behavior sources.", notes: "Serotonergic/withdrawal Extra-label Research preload rule: Dog 1–2 mg/kg q24h; feline lower-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "buspirone-dog-1", generic: "Buspirone", species: .dog,
            label: "Canine anxiety", doseBasis: .mgKg, minDose: 0.5, maxDose: 2,
            frequency: "q8-12h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "MSD canine/feline behavior sources.", notes: "Delayed onset Extra-label Research preload rule: Dog 0.5–2 mg/kg q8–12h; feline fixed-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "buspirone-cat-1", generic: "Buspirone", species: .cat,
            label: "Feline anxiety/urine-marking fixed dose", doseBasis: .fixedMg, minDose: 2.5, maxDose: 7.5,
            frequency: "q12h", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "MSD canine/feline behavior sources.", notes: "Delayed onset Extra-label Research preload rule: Dog 0.5–2 mg/kg q8–12h; feline fixed-dose branch",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "clonidine-dog-1", generic: "Clonidine", species: .dog,
            label: "0.01–0.05 mg/kg q8h PRN or q8–12h scheduled", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.05,
            frequency: "q8h, q8-12h", route: "PO", strengths: [0.3], concentration: nil,
            sourceReference: "MSD canine behavior guidance.", notes: "BP/HR/sedation Extra-label Research preload rule: 0.01–0.05 mg/kg q8h PRN or q8–12h scheduled",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "selegiline-dog-1", generic: "Selegiline", species: .dog,
            label: "0.5–1 mg/kg q24h AM for CDS; endocrine label differs", doseBasis: .mgKg, minDose: 0.5, maxDose: 1.0,
            frequency: "q24h in the morning", route: "PO", strengths: [30], concentration: nil,
            sourceReference: "Current ANIPRYL manufacturer information.", notes: "Canine cognitive-dysfunction branch. Avoid incompatible MAOI/serotonergic combinations and reassess response/tolerance.",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "hydroxyzine-dog-1", generic: "Hydroxyzine", species: .dog,
            label: "0.5–2 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 2.0,
            frequency: "q6–8h as needed", route: "PO/IV", strengths: [50], concentration: nil,
            sourceReference: "MSD antihistamine table.", notes: "Sedation Extra-label Research preload rule: 0.5–2 mg/kg q6–8h PRN",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "hydroxyzine-cat-1", generic: "Hydroxyzine", species: .cat,
            label: "0.5–2 mg/kg", doseBasis: .mgKg, minDose: 0.5, maxDose: 2.0,
            frequency: "q6–8h as needed", route: "PO/IV", strengths: [50], concentration: nil,
            sourceReference: "MSD antihistamine table.", notes: "Sedation Extra-label Research preload rule: 0.5–2 mg/kg q6–8h PRN",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "chlorpheniramine-dog-1", generic: "Chlorpheniramine", species: .dog,
            label: "AAHA oral canine antihistamine regimen", doseBasis: .mgKg, minDose: 0.4, maxDose: 0.4,
            frequency: "q12h", route: "PO", strengths: [4], concentration: nil,
            sourceReference: "https://www.aaha.org/resources/2023-aaha-management-of-allergic-skin-diseases-in-dogs-and-cats-guidelines/table-3-oral-antihistamine-doses-for-dogs/", notes: "Single-ingredient oral product only. Monitor sedation and anticholinergic effects; clinician selects suitability for allergic disease.",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "chlorpheniramine-cat-1", generic: "Chlorpheniramine", species: .cat,
            label: "Feline antihistamine", doseBasis: .fixedMg, minDose: 2, maxDose: 4,
            frequency: "q12h", route: "PO", strengths: [4], concentration: nil,
            sourceReference: "MSD antihistamine table.", notes: "Sedation Extra-label Research preload rule: Cat 2–4 mg/cat q12h; dog 4–8 mg or 0.25–0.5 mg/kg q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lokivetmab-dog-1", generic: "Lokivetmab", species: .dog,
            label: "~2 mg/kg SC; repeat q4–8 wk as needed", doseBasis: .mgKg, minDose: 2.0, maxDose: 2.0,
            frequency: "q4-8wk", route: "SC", strengths: [], concentration: nil,
            sourceReference: "Current CYTOPOINT manufacturer information.", notes: "Select vial combination FDA veterinary biologic/product workflow Research preload rule: Minimum ~2 mg/kg SC via vial/weight-band selection; repeat q4–8wk PRN",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cyclosporine-ophthalmic-dog-1", generic: "Cyclosporine ophthalmic", species: .dog,
            label: "OPTIMMUNE 0.2% ointment: 1/4-inch strip per affected eye", doseBasis: .ribbonInch, minDose: 0.25, maxDose: 0.25,
            frequency: "q12h", route: "Ophthalmic", strengths: [], concentration: nil,
            sourceReference: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=8ee9c677-d86c-4f2f-9eec-6998f4394ae1", notes: "Canine KCS/CSK labeled ointment. Apply the strip to each affected eye every 12 hours after removing debris. This is an ointment length, not drops or a liquid volume. Verify affected eyes and monitor ocular response.",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "cyclosporine-ophthalmic-cat-1", generic: "Cyclosporine ophthalmic", species: .cat,
            label: "Compounded 0.2% ophthalmic template", doseBasis: .dropsEye, minDose: 1, maxDose: 1,
            frequency: "q12h", route: "Ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmology/KCS guidance.", notes: "Tear/ocular monitoring Approved/compounded formulations must not be conflated Research preload rule: 0.2% q12h; selected refractory compounded 1–2% branch",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "tacrolimus-ophthalmic-dog-1", generic: "Tacrolimus ophthalmic", species: .dog,
            label: "0.02–0.03%, one drop q12h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q12h", route: "Ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Compounded veterinary ophthalmology literature; Moderate confidence", notes: "Ocular monitoring Compounded only; concentration mandatory Research preload rule: 0.02–0.03%, one drop q12h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "tacrolimus-ophthalmic-cat-1", generic: "Tacrolimus ophthalmic", species: .cat,
            label: "0.02–0.03%, one drop q12h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q12h", route: "Ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Compounded veterinary ophthalmology literature; Moderate confidence", notes: "Ocular monitoring Compounded only; concentration mandatory Research preload rule: 0.02–0.03%, one drop q12h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "latanoprost-dog-1", generic: "Latanoprost", species: .dog,
            label: "0.005%, one drop q12h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q12h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "MSD glaucoma guidance; efficacy is limited in cats.", notes: "IOP/glaucoma-type dependent Human product extra-label; contraindication logic needed Research preload rule: 0.005%, one drop q12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "dorzolamide-dog-1", generic: "Dorzolamide", species: .dog,
            label: "2%, one drop q8h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q8h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "MSD glaucoma guidance.", notes: "IOP monitoring Extra-label Research preload rule: 2%, one drop q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "dorzolamide-cat-1", generic: "Dorzolamide", species: .cat,
            label: "2%, one drop q8h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q8h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "MSD glaucoma guidance.", notes: "IOP monitoring Extra-label Research preload rule: 2%, one drop q8h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "timolol-ophthalmic-dog-1", generic: "Timolol ophthalmic", species: .dog,
            label: "0.5%, one drop q8–12h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q8-12h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "MSD glaucoma guidance.", notes: "Systemic beta-blockade possible Extra-label; systemic beta-blocker precautions Research preload rule: 0.5%, one drop q8–12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "timolol-ophthalmic-cat-1", generic: "Timolol ophthalmic", species: .cat,
            label: "0.5%, one drop q8–12h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q8-12h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "MSD glaucoma guidance.", notes: "Systemic beta-blockade possible Extra-label; systemic beta-blocker precautions Research preload rule: 0.5%, one drop q8–12h",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "atropine-ophthalmic-dog-1", generic: "Atropine ophthalmic", species: .dog,
            label: "1%, one drop q6–12h initially, then to cycloplegic effect", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q6-12h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmology guidance; contraindicated in glaucoma/ocular hypertension.", notes: "Avoid/caution with glaucoma/high IOP Must not default in glaucoma-risk situations Research preload rule: 1%, one drop q6–12h initially, then to cycloplegic effect",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "atropine-ophthalmic-cat-1", generic: "Atropine ophthalmic", species: .cat,
            label: "1%, one drop q6–12h initially, then to cycloplegic effect", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q6-12h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmology guidance; contraindicated in glaucoma/ocular hypertension.", notes: "Avoid/caution with glaucoma/high IOP Must not default in glaucoma-risk situations Research preload rule: 1%, one drop q6–12h initially, then to cycloplegic effect",
            confidence: "Moderate-high", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ofloxacin-ophthalmic-dog-1", generic: "Ofloxacin ophthalmic", species: .dog,
            label: "0.3%, one drop q4–6h; severe keratitis branch q1–2h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q4-6h, q1-2h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmic secondary literature; Moderate confidence", notes: "Ulcer protocols differ markedly Extra-label Research preload rule: 0.3%, one drop q4–6h; severe keratitis branch q1–2h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ofloxacin-ophthalmic-cat-1", generic: "Ofloxacin ophthalmic", species: .cat,
            label: "0.3%, one drop q4–6h; severe keratitis branch q1–2h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q4-6h, q1-2h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmic secondary literature; Moderate confidence", notes: "Ulcer protocols differ markedly Extra-label Research preload rule: 0.3%, one drop q4–6h; severe keratitis branch q1–2h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ciprofloxacin-ophthalmic-dog-1", generic: "Ciprofloxacin ophthalmic", species: .dog,
            label: "0.3%, one drop q4–6h; severe keratitis branch q1–2h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q4-6h, q1-2h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmic secondary literature; Moderate confidence", notes: "Culture/stewardship Extra-label Research preload rule: 0.3%, one drop q4–6h; severe keratitis branch q1–2h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ciprofloxacin-ophthalmic-cat-1", generic: "Ciprofloxacin ophthalmic", species: .cat,
            label: "0.3%, one drop q4–6h; severe keratitis branch q1–2h", doseBasis: .dropsEye, minDose: 1.0, maxDose: 1.0,
            frequency: "q4-6h, q1-2h", route: "ophthalmic", strengths: [], concentration: nil,
            sourceReference: "Veterinary ophthalmic secondary literature; Moderate confidence", notes: "Culture/stewardship Extra-label Research preload rule: 0.3%, one drop q4–6h; severe keratitis branch q1–2h",
            confidence: "Moderate", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "epinephrine-dog-1", generic: "Epinephrine", species: .dog,
            label: "CPR low-dose 0.01 mg/kg IV/IO q3–5 min", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.01,
            frequency: "q3–5 min during CPR", route: "IV/IO", strengths: [], concentration: 1.0,
            sourceReference: "2024 RECOVER consensus for CPR.", notes: "Concentration/indication lock essential High-risk emergency drug; indication lock mandatory Research preload rule: CPR 0.01 mg/kg IV/IO q3–5min; anaphylaxis branch separate",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "epinephrine-cat-1", generic: "Epinephrine", species: .cat,
            label: "CPR 0.01 mg/kg IV/IO q3–5min; anaphylaxis branch separate", doseBasis: .mgKg, minDose: 0.01, maxDose: 0.01,
            frequency: "q3–5 min during CPR", route: "IV/IO", strengths: [], concentration: 1.0,
            sourceReference: "2024 RECOVER consensus for CPR.", notes: "Concentration/indication lock essential High-risk emergency drug; indication lock mandatory Research preload rule: CPR 0.01 mg/kg IV/IO q3–5min; anaphylaxis branch separate",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "atropine-injection-dog-1", generic: "Atropine injection", species: .dog,
            label: "Non-arrest bradycardia 0.02–0.04 mg/kg", doseBasis: .mgKg, minDose: 0.02, maxDose: 0.04,
            frequency: "to effect", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Non-arrest vagolytic branch. CPR uses the separate RECOVER selector.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "atropine-injection-dog-2", generic: "Atropine injection", species: .dog,
            label: "RECOVER CPR 0.04 mg/kg", doseBasis: .mgKg, minDose: 0.04, maxDose: 0.04,
            frequency: "once, as early as possible when indicated", route: "IV/IO", strengths: [], concentration: nil,
            sourceReference: "2024 RECOVER CPR Guidelines.", notes: "CPR selector for non-shockable rhythms when atropine is indicated. RECOVER recommends one early dose and not repeated atropine dosing during CPR.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "atropine-injection-cat-1", generic: "Atropine injection", species: .cat,
            label: "Non-arrest bradycardia 0.02–0.04 mg/kg", doseBasis: .mgKg, minDose: 0.02, maxDose: 0.04,
            frequency: "to effect", route: "IV/IM/SC", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Non-arrest vagolytic branch. CPR uses the separate RECOVER selector.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "atropine-injection-cat-2", generic: "Atropine injection", species: .cat,
            label: "RECOVER CPR 0.04 mg/kg", doseBasis: .mgKg, minDose: 0.04, maxDose: 0.04,
            frequency: "once, as early as possible when indicated", route: "IV/IO", strengths: [], concentration: nil,
            sourceReference: "2024 RECOVER CPR Guidelines.", notes: "CPR selector for non-shockable rhythms when atropine is indicated. RECOVER recommends one early dose and not repeated atropine dosing during CPR.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "glycopyrrolate-dog-1", generic: "Glycopyrrolate", species: .dog,
            label: "0.005–0.01 mg/kg", doseBasis: .mgKg, minDose: 0.005, maxDose: 0.01,
            frequency: "to effect", route: "IV/IM/SC", strengths: [], concentration: 0.2,
            sourceReference: "MSD cardiovascular/anesthetic pharmacology.", notes: "HR/GI effects Prescription veterinary workflow Research preload rule: 0.005–0.01 mg/kg IV/IM/SC",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "glycopyrrolate-cat-1", generic: "Glycopyrrolate", species: .cat,
            label: "0.005–0.01 mg/kg IV/IM/SC", doseBasis: .mgKg, minDose: 0.005, maxDose: 0.01,
            frequency: "to effect", route: "IV/IM/SC", strengths: [], concentration: 0.2,
            sourceReference: "MSD cardiovascular/anesthetic pharmacology.", notes: "HR/GI effects Prescription veterinary workflow Research preload rule: 0.005–0.01 mg/kg IV/IM/SC",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lidocaine-dog-1", generic: "Lidocaine", species: .dog,
            label: "Ventricular arrhythmia loading dose", doseBasis: .mgKg, minDose: 2, maxDose: 2,
            frequency: "once", route: "IV", strengths: [], concentration: 20.0,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Cats more CNS/CV sensitive Cat/dog rules differ; branch lock essential Research preload rule: Dog 2 mg/kg IV + 25–80 mcg/kg/min; lower feline branch; local-block branch",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "lidocaine-dog-2", generic: "Lidocaine", species: .dog,
            label: "Antiarrhythmic CRI", doseBasis: .mcgKgMin, minDose: 25, maxDose: 80,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 20.0,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "20 mg/mL injectable concentration is stored/displayed as mg/mL. VetPilot converts the mcg/kg/min dose rate to mg before calculating mL/hr. Cats are more sensitive to CNS effects; use the species-specific branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "lidocaine-cat-1", generic: "Lidocaine", species: .cat,
            label: "Feline loading dose", doseBasis: .mgKg, minDose: 0.1, maxDose: 0.4,
            frequency: "once", route: "IV", strengths: [], concentration: 20.0,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "Cats more CNS/CV sensitive Cat/dog rules differ; branch lock essential Research preload rule: Dog 2 mg/kg IV + 25–80 mcg/kg/min; lower feline branch; local-block branch",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "lidocaine-cat-2", generic: "Lidocaine", species: .cat,
            label: "Feline CRI", doseBasis: .mcgKgMin, minDose: 10, maxDose: 20,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 20.0,
            sourceReference: "MSD Veterinary Manual Cardiac Medications of Dogs and Cats.", notes: "20 mg/mL injectable concentration is stored/displayed as mg/mL. VetPilot converts the mcg/kg/min dose rate to mg before calculating mL/hr. Cats are more sensitive to CNS effects; use the species-specific branch.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "naloxone-dog-1", generic: "Naloxone", species: .dog,
            label: "0.04 mg/kg IV/IO emergency reversal; lower titration branch available", doseBasis: .mgKg, minDose: 0.04, maxDose: 0.04,
            frequency: "once immediately for RECOVER opioid-associated emergency; reassess", route: "IV/IO", strengths: [], concentration: 1.0,
            sourceReference: "2024 RECOVER consensus.", notes: "RECOVER opioid-associated arrest/periarrest branch: 0.04 mg/kg IV/IO after/with priority resuscitation interventions. For non-CPR toxicosis, use a separate indication-specific reversal protocol.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "naloxone-cat-1", generic: "Naloxone", species: .cat,
            label: "0.04 mg/kg IV/IO emergency reversal; lower titration branch available", doseBasis: .mgKg, minDose: 0.04, maxDose: 0.04,
            frequency: "once immediately for RECOVER opioid-associated emergency; reassess", route: "IV/IO", strengths: [], concentration: 1.0,
            sourceReference: "2024 RECOVER consensus.", notes: "RECOVER opioid-associated arrest/periarrest branch: 0.04 mg/kg IV/IO after/with priority resuscitation interventions. For non-CPR toxicosis, use a separate indication-specific reversal protocol.",
            confidence: "High", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "mannitol-dog-1", generic: "Mannitol", species: .dog,
            label: "Intracranial/cerebral edema — 20% mannitol (200 mg/mL)", doseBasis: .gKg, minDose: 0.5, maxDose: 1.0,
            frequency: "single IV bolus over ~20 min; reassess before repeat", route: "IV infusion", strengths: [], concentration: 200.0,
            sourceReference: "MSD Veterinary Manual — small-animal cerebral edema guidance.", notes: "20% mannitol = 200 mg/mL. Monitor hydration, renal function, serum osmolality/electrolytes and volume status; do not automatically repeat without reassessment.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "mannitol-dog-2", generic: "Mannitol", species: .dog,
            label: "Acute glaucoma — 20% mannitol (200 mg/mL)", doseBasis: .gKg, minDose: 1.0, maxDose: 1.5,
            frequency: "single IV infusion over 20–30 min; ophthalmic reassessment", route: "IV infusion", strengths: [], concentration: 200.0,
            sourceReference: "MSD Veterinary Manual — Treatment of Glaucoma in Animals.", notes: "20% mannitol = 200 mg/mL. Monitor hydration, renal function and volume status; ophthalmic emergency protocol required.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "mannitol-cat-1", generic: "Mannitol", species: .cat,
            label: "Intracranial/cerebral edema — 20% mannitol (200 mg/mL)", doseBasis: .gKg, minDose: 0.5, maxDose: 1.0,
            frequency: "single IV bolus over ~20 min; reassess before repeat", route: "IV infusion", strengths: [], concentration: 200.0,
            sourceReference: "MSD Veterinary Manual — small-animal cerebral edema guidance.", notes: "20% mannitol = 200 mg/mL. Monitor hydration, renal function, serum osmolality/electrolytes and volume status; do not automatically repeat without reassessment.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "mannitol-cat-2", generic: "Mannitol", species: .cat,
            label: "Acute glaucoma — 20% mannitol (200 mg/mL)", doseBasis: .gKg, minDose: 1.0, maxDose: 1.5,
            frequency: "single IV infusion over 20–30 min; ophthalmic reassessment", route: "IV infusion", strengths: [], concentration: 200.0,
            sourceReference: "MSD Veterinary Manual — Treatment of Glaucoma in Animals.", notes: "20% mannitol = 200 mg/mL. Monitor hydration, renal function and volume status; ophthalmic emergency protocol required.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "calcium-gluconate-dog-1", generic: "Calcium gluconate", species: .dog,
            label: "Life-threatening hyperkalemia — 10% calcium gluconate (100 mg/mL)", doseBasis: .mLKg, minDose: 0.5, maxDose: 1.5,
            frequency: "once, slow IV over 15–30 min with continuous ECG; reassess", route: "slow IV", strengths: [], concentration: 100.0,
            sourceReference: "MSD Veterinary Manual — Urethral Obstruction/Obstructive Uropathy in Dogs and Cats.", notes: "Dose is mL/kg of 10% calcium gluconate; 10% solution contains 100 mg/mL calcium gluconate salt (about 9.3 mg/mL elemental calcium). Protects myocardium but does not lower serum potassium. Stop/slow for ECG abnormalities or bradycardia; avoid extravasation.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "calcium-gluconate-cat-1", generic: "Calcium gluconate", species: .cat,
            label: "Life-threatening hyperkalemia — 10% calcium gluconate (100 mg/mL)", doseBasis: .mLKg, minDose: 0.5, maxDose: 1.5,
            frequency: "once, slow IV over 15–30 min with continuous ECG; reassess", route: "slow IV", strengths: [], concentration: 100.0,
            sourceReference: "MSD Veterinary Manual — Urethral Obstruction/Obstructive Uropathy in Dogs and Cats.", notes: "Dose is mL/kg of 10% calcium gluconate; 10% solution contains 100 mg/mL calcium gluconate salt (about 9.3 mg/mL elemental calcium). Protects myocardium but does not lower serum potassium. Stop/slow for ECG abnormalities or bradycardia; avoid extravasation.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dextrose-dog-1", generic: "Dextrose", species: .dog,
            label: "Emergency hypoglycemia — D50 (500 mg/mL), dilute before IV use", doseBasis: .gKg, minDose: 0.25, maxDose: 0.5,
            frequency: "slow IV over ~10 min as needed to reverse clinical signs; monitor glucose", route: "slow IV", strengths: [], concentration: 500.0,
            sourceReference: "MSD Veterinary Manual — emergency treatment of hypoglycemic crisis.", notes: "50% dextrose = 500 mg/mL. This dose equals 0.5–1 mL/kg of D50 before dilution. Dilute (eg, 1:3 with saline in the cited hypoglycemia protocol) and monitor glucose; avoid excessive boluses/rebound hypoglycemia.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "dextrose-cat-1", generic: "Dextrose", species: .cat,
            label: "Severe hyperkalemia adjunct — D50 (500 mg/mL), dilute 1:4", doseBasis: .gKg, minDose: 0.25, maxDose: 0.5,
            frequency: "single slow IV dose; serial glucose/potassium monitoring", route: "slow IV", strengths: [], concentration: 500.0,
            sourceReference: "MSD Veterinary Manual — Urethral Obstruction in Small Animals.", notes: "50% dextrose = 500 mg/mL. 0.25–0.5 g/kg equals 0.5–1 mL/kg D50 before dilution; cited hyperkalemia protocol dilutes 1:4 in saline. If insulin is selected, calculate insulin separately and monitor glucose closely.",
            confidence: "High for selected indication", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "potassium-chloride-dog-1", generic: "Potassium chloride", species: .dog,
            label: "0.05–0.5 mEq/kg/h IV, serum-K guided; never IV bolus", doseBasis: .mEqKgHr, minDose: 0.05, maxDose: 0.5,
            frequency: "continuous; serum-K guided", route: "IV infusion", strengths: [], concentration: nil,
            sourceReference: "Veterinary critical-care electrolyte protocol", notes: "Never IV push; infusion hard-limit High-alert electrolyte; hard rate limits + double check Research preload rule: 0.05–0.5 mEq/kg/h IV, serum-K guided; **never IV bolus**",
            confidence: "High for arithmetic", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "potassium-chloride-cat-1", generic: "Potassium chloride", species: .cat,
            label: "0.05–0.5 mEq/kg/h IV, serum-K guided; never IV bolus", doseBasis: .mEqKgHr, minDose: 0.05, maxDose: 0.5,
            frequency: "continuous; serum-K guided", route: "IV infusion", strengths: [], concentration: nil,
            sourceReference: "Veterinary critical-care electrolyte protocol", notes: "Never IV push; infusion hard-limit High-alert electrolyte; hard rate limits + double check Research preload rule: 0.05–0.5 mEq/kg/h IV, serum-K guided; **never IV bolus**",
            confidence: "High for arithmetic", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "fenbendazole-dog-1", generic: "Fenbendazole", species: .dog,
            label: "50 mg/kg q24h ×3; some dog labels 100 mg/kg once — 50 mg/kg branch", doseBasis: .mgKg, minDose: 50.0, maxDose: 50.0,
            frequency: "q24h, once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Parasite/product-specific Label vs extra-label duration varies Research preload rule: 50 mg/kg q24h for common GI parasite courses; parasite-specific branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "fenbendazole-dog-2", generic: "Fenbendazole", species: .dog,
            label: "50 mg/kg q24h ×3; some dog labels 100 mg/kg once — 100 mg/kg branch", doseBasis: .mgKg, minDose: 100.0, maxDose: 100.0,
            frequency: "q24h, once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Parasite/product-specific Label vs extra-label duration varies Research preload rule: 50 mg/kg q24h for common GI parasite courses; parasite-specific branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "fenbendazole-cat-1", generic: "Fenbendazole", species: .cat,
            label: "50 mg/kg q24h ×3 described for selected feline infections", doseBasis: .mgKg, minDose: 50.0, maxDose: 50.0,
            frequency: "q24h", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Parasite/product-specific Label vs extra-label duration varies Research preload rule: 50 mg/kg q24h for common GI parasite courses; parasite-specific branches",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "pyrantel-pamoate-dog-1", generic: "Pyrantel pamoate", species: .dog,
            label: "Common canine pyrantel-base dose", doseBasis: .mgKg, minDose: 5, maxDose: 5,
            frequency: "once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Must distinguish base vs pamoate/embonate Product concentration/dose-expression validation Research preload rule: About 5 mg/kg **pyrantel base** for common cat protocol; canine label branch",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "pyrantel-pamoate-cat-1", generic: "Pyrantel pamoate", species: .cat,
            label: "Common feline pyrantel-base dose", doseBasis: .mgKg, minDose: 5, maxDose: 5,
            frequency: "once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Must distinguish base vs pamoate/embonate Product concentration/dose-expression validation Research preload rule: About 5 mg/kg **pyrantel base** for common cat protocol; canine label branch",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "praziquantel-dog-1", generic: "Praziquantel", species: .dog,
            label: "Common cestode treatment", doseBasis: .mgKg, minDose: 5, maxDose: 12.5,
            frequency: "once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Product/parasite specificity Product/combination-product label matters Research preload rule: Dog 5–12.5; cat 4.6–10 mg/kg once for common cestodes",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "praziquantel-cat-1", generic: "Praziquantel", species: .cat,
            label: "Common cestode treatment", doseBasis: .mgKg, minDose: 4.6, maxDose: 10,
            frequency: "once", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology.", notes: "Product/parasite specificity Product/combination-product label matters Research preload rule: Dog 5–12.5; cat 4.6–10 mg/kg once for common cestodes",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "ivermectin-dog-1", generic: "Ivermectin", species: .dog,
            label: "Selected parasite treatment - ABCB1 screening required", doseBasis: .mgKg, minDose: 0.2, maxDose: 0.3,
            frequency: "per parasite protocol", route: "PO/SC", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology; high-dose use requires special caution.", notes: "ABCB1/MDR1 toxicity concern; never generic-dose across indications High-dose extra-label branch needs genetic/risk warning Research preload rule: Preventive microdose branch separate from high-dose parasite branch; ABCB1 hard stop",
            confidence: "Moderate-high", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "ivermectin-cat-1", generic: "Ivermectin", species: .cat,
            label: "Selected feline preventive/parasite branch", doseBasis: .mgKg, minDose: 0.024, maxDose: 0.024,
            frequency: "q30d", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD parasitology; high-dose use requires special caution.", notes: "ABCB1/MDR1 toxicity concern; never generic-dose across indications High-dose extra-label branch needs genetic/risk warning Research preload rule: Preventive microdose branch separate from high-dose parasite branch; ABCB1 hard stop",
            confidence: "Moderate-high", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "milbemycin-oxime-dog-1", generic: "Milbemycin oxime", species: .dog,
            label: "~0.5 mg/kg floor in cited monthly combo", doseBasis: .mgKg, minDose: 0.5, maxDose: 0.5,
            frequency: "monthly", route: "PO", strengths: [], concentration: nil,
            sourceReference: "MSD US-approved helminth table.", notes: "Exact product label preferred Product/combination SKU matters Research preload rule: ≥0.5 mg/kg/weight-band monthly",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "selamectin-dog-1", generic: "Selamectin", species: .dog,
            label: "6 mg/kg monthly", doseBasis: .mgKg, minDose: 6.0, maxDose: 6.0,
            frequency: "monthly", route: "Topical", strengths: [], concentration: nil,
            sourceReference: "MSD feline antiparasitic guidance.", notes: "Species/age/product label Dog and cat products/bands differ Research preload rule: 6 mg/kg topical q30d",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "selamectin-cat-1", generic: "Selamectin", species: .cat,
            label: "6 mg/kg monthly", doseBasis: .mgKg, minDose: 6.0, maxDose: 6.0,
            frequency: "monthly", route: "Topical", strengths: [], concentration: nil,
            sourceReference: "MSD feline antiparasitic guidance.", notes: "Species/age/product label Dog and cat products/bands differ Research preload rule: 6 mg/kg topical q30d",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "moxidectin-dog-1", generic: "Moxidectin", species: .dog,
            label: "Canine topical minimum", doseBasis: .mgKg, minDose: 2.5, maxDose: 2.5,
            frequency: "per labeled product interval", route: "Topical", strengths: [], concentration: nil,
            sourceReference: "MSD antiparasitic tables.", notes: "Exact product essential Multiple formulations/routes make generic auto-dose unsafe Research preload rule: Cat topical 1 mg/kg; dog topical 2.5 mg/kg; long-acting canine injectable branches",
            confidence: "High when product selected", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "moxidectin-cat-1", generic: "Moxidectin", species: .cat,
            label: "Feline topical minimum", doseBasis: .mgKg, minDose: 1, maxDose: 1,
            frequency: "per labeled product interval", route: "Topical", strengths: [], concentration: nil,
            sourceReference: "MSD antiparasitic tables.", notes: "Exact product essential Multiple formulations/routes make generic auto-dose unsafe Research preload rule: Cat topical 1 mg/kg; dog topical 2.5 mg/kg; long-acting canine injectable branches",
            confidence: "High when product selected", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "afoxolaner-dog-1", generic: "Afoxolaner", species: .dog,
            label: "Label weight-band delivering ≥~2.5 mg/kg q30d", doseBasis: .mgKg, minDose: 2.5, maxDose: 2.5,
            frequency: "q30d", route: "PO chewable", strengths: [], concentration: nil,
            sourceReference: "Veterinary product-label based template; isoxazoline neurologic warning retained", notes: "Isoxazoline neurologic warning/product rules Isoxazoline neurologic warning/product label Research preload rule: Label weight-band delivering ≥~2.5 mg/kg q30d",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "fluralaner-dog-1", generic: "Fluralaner", species: .dog,
            label: "Canine oral minimum exposure", doseBasis: .mgKg, minDose: 25, maxDose: 25,
            frequency: "per product label interval", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Product-label/parasite references", notes: "Dog/cat products and intervals differ Formulation + species + interval differ Research preload rule: Dog oral ≥25 mg/kg; cat topical ≥40 mg/kg; formulation/interval selector",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "fluralaner-cat-1", generic: "Fluralaner", species: .cat,
            label: "Feline topical minimum exposure", doseBasis: .mgKg, minDose: 40, maxDose: 40,
            frequency: "per product label interval", route: "Topical", strengths: [], concentration: nil,
            sourceReference: "Product-label/parasite references", notes: "Dog/cat products and intervals differ Formulation + species + interval differ Research preload rule: Dog oral ≥25 mg/kg; cat topical ≥40 mg/kg; formulation/interval selector",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "sarolaner-dog-1", generic: "Sarolaner", species: .dog,
            label: "≥2 mg/kg via weight-band q30d", doseBasis: .mgKg, minDose: 2.0, maxDose: 2.0,
            frequency: "q30d", route: "PO chewable", strengths: [], concentration: nil,
            sourceReference: "Product-label based template", notes: "Product-specific Do not substitute Simparica Trio tables Research preload rule: ≥2 mg/kg via weight-band q30d",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lotilaner-dog-1", generic: "Lotilaner", species: .dog,
            label: "Canine minimum exposure", doseBasis: .mgKg, minDose: 20, maxDose: 20,
            frequency: "q30d", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Current Elanco feline label gives 12 mg for 2–4 lb and 48 mg for 4.1–17 lb cats.", notes: "Never interchange dog/cat rules Dog/cat bands differ Research preload rule: Dog ≥20 mg/kg; cat ≥6 mg/kg, q30d with food",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "lotilaner-cat-1", generic: "Lotilaner", species: .cat,
            label: "Feline minimum exposure", doseBasis: .mgKg, minDose: 6, maxDose: 6,
            frequency: "q30d with food", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Current Elanco feline label gives 12 mg for 2–4 lb and 48 mg for 4.1–17 lb cats.", notes: "Never interchange dog/cat rules Dog/cat bands differ Research preload rule: Dog ≥20 mg/kg; cat ≥6 mg/kg, q30d with food",
            confidence: "High", highRisk: false
        ),
        BuiltInProtocolPreset(
            id: "toceranib-phosphate-dog-1", generic: "Toceranib phosphate", species: .dog,
            label: "PALLADIA FDA-label initial dose — 3.25 mg/kg PO q48h", doseBasis: .mgKg, minDose: 3.25, maxDose: 3.25,
            frequency: "q48h (every other day)", route: "PO", strengths: [10, 15, 50], concentration: nil,
            sourceReference: "FDA PALLADIA (toceranib phosphate) labeling, NADA 141-295.", notes: "Do not split tablets. Label permits dose interruptions and reductions in 0.5 mg/kg steps down to 2.2 mg/kg q48h to manage adverse reactions; use the FDA weight/tablet chart and oncology monitoring rather than freehand tablet rounding.",
            confidence: "FDA-labeled canine protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "toceranib-phosphate-dog-2", generic: "Toceranib phosphate", species: .dog,
            label: "PALLADIA FDA-label minimum reduced dose — 2.2 mg/kg PO q48h", doseBasis: .mgKg, minDose: 2.2, maxDose: 2.2,
            frequency: "q48h (every other day)", route: "PO", strengths: [10, 15, 50], concentration: nil,
            sourceReference: "FDA PALLADIA (toceranib phosphate) labeling, NADA 141-295.", notes: "This is the label-described minimum reduced dose, not an automatic titration target. Dose reduction/interruption must be selected by the treating veterinarian based on toxicity/response; do not split tablets.",
            confidence: "FDA-labeled canine dose-reduction floor", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "chlorambucil-dog-1", generic: "Chlorambucil", species: .dog,
            label: "GI inflammatory protocol — 2 mg/m² PO q48h", doseBasis: .mgM2, minDose: 2.0, maxDose: 2.0,
            frequency: "q48h", route: "PO", strengths: [2], concentration: nil,
            sourceReference: "MSD Veterinary Manual — Drugs Used for Inflammatory Bowel Disease.", notes: "Cytotoxic handling and CBC monitoring required; this selector is for the cited GI protocol and is not a universal oncology dose.",
            confidence: "High for selected GI protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "chlorambucil-cat-1", generic: "Chlorambucil", species: .cat,
            label: "GI inflammatory protocol — 2 mg/m² PO q48h", doseBasis: .mgM2, minDose: 2.0, maxDose: 2.0,
            frequency: "q48h", route: "PO", strengths: [2], concentration: nil,
            sourceReference: "MSD Veterinary Manual — Drugs Used for Inflammatory Bowel Disease.", notes: "Cytotoxic handling and CBC monitoring required; this selector is for the cited GI protocol and is not a universal oncology dose.",
            confidence: "High for selected GI protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "chlorambucil-cat-2", generic: "Chlorambucil", species: .cat,
            label: "Feline low-grade GI/cholangitis protocol — 2 mg/cat PO q48–72h", doseBasis: .fixedMg, minDose: 2.0, maxDose: 2.0,
            frequency: "q48–72h", route: "PO", strengths: [2], concentration: nil,
            sourceReference: "MSD Veterinary Manual — feline colitis/cholangitis and GI lymphoma guidance.", notes: "Cytotoxic handling and CBC monitoring required. Other feline lymphoma schedules exist; choose the disease-specific oncology protocol rather than interchanging schedules.",
            confidence: "High for selected feline protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "cyclophosphamide-dog-1", generic: "Cyclophosphamide", species: .dog,
            label: "Pulse oncology protocol — 200–250 mg/m²", doseBasis: .mgM2, minDose: 200.0, maxDose: 250.0,
            frequency: "protocol-specific cycle; oncologist selection required", route: "PO/IV — protocol-specific", strengths: [], concentration: nil,
            sourceReference: "Veterinary oncology protocol literature; MSD documents 200–250 mg/m² rescue schedules in GI lymphoma.", notes: "Do not infer a cycle from the dose alone. CBC, urinalysis/cystitis monitoring, hydration and protocol-specific handling required; sterile hemorrhagic cystitis requires discontinuation.",
            confidence: "Moderate-high; protocol-specific", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "cyclophosphamide-dog-2", generic: "Cyclophosphamide", species: .dog,
            label: "Metronomic oncology protocol — 10–15 mg/m²", doseBasis: .mgM2, minDose: 10.0, maxDose: 15.0,
            frequency: "short-interval continuous protocol; exact schedule must be selected by oncologist", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary metronomic oncology literature; MSD describes metronomic chemotherapy as low-dose oral therapy at short intervals, often daily.", notes: "The app calculates the selected mg/m² amount but does not choose the schedule. CBC/urinalysis and hemorrhagic-cystitis monitoring are mandatory.",
            confidence: "Moderate; clinic oncology protocol confirmation required", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "cyclophosphamide-cat-1", generic: "Cyclophosphamide", species: .cat,
            label: "Refractory GI lymphoma rescue — 200–250 mg/m²", doseBasis: .mgM2, minDose: 200.0, maxDose: 250.0,
            frequency: "administered over 2 days on days 1 and 3, q2wk in cited rescue protocol", route: "IV or PO", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual — Gastrointestinal Neoplasia in Dogs and Cats.", notes: "Cited rescue protocol; not interchangeable with other lymphoma protocols. CBC, urine/cystitis and oncology monitoring required.",
            confidence: "High for selected rescue protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "cyclophosphamide-cat-2", generic: "Cyclophosphamide", species: .cat,
            label: "Metronomic oncology protocol — 10–15 mg/m²", doseBasis: .mgM2, minDose: 10.0, maxDose: 15.0,
            frequency: "short-interval continuous protocol; exact schedule must be selected by oncologist", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary metronomic oncology literature; MSD describes metronomic chemotherapy as low-dose oral therapy at short intervals, often daily.", notes: "The app calculates the selected mg/m² amount but does not choose the schedule. CBC/urinalysis and hemorrhagic-cystitis monitoring are mandatory.",
            confidence: "Moderate; clinic oncology protocol confirmation required", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "vincristine-dog-1", generic: "Vincristine", species: .dog,
            label: "Canine transmissible venereal tumor (TVT) — 0.025 mg/kg IV weekly", doseBasis: .mgKg, minDose: 0.025, maxDose: 0.025,
            frequency: "q7d; continue per cited TVT response protocol", route: "IV only", strengths: [], concentration: nil,
            sourceReference: "MSD Veterinary Manual — Canine Transmissible Venereal Tumor.", notes: "Vesicant; never intrathecal. Cited TVT protocol gives weekly IV treatment and commonly 5–7 doses, continuing 2 weeks beyond complete gross tumor resolution. CBC and extravasation precautions required.",
            confidence: "High for selected TVT protocol", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "vincristine-cat-1", generic: "Vincristine", species: .cat,
            label: "Feline multidrug oncology protocol — 0.5–0.75 mg/m² IV", doseBasis: .mgM2, minDose: 0.5, maxDose: 0.75,
            frequency: "protocol-specific cycle; oncologist selection required", route: "IV only", strengths: [], concentration: nil,
            sourceReference: "Veterinary feline lymphoma multidrug protocol literature; MSD confirms vincristine is an IV antineoplastic agent used for lymphoma/leukemia.", notes: "Vesicant; never intrathecal. Numeric range requires clinic/oncologist protocol confirmation before activation; CBC, neuro/GI and extravasation monitoring required.",
            confidence: "Moderate; clinic oncology protocol confirmation required", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "doxorubicin-dog-1", generic: "Doxorubicin", species: .dog,
            label: "Dogs >10 kg oncology protocol", doseBasis: .mgM2, minDose: 30, maxDose: 30,
            frequency: "q3wk protocol", route: "IV", strengths: [], concentration: 2.0,
            sourceReference: "MSD specifies these canine size-based rules and notes cumulative canine cardiotoxicity around a 180 mg/m² lifetime exposure ceiling.", notes: "Vesicant; cardiac/renal species-specific monitoring Cardiac/cumulative-dose and small-dog protocol issues Research preload rule: Dog >10 kg 30 mg/m²; ≤10 kg and cat ~1 mg/kg; q3wk protocol branch",
            confidence: "High for arithmetic", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "doxorubicin-dog-2", generic: "Doxorubicin", species: .dog,
            label: "Dogs <=10 kg small-patient protocol", doseBasis: .mgKg, minDose: 1, maxDose: 1,
            frequency: "q3wk protocol", route: "IV", strengths: [], concentration: 2.0,
            sourceReference: "MSD specifies these canine size-based rules and notes cumulative canine cardiotoxicity around a 180 mg/m² lifetime exposure ceiling.", notes: "Vesicant; cardiac/renal species-specific monitoring Cardiac/cumulative-dose and small-dog protocol issues Research preload rule: Dog >10 kg 30 mg/m²; ≤10 kg and cat ~1 mg/kg; q3wk protocol branch",
            confidence: "High for arithmetic", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "doxorubicin-cat-1", generic: "Doxorubicin", species: .cat,
            label: "Feline oncology protocol", doseBasis: .mgKg, minDose: 1, maxDose: 1,
            frequency: "q3wk protocol", route: "IV", strengths: [], concentration: 2.0,
            sourceReference: "MSD specifies these canine size-based rules and notes cumulative canine cardiotoxicity around a 180 mg/m² lifetime exposure ceiling.", notes: "Vesicant; cardiac/renal species-specific monitoring Cardiac/cumulative-dose and small-dog protocol issues Research preload rule: Dog >10 kg 30 mg/m²; ≤10 kg and cat ~1 mg/kg; q3wk protocol branch",
            confidence: "High for arithmetic", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "lomustine-dog-1", generic: "Lomustine", species: .dog,
            label: "Canine oncology protocol", doseBasis: .mgM2, minDose: 60, maxDose: 70,
            frequency: "protocol-specific interval", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary oncology secondary literature; Moderate confidence, mandatory oncology review", notes: "Delayed myelosuppression/hepatotoxicity Cytotoxic; hepatic/myelosuppression monitoring and protocol variation Research preload rule: Dog ~60–70 mg/m²; cat ~50–60 mg/m², protocol-specific interval",
            confidence: "Moderate-high", highRisk: true
        ),
        BuiltInProtocolPreset(
            id: "lomustine-cat-1", generic: "Lomustine", species: .cat,
            label: "Feline oncology protocol", doseBasis: .mgM2, minDose: 50, maxDose: 60,
            frequency: "protocol-specific interval", route: "PO", strengths: [], concentration: nil,
            sourceReference: "Veterinary oncology secondary literature; Moderate confidence, mandatory oncology review", notes: "Delayed myelosuppression/hepatotoxicity Cytotoxic; hepatic/myelosuppression monitoring and protocol variation Research preload rule: Dog ~60–70 mg/m²; cat ~50–60 mg/m², protocol-specific interval",
            confidence: "Moderate-high", highRisk: true
        ),
    ]

    static func presets(for medication: Medication, species: Species) -> [BuiltInProtocolPreset] {
        all.filter { $0.species == species && $0.generic.caseInsensitiveCompare(medication.generic) == .orderedSame }
    }

    static func hasPreset(for medication: Medication, species: Species) -> Bool {
        !presets(for: medication, species: species).isEmpty
    }

    static var coveredMedicationNames: Set<String> { Set(all.map(\.generic)) }
}

