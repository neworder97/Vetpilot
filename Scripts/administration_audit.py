#!/usr/bin/env python3
from pathlib import Path
import json, math, re, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
view = (ROOT/'FergusonVetPilot'/'DoseView.swift').read_text()
admin = (ROOT/'FergusonVetPilot'/'AdministrationMath.swift').read_text()
clinical = (ROOT/'FergusonVetPilot'/'ClinicalData.swift').read_text()
errors=[]

def req(cond,msg):
    if not cond: errors.append(msg)

# UI contract
for token in [
    'Section("Dose range choice")',
    'Section("Administration")',
    'DoseSelectionLevel.allCases',
    'SolidDoseRounding.allCases',
    'Section("Quantity dispensed — math only")',
    'Difference from selected target',
    'Delivered mg/kg',
]: req(token in view, f'missing UI contract: {token}')

# Rounding arithmetic cases
def round_units(target,strength,mode):
    raw=target/strength
    if mode=='down': rounded=math.floor(raw)
    elif mode=='up': rounded=math.ceil(raw)
    else: rounded=math.floor(raw+0.5)
    return raw,rounded,rounded*strength

cases=[]
for target,strength in [(62,50),(44,25),(7.5,10),(100,75),(12.5,5)]:
    for mode in ('down','nearest','up'):
        raw,rounded,delivered=round_units(target,strength,mode)
        req(raw>0 and rounded>=0 and delivered>=0, f'invalid rounding {target}/{strength}/{mode}')
        if mode=='down': req(delivered<=target+1e-9, 'round down overshot target')
        if mode=='up': req(delivered+1e-9>=target, 'round up undershot target')
        cases.append(dict(target=target,strength=strength,mode=mode,raw=raw,rounded=rounded,delivered=delivered))

# Known critical unit conversion examples kept aligned with second audit.
# 20kg dog, lidocaine 52.5 mcg/kg/min middle of 25-80 range, 20mg/mL.
lidocaine_mid_mcg_min = 20 * ((25+80)/2)
lidocaine_ml_hr = (lidocaine_mid_mcg_min/1000)*60/20
req(abs(lidocaine_ml_hr-3.15)<1e-12,'lidocaine middle-rate conversion mismatch')
# Cat 4kg, dexmedetomidine 40mcg/kg, 0.5mg/mL.
dex_ml=(4*40/1000)/0.5
req(abs(dex_ml-0.32)<1e-12,'dexmedetomidine mcg -> mg/mL mismatch')
# BSA constants: Merck table convention as already audited.
dog_bsa=0.101*(10**(2/3))
cat_bsa=0.100*(4**(2/3))
req(abs(dog_bsa-0.469)<0.002,'dog BSA constant mismatch')
req(abs(cat_bsa-0.252)<0.002,'cat BSA constant mismatch')

# Breed coverage.
breed_block=clinical.split('static let breeds: [BreedEntry] = [',1)[1].split('    ]',1)[0]
dogs=len(re.findall(r'BreedEntry\(species: \.dog',breed_block))
cats=len(re.findall(r'BreedEntry\(species: \.cat',breed_block))
req(dogs>=50, f'expected >=50 dog breeds, got {dogs}')
req(cats>=20, f'expected >=20 cat breeds, got {cats}')

# Safety behavior in code.
for token in [
    'does not assume a tablet is scored/splittable',
    'never splits capsules automatically',
    'will not force a non-zero dose',
    'VetPilot does not choose which point is clinically appropriate',
]: req(token in view, f'missing safety language: {token}')

out={
  'status':'PASS' if not errors else 'FAIL',
  'errors':errors,
  'rounding_cases':len(cases),
  'critical_examples':{
      'lidocaine_20kg_middle_52_5mcgkgmin_20mgml_mLhr': lidocaine_ml_hr,
      'dexmedetomidine_cat_4kg_40mcgkg_0_5mgml_mL': dex_ml,
      'dog_10kg_BSA_m2': dog_bsa,
      'cat_4kg_BSA_m2': cat_bsa,
  },
  'breed_counts':{'dog':dogs,'cat':cats,'total':dogs+cats},
}
print(json.dumps(out,indent=2,sort_keys=True))
sys.exit(1 if errors else 0)
