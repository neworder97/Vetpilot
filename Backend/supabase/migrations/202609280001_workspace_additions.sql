begin;
create function public.valid_workspace_items(records jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare r jsonb;v jsonb;k text;
begin
 if records is null or jsonb_typeof(records)<>'array' then return false;end if;
 if jsonb_array_length(records)>3000 or octet_length(records::text)>2000000 then return false;end if;
 if (select count(distinct i->>'id') from jsonb_array_elements(records) i)<>jsonb_array_length(records) then return false;end if;
 for r in select * from jsonb_array_elements(records) loop
  if jsonb_typeof(r)<>'object' or coalesce(r->>'id','')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(r->>'kind','') not in ('favorite','calculation','annotation') or jsonb_typeof(r->'target') is distinct from 'string' or length(r->>'target')>3000 or jsonb_typeof(r->'title') is distinct from 'string' or length(r->>'title')>20000 or jsonb_typeof(r->'updatedAt') is distinct from 'number' or jsonb_typeof(r->'value') is distinct from 'object' then return false;end if;
  if (r->>'updatedAt')::numeric<0 or (r->>'updatedAt')::numeric>8640000000000000 then return false;end if;
  v:=r->'value';
  if r->>'kind'='favorite' and jsonb_typeof(v->'enabled') is distinct from 'boolean' then return false;end if;
  if r->>'kind'='calculation' and jsonb_typeof(v->'inputs') is distinct from 'object' then return false;end if;
  if r->>'kind'='annotation' then
   if coalesce(v->>'shape','') not in ('arrow','circle','label') or jsonb_typeof(v->'label') is distinct from 'string' or length(v->>'label')>100 then return false;end if;
   foreach k in array array['x','y','x2','y2'] loop
    if jsonb_typeof(v->k) is distinct from 'number' then return false;end if;
    if (v->>k)::numeric<0 or (v->>k)::numeric>1 then return false;end if;
   end loop;
  end if;
 end loop;
 return true;
end;$$;
revoke all on function public.valid_workspace_items(jsonb) from public,anon;
grant execute on function public.valid_workspace_items(jsonb) to authenticated;
create table public.workspace_collections (
 user_id uuid primary key references auth.users(id) on delete cascade,
 version integer not null default 1 check(version>0),
 items jsonb not null default '[]'::jsonb check(public.valid_workspace_items(items))
);
alter table public.workspace_collections enable row level security;
revoke all on public.workspace_collections from public,anon,authenticated;
grant select on public.workspace_collections to authenticated;
create policy workspace_owner_read on public.workspace_collections for select to authenticated using(user_id=(select auth.uid()));
-- RPC is the only client writer; the owner is always the existing authenticated user.
create function public.save_workspace_collection(expected_version integer,collection_items jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid();next_version integer;
begin
 if owner is null then raise insufficient_privilege;end if;
 if expected_version is null or expected_version<0 or not public.valid_workspace_items(collection_items) then raise exception 'Invalid workspace';end if;
 if expected_version=0 then insert into public.workspace_collections(user_id,version,items) values(owner,1,collection_items) on conflict do nothing returning version into next_version;
 else update public.workspace_collections set items=collection_items,version=version+1 where user_id=owner and version=expected_version returning version into next_version;end if;
 if next_version is null then raise sqlstate 'PT409' using message='Workspace revision conflict';end if;
 return next_version;
end;$$;
revoke all on function public.save_workspace_collection(integer,jsonb) from public,anon;
grant execute on function public.save_workspace_collection(integer,jsonb) to authenticated;
commit;
