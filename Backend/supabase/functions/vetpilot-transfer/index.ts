import {transferHandler} from './handler.ts';
Deno.serve(transferHandler({url:Deno.env.get('SUPABASE_URL')!,key:Deno.env.get('SUPABASE_ANON_KEY')!,serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!}));
