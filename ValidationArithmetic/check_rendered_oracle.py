"""Independently check actual calculator output, not just helper selections."""
from pathlib import Path
from decimal import Decimal, localcontext
import json,re,math,sys
root=Path(__file__).parent
D=lambda x:Decimal(str(x))
number=r'(?:[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)'
lead=re.compile('^('+number+')(?:–('+number+'))? ')
def source_ineligible(identifier, kg):
 return (identifier == 'levetiracetam-cat-2' or
         (identifier == 'digoxin-cat-1' and not (0 < kg < 3)) or
         (identifier == 'digoxin-cat-2' and not (3 <= kg <= 6)) or
         (identifier == 'digoxin-cat-3' and not (kg > 6)) or
         (identifier == 'mirtazapine-oral-dog-1' and not (0 < kg < 7)) or
         (identifier == 'mirtazapine-oral-dog-2' and not (7 < kg <= 15)) or
         (identifier == 'mirtazapine-oral-dog-3' and not (15 < kg <= 30)) or
         (identifier == 'mirtazapine-oral-dog-4' and not (kg > 30)))
def audit(data, restrictions=False):
    failures=[]; checks=0; automatic_checked=0
    def check(condition,detail):
        nonlocal checks
        checks+=1
        if not condition:failures.append(detail)
    def compare_range(text,low,high,identifier,unit):
        m=lead.match(text)
        check(m is not None,{'case':identifier,'field':text,'expected_unit':unit,'error':'missing numeric range'})
        if not m:return
        values=(D(m[1]),D(m[2] or m[1]))
        for actual,expected in zip(values,(low,high)):
            check(math.isclose(float(actual),float(expected),rel_tol=5e-9,abs_tol=1e-11),{'case':identifier,'actual':str(actual),'expected':str(expected),'text':text})
        suffix=text[m.end():]
        check(suffix.startswith(unit),{'case':identifier,'expected_unit':unit,'text':text})
    units={'mg/kg':'mg','Fixed mg/patient':'mg','mg/lb':'mg','mg/m²':'mg','mcg/kg':'mcg','g/kg':'g','units/kg':'units','Fixed units/patient':'units','drops/eye':'drop(s)/eye','inch ribbon/eye':'inch ribbon/eye','mL/kg':'mL','mcg/kg/min':'mcg/min','mg/kg/hr':'mg/hr','mEq/kg/hr':'mEq/hr','mEq/kg':'mEq'}
    for p in data['presets']:
        for c in p['cases']:
            b=p['basis'];kg=D(c['kg']);key=f"{p['id']}:{c['kg']}:{c['level']}"
            with localcontext() as ctx:
                ctx.prec=45
                factor=D(1) if b.startswith('Fixed') or b in ('drops/eye','inch ribbon/eye') else kg/D('0.45359237') if b=='mg/lb' else (D('.101' if p['species']=='Dog' else '.100')*kg**(D(2)/D(3))) if b=='mg/m²' else kg
                low=D(p['min'])*factor;high=D(p['max'])*factor
                if restrictions and source_ineligible(p['id'], kg):
                    check(not c['engine']['available'] and not c['engine']['formulation'],{'case':key,'error':'ineligible protocol must not calculate'})
                    continue
                if restrictions and p['id']=='digoxin-dog-1':high=min(high,D('.25'))
                e=c['engine'];check(e['available'],{'case':key,'error':'unexpected unavailable'})
                if not e['available']:continue
                compare_range(e['headline'],low,high,key+':headline',units[b])
                if b not in ('mL/kg','drops/eye') and p.get('concentration'):
                    mult=D('.06') if b=='mcg/kg/min' else D('.001') if b=='mcg/kg' else D(1000) if b=='g/kg' else D(1)
                    compare_range(e['formulation'],low*mult/D(p['concentration']),high*mult/D(p['concentration']),key+':formulation','mL/hr' if b.endswith('/hr') or b=='mcg/kg/min' else 'mL')
                elif p['strengths'] and b in ('mg/kg','mg/lb','mg/m²','Fixed mg/patient'):
                    compare_range(e['formulation'],low/D(p['strengths'][0]),high/D(p['strengths'][0]),key+':formulation','unit(s)')
    for p in data['automaticMedications']:
        for c in p['cases']:
            kg=D(c['kg']);e=c['result'];key=f"{p['name']}:{c['kg']}";automatic_checked+=1
            if p['kind']=='robenacoxibCatBand':
                eligible=D('2.5')<=kg<=12
                check(e['available']==eligible,{'case':key,'error':'weight band availability'})
                if eligible:check(e['headline'].startswith('1 × 6 mg' if kg<=6 else '2 × 6 mg'),{'case':key,'error':'wrong labeled tablet count'})
                continue
            if p['name']=='Mirtazapine transdermal (Mirataz)':
                check(e['available'] and e['headline'].startswith('2 mg'),{'case':key,'error':'fixed Mirataz'})
                check('mL' not in e['formulation'],{'case':key,'error':'ointment converted to volume'})
                continue
            check(e['available'],{'case':key,'error':'unexpected unavailable'})
            factor=D(1) if p['kind']=='fixedMg' else kg/D('0.45359237') if p['kind']=='mgLb' else kg
            low=D(p['min'])*factor;high=D(p['max'])*factor
            compare_range(e['headline'],low,high,key,'mg')
            if p.get('concentration'):
                compare_range(e['formulation'],low/D(p['concentration']),high/D(p['concentration']),key+':formulation','mL')
            elif p['strengths']:
                compare_range(e['formulation'],low/D(p['strengths'][0]),high/D(p['strengths'][0]),key+':formulation','unit(s)')
    return {'comparisons':checks,'failure_count':len(failures),'failures':failures,'automatic_entry_weight_cases':automatic_checked,'scope':'Numeric displayed outputs and units only; no clinical dose validity implied.'}
if __name__=='__main__':
    for version in ['baseline','candidate']:
        data=json.loads((root/(version+'-engine-results.json')).read_text())
        result=audit(data, restrictions=version=='candidate')
        (root/(version+'-rendered-oracle.json')).write_text(json.dumps(result,indent=2))
        print(version,{k:v for k,v in result.items() if k!='failures'});print('Examples',result['failures'][:3])

