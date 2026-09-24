'use strict';
const $=s=>document.querySelector(s), esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const call=q=>{const r=JSON.parse(Android.request(JSON.stringify(q)));if(r?.error)throw Error(r.error);return r;};
const load=(key,fallback)=>call({native:'load',key})??fallback;
const persist=(key,value)=>call({native:'save',key,value});
const uuid=()=>crypto.randomUUID();const now=()=>new Date().toISOString().replace(/\.\d{3}Z$/,'Z');
let catalog,clinic,settings,custom,overrides;
const state={tab:'dose',page:'list',species:'Dog',weight:'',unit:'lb',query:'',form:'Any form',provider:'IDEXX',clinicQuery:'',breedQuery:'',labQuery:'',med:null,presets:[],preset:null,result:null,edit:null,import:null};
const options=(values,selected)=>values.map(v=>{const [value,label]=Array.isArray(v)?v:[v,v];return `<option value="${esc(value)}" ${String(value)===String(selected)?'selected':''}>${esc(label)}</option>`;}).join('');
const field=(id,label,value='',type='text',extra='')=>`<label for="${id}">${esc(label)}</label><input id="${id}" type="${type}" value="${esc(value)}" ${extra}>`;
const select=(id,label,values,value)=>`<label for="${id}">${esc(label)}</label><select id="${id}">${options(values,value)}</select>`;
const area=(id,label,value='')=>`<label for="${id}">${esc(label)}</label><textarea id="${id}">${esc(value)}</textarea>`;
const btn=(action,label,cls='',extra='')=>`<button data-action="${action}" class="${cls}" ${extra}>${esc(label)}</button>`;
const back=()=>btn('back','‹ Back','back');
const val=id=>$('#'+id)?.value??'';const checked=id=>!!$('#'+id)?.checked;
const fmt=n=>Number.isFinite(n)?new Intl.NumberFormat('en',{maximumSignificantDigits:6}).format(n):'—';
const detail=(label,value)=>value!==null&&value!==undefined&&value!==''?`<dt>${esc(label)}</dt><dd>${esc(value)}</dd>`:'';
const matches=(text,q)=>q.toLowerCase().trim().split(/\s+/).every(s=>text.toLowerCase().includes(s));
const sourceLink=s=>{const urls=String(s).match(/https?:\/\/[^\s]+/g)||[];return `<p>${esc(s)}</p>`+urls.map(u=>`<p><a href="${esc(u)}">Open source ↗</a></p>`).join('');};
function toast(text){$('#toast').textContent=text;$('#toast').style.display='block';setTimeout(()=>$('#toast').style.display='none',4000);}
function render(){
 $('#tabs').innerHTML=[['dose','✚','Dose'],['clinic','▤','My Clinic'],['breeds','♧','Breeds'],['nutrition','◉','Nutrition'],['labs','⚗','Labwork']].map(([id,icon,label])=>`<button data-tab="${id}" class="${state.tab===id?'active':''}" aria-current="${state.tab===id?'page':'false'}"><span aria-hidden="true">${icon}</span>${label}</button>`).join('');
 if(state.page==='settings')return renderSettings();
 if(state.tab==='dose')return state.page==='custom'?renderCustom():state.page==='override'?renderOverride():state.med?renderDose():renderMedications();
 if(state.tab==='clinic')return state.import?renderImport():state.edit?renderClinicEditor():state.page==='detail'?renderClinicDetail():renderClinic();
 if(state.tab==='nutrition')return renderNutrition();
 if(state.tab==='breeds')return renderBreeds();
 renderLabs();
}
function renderMedications(){
 $('#app').innerHTML=`<h1>Automatic dose calculator</h1><p class="muted">Choose a medication and enter the patient weight. Veterinarian verification is required before prescribing, dispensing or administering.</p><div class="grid"><div>${select('species','Patient',['Dog','Cat'],state.species)}</div><div>${field('weight','Patient weight',state.weight,'text','inputmode="decimal"')}</div><div>${select('unit','Weight unit',['lb','kg'],state.unit)}</div></div><div class="tools"><div class="grow">${field('medSearch','Search medications',state.query,'search')}</div><div>${select('form','Form',['Any form','Tablet','Capsule','Liquid','Injection','Transdermal','Reference'],state.form)}</div>${btn('custom','＋ Custom')}</div><p id="medCount" class="muted"></p><div id="medList" class="list"></div>`;filterMeds();
}
function filterMeds(){
 const all=[...catalog.medications,...custom.map(c=>({id:'custom:'+c.id,name:c.brand?`${c.generic} (${c.brand})`:c.generic,species:[c.speciesRaw],form:c.formRaw,indication:c.indication,drugClass:c.drugClass||'Custom',custom:c}))];
 const items=all.filter(m=>m.species.includes(state.species)&&(state.form==='Any form'||m.form===state.form)&&matches([m.name,m.drugClass,m.indication].join(' '),state.query));
 $('#medCount').textContent=`${items.length} entries`;
 $('#medList').innerHTML=items.map(m=>`<button data-med="${esc(m.id)}"><strong>${esc(m.name)}</strong><span>${esc(m.form)} • ${esc(m.drugClass)}</span><span>${esc(m.indication)}</span>${m.controlled?'<p class="badge warn">CONTROLLED</p>':''}<p class="badge ${m.custom?'warn':''}">${m.custom?'USER ENTERED • REVIEW REQUIRED':m.protocolOnly?'PROTOCOL / INDICATION SELECTOR':'SOURCE-BACKED CALCULATION'}</p></button>`).join('')||'<p>No matching medications.</p>';
}
function medRequest(){return state.med.custom?{custom:state.med.custom,species:state.species}:{medication:state.med.id,species:state.species};}
function overrideKey(){return [state.med.generic,state.med.brand,state.med.form,state.species].join('|').toLowerCase();}
function definition(){return state.med.protocolOnly?(overrides[overrideKey()]||state.preset?.definition):null;}
function openMedication(id){
 const original=id.startsWith('custom:')?null:catalog.medications[Number(id)];
 if(original)state.med=original;else{const c=custom.find(x=>'custom:'+x.id===id);const r=call({op:'presets',custom:c,species:state.species});state.med={...r.medication,id,custom:c};}
 const r=call({op:'presets',...medRequest()});state.presets=r.presets;state.preset=r.presets[0]||null;state.result=null;state.page='detail';render();window.scrollTo(0,0);
}
function renderDose(){
 const m=state.med,d=definition(),strengths=d?.strengths??m.strengths??[],concentration=d?.concentration??m.concentration??'';
 $('#app').innerHTML=`${back()}<h1>${esc(m.name)}</h1><p>${esc(m.indication)}</p><p class="badge ${m.custom?'warn':''}">${m.custom?'USER-ENTERED CALCULATOR — NOT INDEPENDENTLY VERIFIED':esc(m.form+' • '+state.species)}</p>
 ${m.protocolOnly?`<section class="card"><h2>Medication protocol</h2>${overrides[overrideKey()]?'<p class="notice">Clinic override enabled. User-entered equation requires veterinary review.</p>':state.presets.length?select('preset','Protocol / indication',state.presets.map(p=>[p.id,p.label]),state.preset?.id):'<p class="notice">No preloaded calculator. A veterinarian-reviewed protocol is required.</p>'}${d?`<dl>${detail('Equation',d.doseBasisRaw)}${detail('Schedule',d.frequency)}${detail('Route',d.route)}</dl>`:''}<div class="tools">${btn('override','Edit clinic override')}${overrides[overrideKey()]?btn('removeOverride','Use preloaded protocols'):''}</div></section>`:''}
 ${d?.doseBasisRaw==='mL/kg'&&d.concentration?`<p class="notice">Required product concentration: ${fmt(d.concentration)} mg/mL. This mL/kg protocol applies to this product concentration only. Do not substitute a different concentration without a matching reviewed protocol.</p>`:''}
 <section class="card"><h2>Patient & calculation selections</h2><div class="grid"><div>${field('doseWeight','Patient weight',state.weight,'text','inputmode="decimal"')}</div><div>${select('doseUnit','Weight unit',['lb','kg'],state.unit)}</div><div>${select('level','Dose level',['Low','Middle','High'],'Middle')}</div><div>${select('frequency','Frequency', [['Recommended',`Recommended: ${d?.frequency??m.frequency}`],'q8h','q12h','q24h'],'Recommended')}</div>
 ${strengths.length?`<div>${select('strength','Product strength (mg)',strengths.map((x,i)=>[i,fmt(x)+' mg']),0)}</div><div>${select('rounding','Whole-unit rounding',['Round down','Nearest whole','Round up'],'Nearest whole')}</div>`:''}
 ${(d?!['mL/kg','drops/eye','inch ribbon/eye'].includes(d.doseBasisRaw):['Liquid','Injection','Transdermal'].includes(m.form)&&m.generic!=='Mirtazapine transdermal')?`<div>${field('concentration','Verified concentration ('+((d?.doseBasisRaw.includes('units')?'units/mL':d?.doseBasisRaw.includes('mEq')?'mEq/mL':'mg/mL'))+')',concentration,'text','inputmode="decimal"')}</div>`:''}
 ${d?.doseBasisRaw.endsWith('/hr')||d?.doseBasisRaw.endsWith('/min')?'<label class="check"><input id="infusion" type="checkbox">I verified the final prepared infusion concentration.</label>':''}
 ${d?.medicationKey.includes('potassium-chloride')?`<div>${field('potassiumRate','Prescribed potassium rate (mEq/kg/hr)','','text','inputmode="decimal"')}</div>`:''}
 <div>${select('days','Quantity / days supply',[[0,'No supply calculation'],[3,'3 days'],[7,'7 days'],[10,'10 days'],[14,'14 days'],[30,'30 days']],0)}</div>
 ${m.generic==='Robenacoxib'&&m.form==='Tablet'?`<div>${select('priorDoses','Prior ONSIOR doses this course',[0,1,2,3],0)}</div><label class="check"><input id="priorConfirmed" type="checkbox">Oral and injectable dose history confirmed.</label>`:''}</div><p class="muted">Frequency changes require the prescriber's approval. Product and course limits still apply.</p>${btn('calculate','Calculate dose','primary')}</section><div id="doseResult"></div>`;
}
function calculate(){
 state.weight=val('doseWeight');state.unit=val('doseUnit');
 const q={op:'dose',...medRequest(),preset:state.preset?.id,weight:state.weight,unit:state.unit,level:val('level'),frequency:val('frequency'),strengthIndex:Number(val('strength')||0),rounding:val('rounding')||'Nearest whole',concentration:val('concentration'),potassiumRate:val('potassiumRate'),infusionConfirmed:checked('infusion'),priorConfirmed:checked('priorConfirmed'),priorCourseDoses:Number(val('priorDoses')||0),days:Number(val('days'))};
 if(state.med.protocolOnly&&overrides[overrideKey()])q.override=overrides[overrideKey()];
 try{const r=call(q);state.result=r;renderResult(r);}catch(e){$('#doseResult').innerHTML=`<div class="error" role="alert">${esc(e.message)}</div>`;}
 $('#doseResult').scrollIntoView({behavior:'smooth',block:'start'});
}
function renderResult(r){
 const s=r.selection;
 $('#doseResult').innerHTML=`<section class="card candidate"><h2>Calculated candidate</h2>${r.available&&s?`<p class="amount">${fmt(s.selected)} ${esc(s.unit)} • ${esc(r.frequency)}</p>`:`<p class="amount">${esc(r.headline)}</p>`}${r.summary?`<p class="quantity">${esc(r.summary)}</p>`:''}${r.note?`<p>${esc(r.note)}</p>`:''}${r.reviewReason?`<p class="notice">Calculation only — ${esc(r.reviewReason)}</p>`:''}${r.solid?`<p>${esc(r.solid.instruction)}</p>`:''}${r.volume?`<p>${esc(r.volume.instruction)}</p>`:''}${r.supply?`<p><strong>Quantity / supply</strong><br>${esc(r.supply)}</p>`:''}</section>
 <section class="card"><h2>Equation & math</h2><dl>${detail('Calculated range',r.headline)}${detail('Weight',fmt(r.kg)+' kg')}${detail('Equation',r.math)}${detail('Selected amount math',s?.math)}${detail('Formulation',r.formulation)}${detail('Route',r.route)}</dl>${r.levels?`<table><caption>Selectable dose levels</caption><thead><tr><th>Level</th><th>Amount</th></tr></thead><tbody>${r.levels.map(x=>`<tr><td>${esc(x.level)}</td><td>${x.selection?fmt(x.selection.selected)+' '+esc(x.selection.unit):'Not available'}</td></tr>`).join('')}</tbody></table>`:''}${r.solid?`<dl>${detail('Whole-unit rounding',fmt(r.solid.roundedUnits)+' units → '+fmt(r.solid.deliveredMg)+' mg')}${detail('Variance from selected target',fmt(r.solid.variancePercent)+'%')}</dl>`:''}</section>
 <section class="card"><h2>Clinical notes & sources</h2>${r.warning?`<p class="notice">${esc(r.warning)}</p>`:''}<p>${esc(r.notes)}</p>${sourceLink(r.source)}<p class="muted">Veterinarian verification is required before prescribing, dispensing or administering.</p></section>`;
}
function renderNutrition(){
 $('#app').innerHTML=`<h1>Nutrition & body condition</h1><p class="muted">Adult dogs and cats. Weight status reflects the selected 9-point body condition score, not weight alone.</p><section class="card"><div class="grid"><div>${select('nutSpecies','Patient',['Dog','Cat'],state.species)}</div><div>${field('nutWeight','Current weight',state.weight,'text','inputmode="decimal"')}</div><div>${select('nutUnit','Weight unit',['lb','kg'],state.unit)}</div><div>${select('nutStatus','Reproductive status',['Spayed / Neutered','Intact'],'Spayed / Neutered')}</div><div>${select('bcs','Body condition score',Array.from({length:9},(_,i)=>[i+1,`${i+1}/9 — ${i<3?'Underweight':i<5?'Ideal range':i===5?'Overweight':'Obese (PNA)'}`]),5)}</div><div>${field('currentCalories','Current daily calories (optional)','','text','inputmode="decimal"')}</div><div>${field('targetWeight','Clinician target weight (optional)','','text','inputmode="decimal"')}</div><div>${field('foodCalories','Food kcal per cup or can (optional)','','text','inputmode="decimal"')}</div></div><div class="tools">${btn('nutritionCalculate','Calculate nutrition','primary')}</div></section><div id="nutritionResult"></div><p><a href="https://petnutritionalliance.org/resources/calorie-calculator/">Pet Nutrition Alliance calculator ↗</a></p>`;
}
function nutritionCalculate(){
 const food=val('foodCalories');if(food&&(!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(food)||Number(food)<=0))throw Error('Enter positive food calories using a decimal point.');
 const r=call({op:'nutrition',species:val('nutSpecies'),weight:val('nutWeight'),unit:val('nutUnit'),status:val('nutStatus'),bcs:Number(val('bcs')),currentCalories:val('currentCalories'),targetWeight:val('targetWeight')});
 $('#nutritionResult').innerHTML=`<section class="card candidate"><h2>${esc(r.weightStatus)} • ${esc(r.goal)}</h2><p class="amount">${r.targetCalories?fmt(r.targetCalories)+' kcal/day':'Individualized nutrition plan required'}</p><dl>${detail('Estimated ideal weight',r.idealWeight?fmt(r.idealWeight)+' '+r.unit:'Not automatically established for this BCS')}${detail('Food amount',food&&r.targetCalories?fmt(r.targetCalories/Number(food))+' cups or cans/day before allowance for treats':'')}${detail('Current-weight RER',fmt(r.currentRER)+' kcal/day')}${detail('Planning RER',r.planningRER?fmt(r.planningRER)+' kcal/day':'')}${detail('Equation','RER = 70 × weight (kg)^0.75')}${detail('Calculation',r.math)}${detail('Calorie floor',r.floor?fmt(r.floor)+' kcal/day':'')}</dl><p class="notice">${esc(r.caution)}</p></section>`;
}
function renderBreeds(){
 $('#app').innerHTML=`<h1>Breed reference</h1><div class="tools"><div>${select('breedSpecies','Species',['Dog','Cat'],state.species)}</div><div class="grow">${field('breedSearch','Search breeds or conditions',state.breedQuery,'search')}</div></div><p class="muted">Predispositions are reference information and do not establish a diagnosis.</p><div id="breedList" class="list"></div>`;filterBreeds();
}
function filterBreeds(){$('#breedList').innerHTML=catalog.breeds.filter(b=>b.species===state.species&&matches([b.name,b.conditions,b.note].join(' '),state.breedQuery)).map(b=>`<article class="card"><h2>${esc(b.name)}</h2><p>${esc(b.conditions)}</p><small>${esc(b.note)}</small></article>`).join('')||'<p>No matching breeds.</p>';}
function renderLabs(){
 $('#app').innerHTML=`<h1>Labwork</h1><p class="muted">Specimen and handling reference • reviewed ${esc(catalog.labReviewed)}</p><div class="tools"><div>${select('provider','Laboratory',[['IDEXX','IDEXX Reference Laboratories'],['MSU','Michigan State VDL']],state.provider)}</div><div class="grow">${field('labSearch','Search tests, specimens or codes',state.labQuery,'search')}</div></div><p class="notice">${esc(catalog.tubeNote)} Confirm the current order code and laboratory instructions before collection.</p><div id="labList"></div>`;filterLabs();
}
function filterLabs(){$('#labList').innerHTML=catalog.labs.filter(l=>l.provider===state.provider&&matches(Object.values(l).join(' '),state.labQuery)).map(l=>`<details class="card"><summary>${esc(l.name)} ${l.code?'• '+esc(l.code):''}</summary>${!l.available?'<p class="notice">Confirm availability and requirements with the laboratory. This entry is not a verified orderable panel.</p>':''}<dl>${detail('What it tests / purpose',l.purpose)}${detail('Species',l.species)}${detail('Components',l.components)}${detail('Specimen',l.specimen)}${detail('Amount needed',l.amount)}${detail('Tube / additive / cap',l.tube)}${detail('Clotting, spinning & separation',l.preparation)}${detail('Handling & shipping',l.handling)}${detail('Notes',l.notes)}</dl>${sourceLink(l.source)}</details>`).join('')||'<p>No matching tests.</p>';}
function packageOf(items){return {format:'VetPilot.MyClinic',schemaVersion:1,exportedAt:now(),items};}
function renderClinic(){
 $('#app').innerHTML=`<h1>My Clinic</h1><p class="muted">Offline protocols, equipment sets and checklists. Share editable files with VetPilot on iPhone or Android.</p><div class="tools">${btn('newClinic','＋ New item','primary')}${btn('import','Import file')}${btn('exportAll','Export all')}${btn('settings','Sharing settings')}</div>${field('clinicSearch','Search protocols, supplies or notes',state.clinicQuery,'search')}<p class="notice">User-created content — review before clinical use. Do not store patient-identifying information here.</p><div id="clinicList" class="list"></div>`;filterClinic();
}
function filterClinic(){
 const items=clinic.filter(p=>matches(JSON.stringify(p,(k,v)=>k==='jpeg'?undefined:v),state.clinicQuery)).sort((a,b)=>Number(b.favorite)-Number(a.favorite)||a.title.localeCompare(b.title));
 $('#clinicList').innerHTML=items.map(p=>`<button data-clinic="${p.id}"><strong>${p.favorite?'★ ':''}${esc(p.title)}</strong><span>${esc(p.category)} • ${esc(p.kind)}</span><span>${esc(p.summary)}</span><span>${p.steps.length} steps • ${p.equipment.length} supplies • revision ${p.revision}</span>${p.imported?'<p class="badge warn">IMPORTED COPY — REVIEW REQUIRED</p>':''}</button>`).join('')||'<p class="card">No matching items. Add your clinic’s first protocol or import a .vetpilot file.</p>';
}
function currentClinic(){return clinic.find(p=>p.id===state.clinicID);}
function renderClinicDetail(){
 const p=currentClinic();if(!p){state.page='list';return renderClinic();}
 $('#app').innerHTML=`${back()}<h1>${esc(p.title)}</h1><p><span class="pill">${esc(p.category)}</span> <span class="pill">${esc(p.kind)}</span></p><p class="notice">User-created protocol — review before clinical use. Review names and dates are supplied by the author and are not authenticated by VetPilot.</p><div class="tools">${btn('editClinic','Edit')}${btn('favorite',p.favorite?'★ Favorite':'☆ Favorite')}${btn('exportOne','Export / email / text')}${btn('deleteClinic','Delete','danger')}</div><section class="card"><p>${esc(p.summary)}</p><h2>Checklist</h2>${p.steps.map((s,i)=>`<label class="check"><input type="checkbox">${i+1}. ${esc(s.text)}</label>`).join('')||'<p>No steps.</p>'}<h2>Equipment</h2>${p.equipment.map(e=>`<label class="check"><input type="checkbox"><span><strong>${esc(e.name)}</strong><br>${esc([e.quantity,e.size,e.location].filter(Boolean).join(' • '))}</span></label>`).join('')||'<p>No equipment listed.</p>'}<p class="muted">Checkmarks reset when you reopen this item.</p></section><section class="card"><h2>Notes & review</h2><pre>${esc(p.notes)}</pre><dl>${detail('Author',p.author)}${detail('Reviewer (not authenticated)',p.reviewer)}${detail('Review date',p.reviewedOn)}${detail('Revision',p.revision)}${detail('Updated',p.updatedAt)}</dl>${p.photos.map(photo=>`<figure><img class="photo" src="data:image/jpeg;base64,${esc(photo.jpeg)}" alt="${esc(photo.caption||'Protocol photo')}"><figcaption>${esc(photo.caption)}</figcaption></figure>`).join('')}</section>`;
}
function newClinic(){state.edit={id:uuid(),title:'',category:'General',kind:'Protocol',summary:'',steps:[],equipment:[],notes:'',photos:[],author:'',reviewer:'',reviewedOn:'',revision:1,updatedAt:now(),favorite:false,imported:false};state.page='edit';render();}
function captureClinic(){
 const p=state.edit;if(!p||!$('#editTitle'))return;
 Object.assign(p,{title:val('editTitle'),category:val('editCategory'),kind:val('editKind'),summary:val('editSummary'),notes:val('editNotes'),author:val('editAuthor'),reviewer:val('editReviewer'),reviewedOn:val('editReviewed')});
 p.steps=[...document.querySelectorAll('[data-step]')].map(el=>({id:el.dataset.step,text:el.value}));
 p.equipment=[...document.querySelectorAll('[data-equipment]')].map(el=>({id:el.dataset.equipment,...Object.fromEntries([...el.querySelectorAll('[data-key]')].map(x=>[x.dataset.key,x.value]))}));
 p.photos.forEach((photo,i)=>photo.caption=val('caption'+i));
}
function renderClinicEditor(){
 const p=state.edit;
 $('#app').innerHTML=`${back()}<h1>${clinic.some(x=>x.id===p.id)?'Edit':'New'} clinic item</h1><section class="card"><div class="grid"><div>${field('editTitle','Title',p.title,'text','maxlength="200"')}</div><div>${select('editCategory','Category',catalog.clinicCategories,p.category)}</div><div>${select('editKind','Item type',['Protocol','Equipment set'],p.kind)}</div></div>${area('editSummary','Summary',p.summary)}</section><section class="card"><h2>Steps</h2>${p.steps.map((s,i)=>`<div class="tools"><div class="grow"><label for="step${i}">Step ${i+1}</label><textarea id="step${i}" data-step="${s.id}">${esc(s.text)}</textarea></div>${btn('removeStep','Remove','',`data-index="${i}"`)}</div>`).join('')}${btn('addStep','＋ Add step')}</section><section class="card"><h2>Equipment & supplies</h2>${p.equipment.map((e,i)=>`<div data-equipment="${e.id}" class="card"><div class="grid">${['name','quantity','size','location'].map(k=>`<div><label for="eq${i}${k}">${esc(k)}</label><input id="eq${i}${k}" data-key="${k}" value="${esc(e[k])}"></div>`).join('')}</div>${btn('removeEquipment','Remove','',`data-index="${i}"`)}</div>`).join('')}${btn('addEquipment','＋ Add equipment')}</section><section class="card">${area('editNotes','Notes',p.notes)}<div class="grid"><div>${field('editAuthor','Author',p.author)}</div><div>${field('editReviewer','Reviewer (self-reported)',p.reviewer)}</div><div>${field('editReviewed','Review date',p.reviewedOn,'date')}</div></div><p class="muted">Editing clinical content clears an unchanged reviewer and review date. Enter new review details after the revised content is checked.</p></section><section class="card"><h2>Photos (${p.photos.length}/8)</h2>${p.photos.map((photo,i)=>`<figure><img class="photo" src="data:image/jpeg;base64,${esc(photo.jpeg)}" alt="Protocol photo">${field('caption'+i,'Caption',photo.caption)}${btn('removePhoto','Remove photo','',`data-index="${i}"`)}</figure>`).join('')}${btn('photo','＋ Add photo','',p.photos.length>=8?'disabled':'')}<p class="muted">Photos are resized and metadata is removed. Check orientation after import.</p></section><div class="tools">${btn('saveClinic','Save item','primary')}${btn('cancelEdit','Cancel')}</div>`;
}
function saveClinic(){
 captureClinic();const p=structuredClone(state.edit),old=clinic.find(x=>x.id===p.id);
 p.steps=p.steps.filter(s=>s.text.trim());p.equipment=p.equipment.filter(e=>e.name.trim());p.updatedAt=now();
 if(old){const clinical=x=>JSON.stringify([x.title,x.kind,x.category,x.summary,x.steps,x.equipment,x.notes,x.photos]);if(clinical(old)!==clinical(p)&&p.reviewer===old.reviewer&&p.reviewedOn===old.reviewedOn){p.reviewer='';p.reviewedOn='';}p.revision=old.revision+1;}
 const validated=call({op:'clinicValidate',package:packageOf([p])}).package.items[0];
 const next=clinic.filter(x=>x.id!==p.id).concat(validated);persist('clinic',next);clinic=next;state.edit=null;state.clinicID=p.id;state.page='detail';render();toast('Clinic item saved');
}
function renderImport(){
 const p=state.import;
 $('#app').innerHTML=`${back()}<h1>Review import</h1><p class="notice">${p.items.length} item(s) will be added as separate imported copies. Existing clinic items are preserved. Review all content before use; sender review labels are not authenticated.</p>${p.items.map(i=>`<article class="card"><h2>${esc(i.title)}</h2><p>${esc(i.summary)}</p><p>${i.steps.length} steps • ${i.equipment.length} supplies • ${i.photos.length} photos</p><p>Reviewer: ${esc(i.reviewer||'Not supplied')}</p><details><summary>View contents</summary><ol>${i.steps.map(s=>`<li>${esc(s.text)}</li>`).join('')}</ol><pre>${esc(i.notes)}</pre></details></article>`).join('')}<div class="tools">${btn('confirmImport','Add imported copies','primary')}${btn('cancelImport','Cancel')}</div>`;
}
function renderExport(items){
 state.exportItems=items;state.page='export';$('#app').innerHTML=`${back()}<h1>Export clinic items</h1><p>${items.length} item(s) selected</p><section class="card"><div class="grid"><div>${select('exportFormat','File type',[['vetpilot','Editable VetPilot file (.vetpilot)'],['pdf','Readable PDF']],'vetpilot')}</div><div>${field('exportEmail','Email recipient (optional)',settings.email||'','email')}</div><div>${field('exportPhone','Phone recipient (optional)',settings.phone||'','tel')}</div></div><p class="muted">Editable files import into VetPilot on iPhone or Android. PDFs are for reading and review.</p><div class="tools">${btn('shareEmail','Email file','primary')}${btn('shareText','Text / message file')}${btn('share','More sharing options')}${btn('saveFile','Save to Files')}</div><p class="muted">Your installed email or messaging app sends the attachment after you review and tap Send. Some apps do not accept recipient defaults or this file type; select the recipient there. Standard SMS cannot carry a file — attachment support requires a compatible messaging service.</p></section>`;
}
function exportFile(channel){call({native:'export',package:packageOf(state.exportItems),format:val('exportFormat'),channel,email:val('exportEmail').trim(),phone:val('exportPhone').trim()});}
function renderSettings(){
 $('#app').innerHTML=`${back()}<h1>Settings</h1><section class="card"><h2>Sharing defaults</h2><p>Save recipient details for exports. VetPilot uses your installed email and messaging apps; account passwords are not needed.</p>${field('settingsEmail','Default email recipient',settings.email||'','email')}${field('settingsPhone','Default phone recipient',settings.phone||'','tel')}<div class="tools">${btn('saveSettings','Save settings','primary')}</div><p class="muted">You can change recipients before sharing. Delivery depends on your configured app and connection.</p></section><section class="card"><h2>About VetPilot</h2><p>Android 0.5.0 • Offline clinical support</p><p>Calculations and reference data use the shared iPhone source engine. Software tests do not constitute veterinary approval. User-entered protocols remain the responsibility of the reviewing clinician.</p><p>My Clinic data is stored on this device. Export editable files for backup before uninstalling or changing devices.</p></section>`;
}
function renderCustom(){
 $('#app').innerHTML=`${back()}<h1>Custom medications</h1><p class="notice">User-entered equations are not independently verified. A source citation does not authenticate an equation.</p>${custom.map(c=>`<article class="card"><h2>${esc(c.generic)}</h2><p>${esc(c.speciesRaw+' • '+c.doseBasisRaw+' • '+c.frequency)}</p>${btn('deleteCustom','Delete','danger',`data-id="${c.id}"`)}</article>`).join('')}<section class="card"><h2>Add custom medication</h2><div class="grid"><div>${field('cName','Generic name')}</div><div>${field('cBrand','Brand (optional)')}</div><div>${select('cSpecies','Species',['Dog','Cat'],state.species)}</div><div>${select('cForm','Form',['Tablet','Capsule','Liquid','Injection','Transdermal','Reference'],'Tablet')}</div><div>${select('cBasis','Equation basis',['mg/kg','mg/lb','Fixed mg'],'mg/kg')}</div><div>${field('cLow','Minimum dose','','text','inputmode="decimal"')}</div><div>${field('cHigh','Maximum dose (blank = fixed)','','text','inputmode="decimal"')}</div><div>${field('cFrequency','Frequency')}</div><div>${field('cRoute','Route','PO')}</div><div>${field('cConcentration','Concentration mg/mL (optional)','','text','inputmode="decimal"')}</div></div>${field('cIndication','Indication')}${field('cSource','Source reference')}${area('cNotes','Notes')}<div class="tools">${btn('saveCustom','Save custom medication','primary')}</div></section>`;
}
function positive(text,label,optional=false){if(optional&&text.trim()==='')return null;if(!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(text.trim())||!Number.isFinite(Number(text))||Number(text)<=0)throw Error(label+' must be a finite positive number with a decimal point.');return Number(text);}
function saveCustom(){
 const low=positive(val('cLow'),'Minimum dose'),high=positive(val('cHigh'),'Maximum dose',true)??low;
 if(!val('cName').trim()||high<low)throw Error('Enter a name and a valid dose range.');
 const c={id:uuid(),generic:val('cName').trim(),brand:val('cBrand'),drugClass:'Custom',speciesRaw:val('cSpecies'),formRaw:val('cForm'),indication:val('cIndication'),doseBasisRaw:val('cBasis'),minDose:low,maxDose:high,frequency:val('cFrequency'),route:val('cRoute'),concentration:positive(val('cConcentration'),'Concentration',true),sourceReference:val('cSource'),notes:val('cNotes')};
 call({op:'presets',custom:c,species:c.speciesRaw});const next=[...custom,c];persist('custom',next);custom=next;renderCustom();toast('Custom medication saved');
}
function renderOverride(){
 const d=definition()||{};
 $('#app').innerHTML=`${back()}<h1>Clinic dose override</h1><p class="notice">Replaces the preloaded calculator for ${esc(state.med.name)} • ${esc(state.species)} on this device. Only enter a protocol reviewed by the veterinarian.</p><section class="card"><div class="grid"><div>${select('oBasis','Equation basis',catalog.protocolBases,d.doseBasisRaw||'mg/kg')}</div><div>${field('oLow','Minimum dose',d.minDose??'','text','inputmode="decimal"')}</div><div>${field('oHigh','Maximum dose',d.maxDose??'','text','inputmode="decimal"')}</div><div>${field('oFrequency','Frequency',d.frequency||'')}</div><div>${field('oRoute','Route',d.route||'')}</div><div>${field('oStrengths','Tablet strengths mg (comma separated)',(d.strengths||[]).join(', '))}</div><div>${field('oConcentration','Product concentration (basis-appropriate units)',d.concentration??'','text','inputmode="decimal"')}</div></div>${field('oSource','Source reference',d.sourceReference||'')}${area('oNotes','Notes',d.notes||'')}<label class="check"><input id="oApproved" type="checkbox">A veterinarian has reviewed and approved this protocol.</label>${btn('saveOverride','Save override','primary')}</section>`;
}
function saveOverride(){
 const low=positive(val('oLow'),'Minimum dose'),high=positive(val('oHigh'),'Maximum dose',true)??low;
 if(high<low||!checked('oApproved')||!val('oSource').trim()||!val('oFrequency').trim()||!val('oRoute').trim())throw Error('A valid range, route, frequency, source and veterinarian approval are required.');
 const d={medicationKey:overrideKey(),generic:state.med.generic,speciesRaw:state.species,doseBasisRaw:val('oBasis'),minDose:low,maxDose:high,frequency:val('oFrequency'),route:val('oRoute'),strengths:val('oStrengths').trim()?val('oStrengths').split(',').map(v=>positive(v,'Strength')):[],concentration:positive(val('oConcentration'),'Concentration',true),sourceReference:val('oSource'),notes:val('oNotes'),veterinarianApproved:true};
 const next={...overrides,[overrideKey()]:d};persist('overrides',next);overrides=next;state.page='detail';render();
}
function discardEdit(){return !state.edit||confirm('Discard unsaved changes?');}
window.goBack=()=>{if(state.edit&&!discardEdit())return;state.edit=null;state.import=null;if(['override'].includes(state.page)){state.page='detail';render();return;}if(state.tab==='clinic'&&state.page==='export'){state.page=state.clinicID?'detail':'list';render();return;}state.page='list';state.med=null;state.result=null;render();window.scrollTo(0,0);};
document.addEventListener('click',event=>{
 const el=event.target.closest('button');if(!el)return;
 try{
  if(el.dataset.tab){if(!discardEdit())return;state.tab=el.dataset.tab;state.page='list';state.med=null;state.edit=null;state.import=null;render();window.scrollTo(0,0);return;}
  if(el.dataset.med)return openMedication(el.dataset.med);
  if(el.dataset.clinic){state.clinicID=el.dataset.clinic;state.page='detail';render();window.scrollTo(0,0);return;}
  const a=el.dataset.action,i=Number(el.dataset.index);
  switch(a){
   case 'back':return goBack();
   case 'settings':if(!discardEdit())return;state.edit=null;state.page='settings';render();break;
   case 'saveSettings':{const email=val('settingsEmail').trim(),phone=val('settingsPhone').trim();if(email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw Error('Enter a valid email address.');if(phone&&!/^[+\d\s().-]{3,40}$/.test(phone))throw Error('Enter a valid phone number.');const next={email,phone};persist('settings',next);settings=next;toast('Sharing defaults saved');break;}
   case 'calculate':calculate();break;
   case 'nutritionCalculate':nutritionCalculate();break;
   case 'custom':state.page='custom';render();break;
   case 'saveCustom':saveCustom();break;
   case 'deleteCustom':if(confirm('Delete this custom medication?')){const next=custom.filter(c=>c.id!==el.dataset.id);persist('custom',next);custom=next;renderCustom();}break;
   case 'override':state.page='override';render();break;
   case 'saveOverride':saveOverride();break;
   case 'removeOverride':if(confirm('Remove the clinic override and use preloaded protocols?')){const next={...overrides};delete next[overrideKey()];persist('overrides',next);overrides=next;render();}break;
   case 'newClinic':newClinic();break;
   case 'editClinic':state.edit=structuredClone(currentClinic());state.page='edit';render();break;
   case 'cancelEdit':if(discardEdit()){state.edit=null;state.page=state.clinicID?'detail':'list';render();}break;
   case 'saveClinic':saveClinic();break;
   case 'addStep':captureClinic();if(state.edit.steps.length>=200)throw Error('Maximum 200 steps');state.edit.steps.push({id:uuid(),text:''});render();break;
   case 'removeStep':captureClinic();state.edit.steps.splice(i,1);render();break;
   case 'addEquipment':captureClinic();if(state.edit.equipment.length>=200)throw Error('Maximum 200 equipment entries');state.edit.equipment.push({id:uuid(),name:'',quantity:'',size:'',location:''});render();break;
   case 'removeEquipment':captureClinic();state.edit.equipment.splice(i,1);render();break;
   case 'photo':captureClinic();call({native:'photo'});break;
   case 'removePhoto':captureClinic();state.edit.photos.splice(i,1);render();break;
   case 'favorite':{const next=clinic.map(p=>p.id===state.clinicID?{...p,favorite:!p.favorite}:p);persist('clinic',next);clinic=next;render();break;}
   case 'deleteClinic':if(confirm('Delete this clinic item? Export a backup first if needed.')){const next=clinic.filter(p=>p.id!==state.clinicID);persist('clinic',next);clinic=next;state.page='list';state.clinicID=null;render();}break;
   case 'import':call({native:'import'});break;
   case 'cancelImport':state.import=null;state.page='list';render();break;
   case 'confirmImport':{const p=call({op:'clinicImport',package:state.import}).package;const next=[...clinic,...p.items];persist('clinic',next);clinic=next;state.import=null;state.page='list';render();toast('Imported copies added');break;}
   case 'exportAll':if(!clinic.length)throw Error('Add an item first.');renderExport(clinic);break;
   case 'exportOne':renderExport([currentClinic()]);break;
   case 'shareEmail':exportFile('email');break;
   case 'shareText':exportFile('text');break;
   case 'share':exportFile('share');break;
   case 'saveFile':exportFile('save');break;
  }
 }catch(e){alert(e.message);}
});
document.addEventListener('input',e=>{
 const id=e.target.id;
 if(id==='medSearch'){state.query=e.target.value;filterMeds();}
 if(id==='weight')state.weight=e.target.value;
 if(id==='breedSearch'){state.breedQuery=e.target.value;filterBreeds();}
 if(id==='labSearch'){state.labQuery=e.target.value;filterLabs();}
 if(id==='clinicSearch'){state.clinicQuery=e.target.value;filterClinic();}
 if(state.med&&$('#doseResult')&&id!=='medSearch'){$('#doseResult').innerHTML='';state.result=null;}
 if(state.tab==='nutrition'&&$('#nutritionResult'))$('#nutritionResult').innerHTML='';
});
document.addEventListener('change',e=>{
 const id=e.target.id;
 if(id==='species'){state.species=e.target.value;filterMeds();}
 if(id==='unit')state.unit=e.target.value;
 if(id==='form'){state.form=e.target.value;filterMeds();}
 if(id==='breedSpecies'){state.species=e.target.value;filterBreeds();}
 if(id==='provider'){state.provider=e.target.value;filterLabs();}
 if(id==='preset'){state.weight=val('doseWeight');state.unit=val('doseUnit');state.preset=state.presets.find(p=>p.id===e.target.value);renderDose();}
 if(state.med&&$('#doseResult')){$('#doseResult').innerHTML='';state.result=null;}
 if(state.tab==='nutrition'&&$('#nutritionResult'))$('#nutritionResult').innerHTML='';
});
window.nativeEvent=event=>{
 if(event.type==='error')return alert(event.value);
 if(event.type==='saved')return toast(event.value);
 if(event.type==='import'){if(!discardEdit())return;state.edit=null;state.tab='clinic';state.import=event.value;state.page='import';render();}
 if(event.type==='photo'&&state.edit){if(state.edit.photos.length>=8)return alert('Maximum 8 photos');captureClinic();state.edit.photos.push(event.value);render();}
};
try{catalog=call({op:'catalog'});clinic=load('clinic',[]);settings=load('settings',{});custom=load('custom',[]);overrides=load('overrides',{});render();}catch(e){$('#app').innerHTML=`<div class="error"><h1>VetPilot could not start</h1><p>${esc(e.message)}</p><p>Close and reopen the app. Do not clear app storage without exporting your clinic data.</p></div>`;}
