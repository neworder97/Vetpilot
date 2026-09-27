export type QRCollection='clinic'|'cytology';
export type QRItem={id:string;title:string;category:string;kind:string;summary:string;steps:{id:string;text:string}[];equipment:{id:string;name:string;quantity:string;size:string;location:string}[];notes:string;photos:{id:string;caption:string;jpeg:string}[];author:string;reviewer:string;reviewedOn:string;revision:number;updatedAt:string;favorite:boolean;imported:boolean;sourceID?:string};
export type QRPackage={format:'VetPilot.MyClinic';schemaVersion:1;exportedAt:string;items:QRItem[]};
export type QRShare={id:string;collection:QRCollection;expiresAt:string;itemCount:number;title:string;url?:string};
export function validateQRPackage(value:unknown):QRPackage{
 const p=value as QRPackage;const fail=():never=>{throw Error('Invalid sharing file or unsupported file size.');};
 const unique=(a:{id:string}[])=>a.every(v=>v&&typeof v.id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v.id))&&new Set(a.map(v=>v.id.toLowerCase())).size===a.length;
 if(!p||p.format!=='VetPilot.MyClinic'||p.schemaVersion!==1||!Number.isFinite(Date.parse(p.exportedAt))||!Array.isArray(p.items)||!p.items.length||p.items.length>1000||!unique(p.items))fail();
 for(const i of p.items){
  if(!i||typeof i.title!=='string'||!i.title.trim()||i.title.length>200||!['Protocol','Equipment set'].includes(i.kind)||!Array.isArray(i.steps)||i.steps.length>200||!Array.isArray(i.equipment)||i.equipment.length>200||!Array.isArray(i.photos)||i.photos.length>8||!unique(i.steps)||!unique(i.equipment)||!unique(i.photos))fail();
  const strings=[i.title,i.category,i.summary,i.notes,i.author,i.reviewer,i.reviewedOn,...i.steps.map(s=>s.text),...i.equipment.flatMap(e=>[e.name,e.quantity,e.size,e.location]),...i.photos.map(p=>p.caption)];
  if(strings.some(s=>typeof s!=='string'||new TextEncoder().encode(s).length>20000)||!Number.isInteger(i.revision)||i.revision<1||i.revision>=1000000||typeof i.favorite!=='boolean'||typeof i.imported!=='boolean'||!Number.isFinite(Date.parse(i.updatedAt)))fail();
  let total=0;for(const photo of i.photos){if(typeof photo.jpeg!=='string'||!photo.jpeg.length||photo.jpeg.length>2666668||!/^[A-Za-z0-9+/]*={0,2}$/.test(photo.jpeg))fail();let bytes=0;try{bytes=atob(photo.jpeg).length;}catch{fail();}if(!bytes||bytes>2000000)fail();total+=bytes;}if(total>8000000)fail();
 }
 if(new TextEncoder().encode(JSON.stringify(p)).length>15_000_000)fail();return p;
}
