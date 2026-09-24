import { RequestError } from './core.mjs';
export function headers(request: Request): Record<string,string> {
  const origin=request.headers.get('origin'); const allowed=(Deno.env.get('ALLOWED_WEB_ORIGINS')||'').split(',').filter(Boolean);
  if(origin && !allowed.includes(origin)) throw new RequestError('Origin not allowed',403);
  return {'Content-Type':'application/json','Cache-Control':'no-store',...(origin?{'Access-Control-Allow-Origin':origin,'Vary':'Origin','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'}:{})};
}
export async function identity(request: Request) {
  const authorization=request.headers.get('authorization');
  if(!authorization?.startsWith('Bearer ')) throw new RequestError('Sign-in required',401);
  const url=Deno.env.get('SUPABASE_URL')!, key=Deno.env.get('SUPABASE_ANON_KEY')!;
  const response=await fetch(url+'/auth/v1/user',{headers:{Authorization:authorization,apikey:key},signal:AbortSignal.timeout(15_000)});
  if(!response.ok)throw new RequestError('Invalid session',401);
  const user=await response.json(); if(!user.id || user.is_anonymous)throw new RequestError('Verified account required',403);
  return {id:user.id,authorization,url,key};
}
export function failure(error: unknown, responseHeaders: Record<string,string>) {
  // Never log patient content, transcripts, audio, tokens or upstream response bodies.
  return new Response(JSON.stringify({error:error instanceof RequestError?error.message:'Service unavailable; local data is preserved'}),{status:error instanceof RequestError?error.status:503,headers:responseHeaders});
}
