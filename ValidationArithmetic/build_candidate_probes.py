from pathlib import Path
import re,shutil,json
root=Path(__file__).parent;r=root/'candidate';h=root/'candidate_harness'
view=(r/'FergusonVetPilot/DoseView.swift').read_text()
def block(pattern):
 m=re.search(pattern,view);assert m,pattern
 a=view.index('{',m.start());depth=1;i=a+1
 while depth:
  if view[i]=='{':depth+=1
  if view[i]=='}':depth-=1
  i+=1
 return view[m.start():i]
fields=['readableAdministrationSummary','readableAdministrationNote','requiresPrescribedPotassiumRate','prescribedRateInputError','numericWeight','weightInputError','activeStrengths','selectedStrength','activeConcentration','recommendedFrequency','activeRoute','activeFrequencyLabel','dosesPerDay','doseSelection','selectedSolidPlan','routeSupportsOralSolid','routeSupportsMeasuredVolume','solidUnitName','selectedAdministrationVolume','canPlanSupply','administrationSelection','requiresRibbonApplication','usesGalliprantChart','galliprantPlan','concentrationInputError','administrationReviewReason']
funcs=['administrationInstruction','volumeInstruction','supplySummary']
chunks=[block(r'private enum FrequencyChoice:')]+[block(r'private var '+f+r':') for f in fields]+[block(r'private func '+f+r'\(') for f in funcs]
head='''import Foundation
struct DoseSheetLogicProbe {
 var medication: Medication
 var protocolDefinition: ProtocolMedicationDefinition? = nil
 var selectedBuiltInPreset: BuiltInProtocolPreset? = nil
 var kg: Double = 10
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
 var patientWeightOverride: String? = nil
 var patientWeight: String { patientWeightOverride ?? MedicationSafety.input(patientWeightUnit == "lb" ? ClinicalData.kgToLb(kg) : kg) }
'''
(h/'DoseSheetLogicProbe.swift').write_text(head+'\n'.join(x.replace('private ','') for x in chunks)+'\n}\n')
s=(r/'FergusonVetPilot/ProtocolMedicationStore.swift').read_text()
(h/'ProtocolCore.swift').write_text('import Foundation\n'+s[s.index('enum ProtocolDoseBasis:'):s.index('@MainActor\nfinal class ProtocolMedicationStore')]+'\n'+s[s.index('enum ProtocolDoseCalculator {'):s.index('struct ProtocolMedicationEditorView:')])
c=(r/'FergusonVetPilot/CustomMedicationStore.swift').read_text()
(h/'CustomCore.swift').write_text('import Foundation\n'+c[c.index('enum CustomDoseBasis:'):c.index('@MainActor\nfinal class CustomMedicationStore')])
for f in ['ClinicalData.swift','AdministrationMath.swift','BuiltInProtocolCatalog.swift','NutritionMath.swift','MedicationSafety.swift']:shutil.copy2(r/'FergusonVetPilot'/f,h/f)
(root/'candidate-probe-extraction.json').write_text(json.dumps({'source':'candidate/FergusonVetPilot/DoseView.swift','properties':fields,'methods':funcs,'method':'Unchanged computed property and method bodies extracted into a plain struct. Removed private modifiers and substituted non-UI state fields. Not an iOS UI execution.'},indent=2))

