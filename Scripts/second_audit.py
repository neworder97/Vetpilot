#!/usr/bin/env python3
from pathlib import Path
import re, math, json, hashlib, sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
CATALOG = ROOT/'FergusonVetPilot'/'BuiltInProtocolCatalog.swift'
STORE = ROOT/'FergusonVetPilot'/'ProtocolMedicationStore.swift'
DOSEVIEW = ROOT/'FergusonVetPilot'/'DoseView.swift'
TESTS = ROOT/'FergusonVetPilotTests'/'MedicationPreloadTests.swift'

errors=[]; warnings=[]

def fail(msg): errors.append(msg)
def require(cond,msg):
    if not cond: fail(msg)

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

cat = CATALOG.read_text()
store = STORE.read_text()
view = DOSEVIEW.read_text()
tests = TESTS.read_text()

# Parse each constructor block. Catalog formatting intentionally keeps one preset per constructor.
chunks = cat.split('BuiltInProtocolPreset(')[1:]
rows=[]
for i,ch in enumerate(chunks,1):
    # terminate at the first constructor close at the same indentation; current catalog is flat.
    block = ch.split('\n        ),',1)[0]
    def sm(p, required=True):
        m=re.search(p,block,re.S)
        if not m:
            if required: fail(f'Preset #{i}: missing pattern {p}')
            return None
        return m.group(1)
    rid=sm(r'id:\s*"([^"]+)"')
    generic=sm(r'generic:\s*"([^"]+)"')
    species=sm(r'species:\s*\.(dog|cat)')
    basis=sm(r'doseBasis:\s*\.(\w+)')
    mn=sm(r'minDose:\s*([0-9.eE+\-]+)')
    mx=sm(r'maxDose:\s*([0-9.eE+\-]+)')
    freq=sm(r'frequency:\s*"([^"]*)"')
    route=sm(r'route:\s*"([^"]*)"')
    conc_raw=sm(r'concentration:\s*(nil|[0-9.eE+\-]+)')
    source=sm(r'sourceReference:\s*"([^"]*)"')
    notes=sm(r'notes:\s*"([^"]*)"')
    conf=sm(r'confidence:\s*"([^"]*)"')
    risk=sm(r'highRisk:\s*(true|false)')
    if None in (rid,generic,species,basis,mn,mx,freq,route,conc_raw,source,notes,conf,risk):
        continue
    row=dict(id=rid,generic=generic,species=species,basis=basis,min=float(mn),max=float(mx),
             frequency=freq,route=route,concentration=None if conc_raw=='nil' else float(conc_raw),
             source=source,notes=notes,confidence=conf,highRisk=(risk=='true'))
    rows.append(row)

require(len(rows)==len(chunks), f'Parsed {len(rows)} of {len(chunks)} presets')
require(len(rows)==307, f'Expected 307 audited presets, got {len(rows)}')
ids=[r['id'] for r in rows]; names={r['generic'] for r in rows}
require(len(ids)==len(set(ids)), 'Preset IDs must be unique')
require(len(names)==114, f'Expected 114 unique medications, got {len(names)}')

byid={r['id']:r for r in rows}
for r in rows:
    require(r['min']>0, f"{r['id']}: minDose must be >0")
    require(r['max']>=r['min'], f"{r['id']}: maxDose < minDose")
    require(bool(r['source'].strip()), f"{r['id']}: source reference is empty")
    require(bool(r['route'].strip()), f"{r['id']}: route is empty")
    require(bool(r['frequency'].strip()), f"{r['id']}: frequency is empty")
    require(bool(r['confidence'].strip()), f"{r['id']}: confidence is empty")

# UI/unit safety contract: mass concentrations use mg/mL; insulin uses units/mL; electrolytes use mEq/mL.
require('case .mgKg, .mgLb, .fixedMg, .mgKgHr, .mgM2, .mcgKg, .mcgKgMin, .gKg: return "mg/mL"' in store,
        'Mass-based concentration label must be mg/mL')
