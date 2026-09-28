\set ON_ERROR_STOP on
\i Backend/tests/database.sql
\i Backend/supabase/migrations/202609280001_workspace_additions.sql
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
select public.save_workspace_collection(0,'[{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","kind":"favorite","title":"CBC","target":"Lab|CBC","updatedAt":1000,"value":{"enabled":true}}]');
do $$begin
 if (select count(*) from public.workspace_collections)<>1 then raise exception 'Workspace own read failed';end if;
 begin perform public.save_workspace_collection(0,'[]');raise exception 'Workspace revision overwrite';exception when sqlstate 'PT409' then null;end;
 begin update public.workspace_collections set items='[]';raise exception 'Workspace direct write allowed';exception when insufficient_privilege then null;end;
 if public.valid_workspace_items('[{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","kind":"annotation","title":"Mark","target":"photo|fixture","updatedAt":1000,"value":{"shape":"circle","label":"","x":-1,"y":0,"x2":1,"y2":1}}]') then raise exception 'Invalid annotation accepted';end if;
 if public.valid_workspace_items('[{}]') or public.valid_workspace_items(null) or public.valid_workspace_items('{}') then raise exception 'Invalid shape accepted';end if;
 if (select version from public.workspace_collections)<>1 then raise exception 'Failed operation altered data';end if;
end$$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$begin
 if (select count(*) from public.workspace_collections)<>0 then raise exception 'Workspace cross-account read';end if;
 begin perform public.save_workspace_collection(1,'[]');raise exception 'Workspace cross-account overwrite';exception when sqlstate 'PT409' then null;end;
end$$;
select public.save_workspace_collection(0,'[]');
set request.jwt.claim.sub='';
do $$begin
 begin perform public.save_workspace_collection(0,'[]');raise exception 'Workspace unauthenticated write';exception when insufficient_privilege then null;end;
end$$;
reset role;
set role anon;
do $$begin
 begin perform * from public.workspace_collections;raise exception 'Workspace anonymous read';exception when insufficient_privilege then null;end;
 begin perform public.save_workspace_collection(0,'[]');raise exception 'Workspace anonymous write';exception when insufficient_privilege then null;end;
end$$;
reset role;
select 'Workspace owner isolation, compare-and-swap and validation passed' as result;
