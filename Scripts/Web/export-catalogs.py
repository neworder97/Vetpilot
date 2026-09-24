#!/usr/bin/env python3
"""Export current Swift catalogs without retyping clinical content. Requires swiftc."""
from pathlib import Path
import argparse, subprocess, tempfile, shutil
p=argparse.ArgumentParser(); p.add_argument('output'); a=p.parse_args()
root=Path(__file__).resolve().parents[2]; source=root/'FergusonVetPilot'
with tempfile.TemporaryDirectory() as directory:
 t=Path(directory)
 s=(source/'ProtocolMedicationStore.swift').read_text()
 (t/'ProtocolCore.swift').write_text('import Foundation\n'+s[s.index('enum ProtocolDoseBasis:'):s.index('@MainActor\nfinal class ProtocolMedicationStore')]+'\n'+s[s.index('enum ProtocolDoseCalculator {'):s.index('struct ProtocolMedicationEditorView:')])
 for name in ['ClinicalData','MedicationSafety','AdministrationMath','BuiltInProtocolCatalog','LabworkCatalog']:
  shutil.copy2(source/(name+'.swift'),t/(name+'.swift'))
 (t/'main.swift').write_text('''import Foundation
let medications: [[String: Any]] = ClinicalData.medications.map { m in
 ["generic": m.generic, "brand": m.brand, "drugClass": m.drugClass, "species": m.species.map(\\.rawValue).sorted(), "form": m.form.rawValue, "indication": m.indication, "kind": String(describing: m.kind), "minDose": m.minDose, "maxDose": m.maxDose, "frequency": m.frequency, "route": m.route, "notes": m.notes, "source": m.source, "strengths": m.strengths, "concentration": m.concentration as Any? ?? NSNull(), "controlled": m.controlled]
}
let protocols: [[String: Any]] = BuiltInProtocolCatalog.all.map { p in
 ["id": p.id, "generic": p.generic, "species": p.species.rawValue, "label": p.label, "doseBasis": p.doseBasis.rawValue, "minDose": p.minDose, "maxDose": p.maxDose, "frequency": p.frequency, "route": p.route, "strengths": p.strengths, "concentration": p.concentration as Any? ?? NSNull(), "source": p.sourceReference, "notes": p.notes, "confidence": p.confidence, "highRisk": p.highRisk]
}
let labs: [[String: Any]] = LabworkCatalog.tests.map { l in
 ["id": l.id, "provider": l.provider, "code": l.code, "name": l.name, "purpose": l.purpose, "species": l.species, "specimen": l.specimen, "amount": l.amount, "tube": l.tube, "preparation": LabworkCatalog.preparation(l.preparation), "handling": l.handling, "notes": l.notes, "source": l.source, "available": l.available, "components": l.components]
}
let breeds: [[String: Any]] = ClinicalData.breeds.map { b in ["species": b.species.rawValue, "name": b.name, "conditions": b.conditions, "note": b.note] }
let result: [String: Any] = ["medications": medications, "protocols": protocols, "labs": labs, "breeds": breeds, "labReviewed": LabworkCatalog.reviewed, "tubeNote": LabworkCatalog.tubeNote]
let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
FileHandle.standardOutput.write(data)
''')
 subprocess.run(['swiftc',*[str(f) for f in t.glob('*.swift')],'-o',str(t/'export')],check=True)
 output=Path(a.output); output.parent.mkdir(parents=True,exist_ok=True)
 with output.open('wb') as f: subprocess.run([str(t/'export')],stdout=f,check=True)
