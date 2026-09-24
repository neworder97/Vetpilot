import {readJSON,RequestError} from '../_shared/core.mjs';
import {headers,identity,failure} from '../_shared/runtime.ts';
Deno.serve(async request=>{
  let responseHeaders:Record<string,string>={'Content-Type':'application/json','Cache-Control':'no-store'};
  try {
    responseHeaders=headers(request);if(request.method==='OPTIONS')return new Response(null,{status:204,headers:responseHeaders});
    if(request.method!=='POST')throw new RequestError('Method not allowed',405);
    const user=await identity(request);const body=await readJSON(request,1024);
    if(body.action!=='delete')throw new RequestError('Unknown action');
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');if(!service)throw new RequestError('Account deletion is not configured',503);
    // User ID comes exclusively from the verified token, never the request body.
    const response=await fetch(user.url+'/auth/v1/admin/users/'+encodeURIComponent(user.id),{method:'DELETE',headers:{Authorization:'Bearer '+service,apikey:service},signal:AbortSignal.timeout(20_000)});
    if(!response.ok)throw new RequestError('Account could not be deleted',502);
    return new Response(JSON.stringify({deleted:true}),{headers:responseHeaders});
  }catch(error){return failure(error,responseHeaders);}
});
