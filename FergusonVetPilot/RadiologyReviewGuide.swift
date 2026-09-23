import Foundation

enum RadiologyReviewGuide {
    static func checklist(for region: String) -> [String] {
        let r = region.lowercased()

        if r.contains("thorax") || r.contains("chest") || r.contains("lung") {
            return [
                "Confirm patient, species, projection, laterality, positioning, exposure, and motion.",
                "Review trachea, bronchi, lung fields, and pulmonary pattern systematically.",
                "Assess cardiac silhouette size/shape and pulmonary vasculature.",
                "Review pleural space, mediastinum, diaphragm, and visible upper abdomen.",
                "Inspect ribs, spine, sternum, soft tissues, and any focal/multifocal opacity.",
                "Compare orthogonal views when available and correlate with history/exam."
            ]
        }

        if r.contains("abdomen") || r.contains("abdominal") || r.contains("gi") {
            return [
                "Confirm patient, species, projection, positioning, exposure, and motion.",
                "Assess serosal detail and distribution of abdominal gas/fluid.",
                "Review stomach, small bowel, and colon for caliber, content, displacement, or repeated dilation pattern.",
                "Review liver, spleen, kidneys, urinary bladder, and visible reproductive structures.",
                "Inspect for mass effect, organ displacement, mineral opacity, foreign material, or free gas.",
                "Review lumbar spine, pelvis, body wall, and correlate with orthogonal views/history."
            ]
        }

        if r.contains("neck") || r.contains("cervical") || r.contains("upper airway") || r.contains("skull") {
            return [
                "Confirm patient, species, projection, laterality, positioning, exposure, and motion.",
                "Trace the nasopharynx, laryngeal region, cervical trachea, and surrounding soft tissues.",
                "Assess airway caliber, symmetry, displacement, and abnormal soft-tissue/gas opacity.",
                "Review cervical vertebrae and visible thoracic inlet.",
                "Look for focal swelling, mineralization, mass effect, or foreign material.",
                "Correlate with respiratory signs, swallowing history, and additional views."
            ]
        }

        return [
            "Confirm patient, species, projection, laterality, positioning, exposure, and motion.",
            "Use a consistent anatomic search pattern and review every visible structure.",
            "Compare paired/orthogonal views when available.",
            "Look for asymmetry, mass effect, abnormal opacity, displacement, dilation, or loss of normal detail.",
            "Correlate all observations with clinical history and physical examination.",
            "Escalate uncertain or high-risk findings for veterinary/radiologist interpretation."
        ]
    }


}
