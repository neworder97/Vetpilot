from pathlib import Path
import shutil,hashlib,json
r=Path(__file__).parent/'source'; h=r.parent/'harness'
s=(r/'FergusonVetPilot/ProtocolMedicationStore.swift').read_text()
prefix=s[s.index('enum ProtocolDoseBasis:'):s.index('@MainActor\nfinal class ProtocolMedicationStore')]
calc=s[s.index('enum ProtocolDoseCalculator {'):s.index('struct ProtocolMedicationEditorView:')]
(h/'ProtocolCore.swift').write_text('import Foundation\n'+prefix+'\n'+calc)
for f in ['ClinicalData.swift','AdministrationMath.swift','BuiltInProtocolCatalog.swift','NutritionMath.swift']:
 shutil.copy2(r/'FergusonVetPilot'/f,h/f)
meta={str(p.relative_to(r)):{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_blob_sha':hashlib.sha1(b'blob '+str(p.stat().st_size).encode()+b'\0'+p.read_bytes()).hexdigest()} for p in (r/'FergusonVetPilot').glob('*.swift')}
(r.parent/'source-hashes.json').write_text(json.dumps(meta,indent=2))
