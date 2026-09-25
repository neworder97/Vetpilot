\set ON_ERROR_STOP on
create schema auth;
create role anon; create role authenticated;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
\i Backend/supabase/migrations/202609240001_scribe.sql
insert into auth.users values('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
insert into public.scribe_ai_access(user_id,enabled,daily_limit) values('11111111-1111-4111-8111-111111111111',true,2);
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
select public.save_scribe_encounter('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","patients":[]}');
do $$ begin
  if (select count(*) from public.scribe_encounters)<>1 then raise exception 'Own record not visible';end if;
  if not public.consume_scribe_quota() or not public.consume_scribe_quota() or public.consume_scribe_quota() then raise exception 'Quota failure';end if;
  begin perform public.save_scribe_encounter('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","patients":[]}');raise exception 'Conflict not detected';exception when sqlstate 'PT409' then null;end;
end $$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$begin
  if (select count(*) from public.scribe_encounters)<>0 then raise exception 'Cross-account read leak';end if;
  if public.consume_scribe_quota() then raise exception 'AI enabled without explicit access';end if;
  begin perform public.save_scribe_encounter('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',1,'{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","patients":[]}');raise exception 'Cross-account overwrite';exception when sqlstate 'PT409' then null;end;
end $$;
set request.jwt.claim.sub='';
do $$begin
  begin perform public.save_scribe_encounter('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","patients":[]}');raise exception 'Unauthenticated write';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'Database identity, isolation, revision conflict and quota checks passed' as result;

\i Backend/supabase/migrations/20260925001805_cytology_library_sync.sql
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
select public.save_cytology_collection(0,'[{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","title":"Ear cytology","photos":[{"caption":"Yeast","jpeg":"dGVzdA=="}]}]'::jsonb);
do $$ begin
 if (select count(*) from public.cytology_collections)<>1 then raise exception 'Cytology own read failure';end if;
 begin perform public.save_cytology_collection(0,'[]'::jsonb);raise exception 'Missing cytology conflict';exception when sqlstate 'PT409' then null;end;
end $$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$ begin
 if (select count(*) from public.cytology_collections)<>0 then raise exception 'Cytology cross-account leak';end if;
 begin perform public.save_cytology_collection(1,'[]'::jsonb);raise exception 'Cytology cross-account overwrite';exception when sqlstate 'PT409' then null;end;
end $$;
reset role;
