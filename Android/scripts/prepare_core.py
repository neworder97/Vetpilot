#!/usr/bin/env python3
"""Extract the exact iOS production engine; no equations are translated."""
from pathlib import Path
import re, shutil, hashlib, json
root=Path(__file__).resolve().parents[2]; src=root/'FergusonVetPilot'; dst=root/'Android/SwiftCore/Sources/VetPilotCore/Generated'
dst.mkdir(parents=True,exist_ok=True)
view=(src/'DoseView.swift').read_text()
def block(pattern):
 m=re.search(pattern,view); assert m,pattern
 a=view.index('{',m.start()); depth=1;i=a+1
 while depth:
  if view[i]=='{':depth+=1
  if view[i]=='}':depth-=1
  i+=1
 return view[m.start():i].replace('private ','')
fields=['readableAdministrationSummary','readableAdministrationNote','requiresPrescribedPotassiumRate','prescribedRateInputError','numericWeight','weightInputError','activeStrengths','selectedStrength','activeConcentration','recommendedFrequency','activeRoute','activeFrequencyLabel','dosesPerDay','doseSelection','selectedSolidPlan','routeSupportsOralSolid','routeSupportsMeasuredVolume','solidUnitName','selectedAdministrationVolume','canPlanSupply','administrationSelection','requiresRibbonApplication','usesGalliprantChart','galliprantPlan','concentrationInputError','administrationReviewReason','kg']
head='''import Foundation
struct DoseLogic {
 var medication: Medication
 var protocolDefinition: ProtocolMedicationDefinition? = nil
 var selectedBuiltInPreset: BuiltInProtocolPreset? = nil
 var selectedStrengthIndex = 0
 var concentration = ""
 var infusionConcentrationConfirmed = false
 var prescribedPotassiumRate = ""
 var selectedFrequency: FrequencyChoice = .recommended
 var selectedDoseLevel: DoseSelectionLevel = .middle
 var solidRounding: SolidDoseRounding = .nearest
 var priorCourseDoses = 0
 var priorCourseHistoryConfirmed = false
 var patientWeightUnit = "kg"
 var patientWeight = ""
'''
chunks=[block(r'private enum FrequencyChoice:')]+[block(r'private var '+f+r':') for f in fields]+[block(r'private func '+f+r'\(') for f in ['administrationInstruction','volumeInstruction','supplySummary']]
(dst/'DoseLogic.swift').write_text(head+'\n'.join(chunks)+'\n}\n')
s=(src/'ProtocolMedicationStore.swift').read_text()
(dst/'ProtocolCore.swift').write_text('import Foundation\n'+s[s.index('enum ProtocolDoseBasis:'):s.index('@MainActor\nfinal class ProtocolMedicationStore')]+'\n'+s[s.index('enum ProtocolDoseCalculator {'):s.index('struct ProtocolMedicationEditorView:')])
c=(src/'CustomMedicationStore.swift').read_text()
(dst/'CustomCore.swift').write_text('import Foundation\n'+c[c.index('enum CustomDoseBasis:'):c.index('@MainActor\nfinal class CustomMedicationStore')])
files=['ClinicalData.swift','AdministrationMath.swift','BuiltInProtocolCatalog.swift','NutritionMath.swift','MedicationSafety.swift','LabworkCatalog.swift','ClinicProtocol.swift']
for f in files:shutil.copy2(src/f,dst/f)
manifest={f:hashlib.sha256((src/f).read_bytes()).hexdigest() for f in files+['DoseView.swift','ProtocolMedicationStore.swift','CustomMedicationStore.swift']}
(root/'Android/core-source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Prepared unchanged iOS calculation bodies and catalogs')