require('case .unitsKg, .fixedUnits: return "units/mL"' in store, 'Insulin concentration label must be units/mL')
require('case .mEqKg, .mEqKgHr: return "mEq/mL"' in store, 'Electrolyte concentration label must be mEq/mL')
require('Dose is mcg/min; concentration is deliberately entered as mg/mL.' in store, 'mcg/min -> mg/mL conversion safeguard missing')
require('Dose is mcg; concentration is mg/mL.' in store, 'mcg -> mg/mL conversion safeguard missing')
require('(low / 1000.0) * 60.0 / c' in store, 'mcg/kg/min to mL/hr conversion is not explicit')
require('(low / 1000.0) / c' in store, 'mcg/kg to mL conversion is not explicit')
require('(low * 1000.0) / c' in store, 'g/kg to mg/mL conversion is not explicit')
require('Section("Concentration (\\(concentrationUnit)) — verify product")' in view, 'Dose UI does not display concentration unit in header')
require('Enter the exact product concentration in \\(concentrationUnit).' in view, 'Dose UI does not explicitly require exact concentration units')
require('Section("Required product concentration (mg/mL)")' in view, 'Volume-based injectable protocols must show required mg/mL product concentration')

# Independent arithmetic evaluator mirroring the dose engine, run across small / typical / large patients.
def amounts(r,kg):
    mn,mx=r['min'],r['max']; b=r['basis']
    if b in ('fixedMg','fixedUnits','dropsEye'): return mn,mx
    if b=='mgLb':
        lb=kg*2.20462262185; return mn*lb,mx*lb
    if b=='mgM2':
        k=0.101 if r['species']=='dog' else 0.100
        bsa=k*(kg**(2/3)); return mn*bsa,mx*bsa
    # all remaining weight-normalized bases
    return mn*kg,mx*kg

def volume(r,lo,hi):
    c=r['concentration']
    if not c or c<=0: return None
    b=r['basis']
    if b=='mcgKgMin': return (lo/1000)*60/c,(hi/1000)*60/c
    if b=='mcgKg': return (lo/1000)/c,(hi/1000)/c
    if b=='gKg': return (lo*1000)/c,(hi*1000)/c
    if b in ('mLKg','dropsEye'): return None # dose already expressed as volume/drop
    return lo/c,hi/c

arith_cases=0
max_volume=0
for r in rows:
    weights = [2,20,60] if r['species']=='dog' else [1,4,8]
    if r['basis'] in ('fixedMg','fixedUnits','dropsEye'): weights=[0]
    for kg in weights:
        lo,hi=amounts(r,kg)
        arith_cases += 1
        require(all(math.isfinite(x) for x in (lo,hi)), f"{r['id']} @ {kg}kg produced non-finite amount")
        require(lo>0 and hi>=lo, f"{r['id']} @ {kg}kg produced invalid amount range {lo}..{hi}")
        v=volume(r,lo,hi)
        if v:
            require(all(math.isfinite(x) and x>0 for x in v), f"{r['id']} @ {kg}kg produced invalid volume {v}")
            max_volume=max(max_volume,*v)

# Critical clinical/unit assertions from the second source audit.
def exact(rid, basis=None, mn=None, mx=None, conc=None, frequency_contains=None, route_contains=None):
    r=byid.get(rid); require(r is not None, f'Missing critical preset {rid}')
    if not r: return
    if basis is not None: require(r['basis']==basis, f'{rid}: expected {basis}, got {r["basis"]}')
    if mn is not None: require(abs(r['min']-mn)<1e-9, f'{rid}: expected min {mn}, got {r["min"]}')
    if mx is not None: require(abs(r['max']-mx)<1e-9, f'{rid}: expected max {mx}, got {r["max"]}')
    if conc is not None: require(r['concentration'] is not None and abs(r['concentration']-conc)<1e-9, f'{rid}: expected concentration {conc}, got {r["concentration"]}')
    if frequency_contains is not None: require(frequency_contains.lower() in r['frequency'].lower(), f'{rid}: frequency missing {frequency_contains!r}: {r["frequency"]!r}')
    if route_contains is not None: require(route_contains.lower() in r['route'].lower(), f'{rid}: route missing {route_contains!r}')

