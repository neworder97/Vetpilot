begin;
create table public.medication_collections (
 user_id uuid primary key references auth.users(id) on delete cascade,
 version integer not null check(version>0),
 items jsonb not null check(jsonb_typeof(items)='array' and jsonb_array_length(items)<=500 and octet_length(items::text)<=2000000),
 updated_at timestamptz not null default now()
);
alter table public.medication_collections enable row level security;
create policy own_medication_read on public.medication_collections for select to authenticated using ((select auth.uid())=user_id);
revoke all on public.medication_collections from public,anon,authenticated;
grant select on public.medication_collections to authenticated;
-- Custom medication records share the iOS CustomMedicationDefinition schema.
-- Direct writes are revoked to enforce compare-and-swap; the definer is restricted to auth.uid().
-- Only this compare-and-swap operation writes collections. Ownership comes from JWT, never input.
create function public.save_medication_collection(expected_version integer,collection_items jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid(); next_version integer;
begin
 if owner is null then raise insufficient_privilege; end if;
 if expected_version is null or expected_version<0 or collection_items is null or jsonb_typeof(collection_items)<>'array' then raise exception 'Invalid collection';end if;
 if jsonb_array_length(collection_items)>500 or octet_length(collection_items::text)>2000000 then raise exception 'Collection too large';end if;
 if exists(select 1 from jsonb_array_elements(collection_items) i where jsonb_typeof(i)<>'object' or i->>'id' is null or (i->>'id')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'Invalid item identity';end if;
 if (select count(distinct lower(i->>'id')) from jsonb_array_elements(collection_items) i)<>jsonb_array_length(collection_items) then raise exception 'Duplicate items';end if;
 if expected_version=0 then
  insert into public.medication_collections(user_id,version,items) values(owner,1,collection_items) on conflict do nothing returning version into next_version;
 else
  update public.medication_collections set items=collection_items,version=version+1,updated_at=now() where user_id=owner and version=expected_version returning version into next_version;
 end if;
 if next_version is null then raise sqlstate 'PT409' using message='Cloud revision conflict';end if;
 return next_version;
end $$;
revoke all on function public.save_medication_collection(integer,jsonb) from public,anon;
grant execute on function public.save_medication_collection(integer,jsonb) to authenticated;
commit;
