import {validateQRPackage} from './validation.ts';
type Config={url:string;key:string;serviceKey:string};
export function transferHandler(c:Config,fetcher:typeof fetch=fetch){return async(request:Request)=>{
 const origin=request.headers.get('origin'),allowed=['https://vetpilotapp.org','https://vetpilot.jr4606652.chatgpt.site'];
 const headers:Record<string,string>={'Content-Type':'application/json','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Vary':'Origin'};
 if(origin&&allowed.includes(origin)){headers['Access-Control-Allow-Origin']=origin;headers['Access-Control-Allow-Headers']='authorization,apikey,content-type';headers['Access-Control-Allow-Methods']='POST, OPTIONS';}
 const answer=(v:unknown,s=200)=>new Response(JSON.stringify(v),{status:s,headers});
 if(origin&&!allowed.includes(origin))return answer({error:'Invalid request origin.'},403);
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});if(request.method!=='POST')return answer({error:'Use POST.'},405);
 try{
  const auth=request.headers.get('authorization');if(!auth?.startsWith('Bearer '))return answer({error:'Sign in to use QR sharing.'},401);
  const check=await fetcher(c.url+'/auth/v1/user',{headers:{apikey:c.key,Authorization:auth},signal:AbortSignal.timeout(15000)});if(!check.ok)return answer({error:'Sign in to use QR sharing.'},401);
  const user=await check.json();if(!user.id||user.is_anonymous)return answer({error:'Sign in to use QR sharing.'},401);
  const reader=request.body?.getReader();if(!reader)return answer({error:'Empty request.'},400);
  let size=0;const chunks:Uint8Array[]=[];while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>15_100_000){await reader.cancel();return answer({error:'Transfer exceeds 15 MB. Select fewer items.'},413);}chunks.push(value);}
  const raw=new Uint8Array(size);let at=0;for(const p of chunks){raw.set(p,at);at+=p.length;}const input=JSON.parse(new TextDecoder().decode(raw));
  if(input.owner!==user.id)return answer({error:'Account changed. Reopen QR sharing.'},409);
  const db=async(path:string,method='GET',body?:unknown)=>{const r=await fetcher(c.url+'/rest/v1/'+path,{method,headers:{apikey:c.serviceKey,Authorization:'Bearer '+c.serviceKey,'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});if(!r.ok){const e=await r.json().catch(()=>({}));throw Error(e.message==='QR_ACTIVE_LIMIT'?'You have 10 active QR links. Revoke an old link before creating another.':'Sharing service unavailable. Please try again.');}return r.status===204?null:r.json();};
  const collection=input.collection;if(!['clinic','cytology'].includes(collection))return answer({error:'Choose My Clinic or Cytology.'},400);
  const hash=async(token:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token))),b=>b.toString(16).padStart(2,'0')).join('');
  if(input.action==='create'){
   const pkg=validateQRPackage(input.package),token=btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'');
   const rows=await db('rpc/create_qr_transfer','POST',{transfer_owner:user.id,transfer_collection:collection,transfer_hash:await hash(token),transfer_payload:pkg});
   return answer({...metadata(rows[0]),url:`https://vetpilotapp.org/transfer#v1:${collection}:${token}`});
  }
  if(input.action==='list'){const rows=await db(`qr_transfers?owner_id=eq.${encodeURIComponent(user.id)}&collection=eq.${collection}&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id,collection,expires_at,item_count,title&order=created_at.desc`);return answer({transfers:rows.map(metadata)});}
  if(input.action==='revoke'){
   if(typeof input.id!=='string'||!/^[0-9a-f-]{36}$/i.test(input.id))return answer({error:'Invalid transfer.'},400);
   await db(`qr_transfers?id=eq.${input.id}&owner_id=eq.${encodeURIComponent(user.id)}&collection=eq.${collection}`,'DELETE');return answer({ok:true});
  }
  if(input.action==='resolve'){
   if(typeof input.token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(input.token))return answer({error:'Invalid sharing link.'},400);
   const rows=await db(`qr_transfers?token_hash=eq.${await hash(input.token)}&collection=eq.${collection}&expires_at=gt.${encodeURIComponent(new Date().toISOString())}&select=id,collection,expires_at,item_count,title,payload&limit=1`);
   if(!rows.length)return answer({error:'This QR link has expired, was revoked, or is unavailable. Ask the sender for a new link.'},404);
   return answer({...metadata(rows[0]),package:rows[0].payload});
  }
  return answer({error:'Unsupported QR action.'},400);
 }catch(e){return answer({error:e instanceof Error?e.message:'QR transfer failed.'},400);}
};}
function metadata(row:Record<string,unknown>){return {id:row.id,collection:row.collection,expiresAt:row.expires_at,itemCount:row.item_count,title:row.title};}