exact('insulin-glargine-cat-1','fixedUnits',1,1,100,'q12h')
exact('insulin-pzi-cat-1','unitsKg',0.2,0.7,40,'q12h')
exact('insulin-pzi-cat-2','fixedUnits',1,1,40,'q12h')
exact('dexmedetomidine-dog-1','mgM2',0.375,0.375,0.5,'once','IV')
exact('dexmedetomidine-dog-2','mgM2',0.5,0.5,0.5,'once','IM')
exact('dexmedetomidine-cat-1','mcgKg',40,40,0.5,'once','IM')
exact('fentanyl-dog-1','mgKg',0.01,0.01,0.05)
exact('fentanyl-dog-2','mgKgHr',0.01,0.01,0.05,'continuous')
exact('fentanyl-cat-1','mgKg',0.01,0.01,0.05)
exact('fentanyl-cat-2','mgKgHr',0.01,0.01,0.05,'continuous')
exact('lidocaine-dog-2','mcgKgMin',25,80,20,'continuous')
exact('lidocaine-cat-2','mcgKgMin',10,20,20,'continuous')
exact('butorphanol-dog-2','mgKg',0.2,0.2,10,'once')
exact('mitotane-dog-2','mgKg',25,50,None,'per week')
exact('epinephrine-dog-1','mgKg',0.01,0.01,1,'q3–5 min')
exact('epinephrine-cat-1','mgKg',0.01,0.01,1,'q3–5 min')
exact('atropine-injection-dog-2','mgKg',0.04,0.04,None,'once')
exact('atropine-injection-cat-2','mgKg',0.04,0.04,None,'once')
exact('marbofloxacin-dog-1','mgKg',2.75,5.5,None,'q24h')
exact('marbofloxacin-cat-1','mgKg',2.75,5.5,None,'q24h')
exact('orbifloxacin-dog-1','mgKg',2.5,7.5,None,'q24h')
exact('orbifloxacin-dog-2','mgKg',7.5,7.5,None,'q24h')
exact('potassium-chloride-dog-1','mEqKgHr',0.05,0.5,None,'serum-K guided')
exact('potassium-chloride-cat-1','mEqKgHr',0.05,0.5,None,'serum-K guided')
for rid in ('potassium-chloride-dog-1','potassium-chloride-cat-1'):
    require('never iv' in byid[rid]['notes'].lower(), f'{rid}: missing never-IV-push safety note')

# Additional second-audit clinical metadata corrections.
exact('trimethoprim-sulfamethoxazole-dog-2','mgKg',30,45,None,'q12h','PO')
exact('trimethoprim-sulfamethoxazole-cat-1','mgKg',15,15,None,'q12h','PO')
exact('telmisartan-cat-1','mgKg',1.5,1.5,None,'q12h','PO')
exact('telmisartan-cat-2','mgKg',2,2,None,'q24h','PO')
exact('telmisartan-cat-3','mgKg',1,1,None,'q24h','PO')
exact('levothyroxine-dog-1','mgKg',0.022,0.022,None,'q24h','PO')
exact('levothyroxine-dog-2','mgKg',0.011,0.011,None,'q12h','PO')
exact('trilostane-dog-1','mgKg',2.2,6.7,None,'q24h','PO')
exact('desoxycorticosterone-pivalate-dog-1','mgKg',2.2,2.2,25,None,'SC')
exact('desmopressin-dog-1','mcgKg',0.3,1.0,None,'once','SC/IV')
exact('desmopressin-cat-1','mcgKg',0.3,1.0,None,'once','SC/IV')
exact('desmopressin-dog-2','fixedMg',0.1,0.2,None,'q8–12h','PO')
exact('desmopressin-cat-2','fixedMg',0.1,0.2,None,'q12h','PO')
exact('methocarbamol-dog-2','mgKg',44,44,None,'330 mg/kg/day','IV')
exact('methocarbamol-cat-2','mgKg',44,44,None,'330 mg/kg/day','IV')
exact('clomipramine-dog-1','mgKg',2,4,None,'q24h','PO')
exact('hydroxyzine-dog-1','mgKg',0.5,2,None,'q6–8h','PO/IV')
exact('hydroxyzine-cat-1','mgKg',0.5,2,None,'q6–8h','PO/IV')

# Indication selector presence checks.
def count_prefix(prefix): return sum(1 for r in rows if r['id'].startswith(prefix))
require(count_prefix('metronidazole-dog-')>=3 and count_prefix('metronidazole-cat-')>=2, 'Metronidazole indication-specific selector coverage incomplete')
require(count_prefix('levetiracetam-dog-')>=3 and count_prefix('levetiracetam-cat-')>=3, 'Levetiracetam IR/ER/IV selector coverage incomplete')
require(count_prefix('atropine-injection-dog-')>=2 and count_prefix('atropine-injection-cat-')>=2, 'Atropine CPR vs non-arrest selector coverage incomplete')

# Titrated anesthetics must be explicitly high-risk and dose-to-effect.
for rid in ('propofol-dog-1','propofol-cat-1','alfaxalone-dog-1','alfaxalone-cat-1'):
    r=byid.get(rid); require(r is not None, f'Missing {rid}')
    if r:
        require(r['highRisk'], f'{rid}: must be highRisk')
        require('effect' in r['frequency'].lower() or 'effect' in r['notes'].lower(), f'{rid}: must explicitly say dose/titrate to effect')

