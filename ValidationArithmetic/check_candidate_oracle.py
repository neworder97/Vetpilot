from pathlib import Path
from decimal import Decimal, localcontext, ROUND_CEILING,ROUND_FLOOR,ROUND_HALF_UP
import json,math,csv,re
root=Path(__file__).parent
p=json.loads((root/'candidate-engine-results.json').read_text())
errors=[];round_boundary=[];n=0;vcount=0;scount=0;rounded_to_zero=[];display_large=[]
D=lambda v:Decimal(str(v))
def check(actual,expected,label):
 global n
 n+=1
 if not math.isclose(float(actual),float(expected),rel_tol=2e-10,abs_tol=1e-11):errors.append({'case':label,'actual':actual,'expected':str(expected)})
def source_ineligible(identifier, kg):
 return (identifier in ('levetiracetam-cat-2', 'cyclophosphamide-cat-1', 'ampicillin-sulbactam-dog-2', 'ampicillin-sulbactam-cat-2', 'potassium-chloride-dog-1', 'potassium-chloride-cat-1') or
         (identifier == 'praziquantel-dog-1' and kg > 34) or
         (identifier == 'doxorubicin-dog-1' and not (kg > 10)) or
         (identifier == 'doxorubicin-dog-2' and not (0 < kg <= 10)) or
         (identifier == 'digoxin-cat-1' and not (0 < kg < 3)) or
         (identifier == 'digoxin-cat-2' and not (3 <= kg <= 6)) or
         (identifier == 'digoxin-cat-3' and not (kg > 6)) or
         (identifier == 'mirtazapine-oral-dog-1' and not (0 < kg < 7)) or
         (identifier == 'mirtazapine-oral-dog-2' and not (7 < kg <= 15)) or
         (identifier == 'mirtazapine-oral-dog-3' and not (15 < kg <= 30)) or
         (identifier == 'mirtazapine-oral-dog-4' and not (kg > 30)))
for r in p['presets']:
 for c in r['cases']:
  kg=D(c['kg']);basis=r['basis']
  if source_ineligible(r['id'], kg):
   check(c['engine']['available'],False,r['id']+':must-be-blocked')
   if 'selected' in c:errors.append({'case':r['id'],'error':'blocked protocol exposed a selection'})
   continue
  with localcontext() as ctx:
   ctx.prec=45
   factor=Decimal(1) if basis.startswith('Fixed') or basis in ('drops/eye','inch ribbon/eye') else (kg**(Decimal(2)/Decimal(3)) * D('.101' if r['species']=='Dog' else '.100') if basis=='mg/m²' else (kg/D('0.45359237') if basis=='mg/lb' else kg))
   lo=D(r['min'])*factor;hi=D(r['max'])*factor
   if r['id']=='digoxin-dog-1':hi=min(hi,D('.25'))
   if r['id']=='praziquantel-dog-1':hi=min(hi,D(170))
   target=lo+((hi-lo)*{'Low':D(0),'Middle':D('.5'),'High':D(1)}[c['level']])
   check(c['low'],lo,r['id']+':low');check(c['high'],hi,r['id']+':high');check(c['selected'],target,r['id']+':'+c['level'])
   if 'volume' in c:
    volume=target if basis in ('mL/kg','drops/eye') else target/D(r['concentration'])
    if basis=='mcg/kg/min':volume*=D('.06')
    elif basis=='mcg/kg':volume*=D('.001')
    elif basis=='g/kg':volume*=D(1000)
    check(c['volume'],volume,r['id']+':volume');vcount+=1
    if c['volume']>0 and float(c['displayedVolume'])==0:rounded_to_zero.append({'id':r['id'],'kg':c['kg'],'level':c['level'],'value':c['volume'],'display':c['displayedVolume'],'unit':c['volumeUnit']})
   if c['selected']>0:
    delta=(float(c['displayedAmount'])-c['selected'])/c['selected']
    if abs(delta)>.05:display_large.append({'id':r['id'],'kg':c['kg'],'level':c['level'],'value':c['selected'],'display':c['displayedAmount'],'error_percent':100*delta})
   for s in c['solids']:
    raw=target/D(s['strength']);mode={'Round down':ROUND_FLOOR,'Round up':ROUND_CEILING,'Nearest whole':ROUND_HALF_UP}[s['rounding']];rounded=raw.to_integral_value(rounding=mode)
    check(s['raw'],raw,r['id']+':raw-solid');scount+=1
    if float(rounded)!=s['rounded']:
     round_boundary.append({'id':r['id'],'kg':c['kg'],'level':c['level'],'strength':s['strength'],'mode':s['rounding'],'exact_units':str(raw),'actual_rounded':s['rounded'],'expected_rounded':str(rounded)})
    check(s['delivered'],D(s['rounded'])*D(s['strength']),r['id']+':delivered-solid')
summary={'preset_count':len(p['presets']),'medication_names':len({r['generic'] for r in p['presets']}),'weights_per_preset':10,'levels':3,'preset_weight_level_cases':sum(len(r['cases']) for r in p['presets']),'numeric_comparisons':n,'numeric_mismatches':errors,'volume_cases':vcount,'solid_rounding_cases':scount,'rounding_boundary_mismatches':round_boundary,'nonzero_volumes_displayed_as_zero':rounded_to_zero,'amount_display_errors_over_5_percent':display_large,'automatic_medication_entries':len(p['automaticMedications']),'invalid_input_probes':p['invalidInputs']}
(root/'candidate-independent-numeric-audit.json').write_text(json.dumps(summary,indent=2))
with (root/'candidate-all-307-protocols.csv').open('w') as f:
 fields=['id','generic','species','label','basis','min','max','frequency','route','strengths','concentration','source','notes','highRisk','confidence']
 w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows({k:r.get(k,'') for k in fields} for r in p['presets'])
print({k:v for k,v in summary.items() if not isinstance(v,list)})
for k in ('numeric_mismatches','rounding_boundary_mismatches','nonzero_volumes_displayed_as_zero','amount_display_errors_over_5_percent'):print(k,len(summary[k]),'Examples:',summary[k][:4])

