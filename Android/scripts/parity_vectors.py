#!/usr/bin/env python3
"""Generate host Swift expectations for every shipped medication/protocol.
Android executes the same requests via JNI; no reference dose is supplied by JS.
"""
import json,subprocess,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[1]
cli=root/'SwiftCore/.build/out/Products/Release-linux-x86_64/CoreCLI'
p=subprocess.Popen([str(cli)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
def call(q):
 p.stdin.write(json.dumps(q)+'\n');p.stdin.flush();return json.loads(p.stdout.readline())
catalog=call({'op':'catalog'});count=0;available=0
output=root/'app/src/debug/assets/parity.jsonl';output.parent.mkdir(parents=True,exist_ok=True)
with output.open('w') as f:
 def vector(q):
  global count,available
  expected=call(q);f.write(json.dumps({'q':q,'expected':expected},ensure_ascii=False,separators=(',',':'))+'\n');count+=1;available+=bool(expected.get('available'))
 vector({'op':'catalog'})
 for med in catalog['medications']:
  for species in med['species']:
   presets=call({'op':'presets','medication':med['id'],'species':species})['presets']
   vector({'op':'presets','medication':med['id'],'species':species})
   for preset in presets or [None]:
    d=preset['definition'] if preset else med
    for weight,level in itertools.product(['2.5','10','35'],['Low','Middle','High']):
     q={'op':'dose','medication':med['id'],'species':species,'preset':preset['id'] if preset else '', 'weight':weight,'unit':'kg','level':level,'frequency':'Recommended','rounding':'Nearest whole','strengthIndex':0,'concentration':str(d['concentration']) if d.get('concentration') else '', 'infusionConfirmed':True,'potassiumRate':'0.2','days':7,'priorCourseDoses':0,'priorConfirmed':True}
     vector(q)
    for key,value in [('weight','-1'),('weight','2,5'),('concentration','0'),('concentration','NaN'),('frequency','q12h'),('unit','lb'),('infusionConfirmed',False),('potassiumRate','0.6')]:
     vector({**q,key:value})
 for species,bcs,status,unit in itertools.product(['Dog','Cat'],range(1,10),['Spayed / Neutered','Intact'],['kg','lb']):
  vector({'op':'nutrition','species':species,'weight':'17.3','unit':unit,'status':status,'bcs':bcs,'currentCalories':'','targetWeight':''})
 vector({'op':'dose','medication':-1,'species':'Dog'})
 vector({'op':'nutrition','species':'Other','weight':'10','unit':'kg','status':'Intact','bcs':5})
p.terminate()
summary={'vectors':count,'availableDoseResults':available,'medications':len(catalog['medications']),'method':'Host Swift exact JSON expectations; Android JNI comparison uses numerical tolerance 1e-10 and exact nonnumeric text.'}
(root/'validation/parity-vector-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