# Known hard maximum must be visible for chronic dog furosemide.
for rid in ('furosemide-dog-2',):
    r=byid.get(rid); require(r is not None, f'Missing {rid}')
    if r: require('12 mg/kg/day' in r['notes'], f'{rid}: missing 12 mg/kg/day hard-maximum warning')

# Unit examples independently recomputed.
# 4 kg cat x 40 mcg/kg = 160 mcg = .16 mg / .5 mg/mL = .32 mL
r=byid['dexmedetomidine-cat-1']; lo,hi=amounts(r,4); v=volume(r,lo,hi)
require(v and abs(v[0]-0.32)<1e-9 and abs(v[1]-0.32)<1e-9, f'Dexmedetomidine cat conversion expected 0.32mL, got {v}')
# 20 kg dog x 25-80 mcg/kg/min -> 500-1600 mcg/min -> 30-96 mg/hr / 20mg/mL = 1.5-4.8 mL/hr
r=byid['lidocaine-dog-2']; lo,hi=amounts(r,20); v=volume(r,lo,hi)
require(v and abs(v[0]-1.5)<1e-9 and abs(v[1]-4.8)<1e-9, f'Lidocaine dog CRI expected 1.5-4.8mL/hr, got {v}')
# 20 kg dog fentanyl: .01 mg/kg/hr => .2mg/hr / .05mg/mL = 4mL/hr
r=byid['fentanyl-dog-2']; lo,hi=amounts(r,20); v=volume(r,lo,hi)
require(v and abs(v[0]-4.0)<1e-9, f'Fentanyl dog CRI expected 4mL/hr, got {v}')
# Feline glargine 1U at U100 = .01mL
r=byid['insulin-glargine-cat-1']; lo,hi=amounts(r,0); v=volume(r,lo,hi)
require(v and abs(v[0]-0.01)<1e-9, f'Feline glargine expected 0.01mL, got {v}')

# Tests must contain the edge-case coverage we expect CI to execute.
for token in [
    'testEveryBuiltInPresetCalculatesAtSmallTypicalAndLargeWeights',
    'testDexmedetomidineCatMcgToMgMlConversion',
    'testDexmedetomidineDogUsesBSAInsteadOfFixedMcgKg',
    'testLidocaineCriMcgPerMinuteConvertsSafelyFromMgPerMl',
    'testFentanylCriUsesHourlyMgProtocolAndMgPerMl',
    'testMitotaneMaintenanceIsWeeklyNotQ12h',
    'testControlledAnalgesicCriticalBranches',
    'testEmergencySelectorsCarryCorrectFrequencyAndSeparation',
    'testSecondAuditMetadataAndIndicationBranches',
    'testDesmopressinSeparatesHemostaticAndCdiProtocols',
    'testMethocarbamolDistinguishesDailyTotalFromIvIncrement',
    'testAllPresetsHaveExplicitRouteFrequencyAndSource',
    'testVolumeBasedProtocolRetainsRequiredProductConcentration'
]: require(token in tests, f'Missing required XCTest {token}')

report={
  'status':'PASS' if not errors else 'FAIL',
  'preset_count':len(rows),
  'unique_medication_count':len(names),
  'unique_id_count':len(set(ids)),
  'independent_arithmetic_cases':arith_cases,
  'concentration_contract':{
    'mass':'mg/mL','insulin':'units/mL','electrolyte':'mEq/mL'
  },
  'critical_examples':{
    'dexmedetomidine_cat_4kg_40mcgkg_0_5mgml_mL':0.32,
    'lidocaine_dog_20kg_25_80mcgkgmin_20mgml_mLhr':[1.5,4.8],
    'fentanyl_dog_20kg_0_01mgkghr_0_05mgml_mLhr':4.0,
    'glargine_cat_1U_U100_mL':0.01
  },
  'files':{
    'BuiltInProtocolCatalog.swift':sha(CATALOG),
    'ProtocolMedicationStore.swift':sha(STORE),
    'DoseView.swift':sha(DOSEVIEW),
    'MedicationPreloadTests.swift':sha(TESTS)
  },
  'errors':errors,
  'warnings':warnings
}
print(json.dumps(report,indent=2,sort_keys=True))
if errors:
    sys.exit(1)
