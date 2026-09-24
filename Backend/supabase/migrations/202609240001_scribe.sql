begin;
create table public.scribe_encounters (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  version integer not null default 1 check(version > 0),
  payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=1500000),
  updated_at timestamptz not null default now(),
  primary key(user_id,id)
);
alter table public.scribe_encounters enable row level security;
create policy own_notes_read on public.scribe_encounters for select to authenticated using ((select auth.uid())=user_id);
create policy own_notes_insert on public.scribe_encounters for insert to authenticated with check ((select auth.uid())=user_id);
create policy own_notes_update on public.scribe_encounters for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy own_notes_delete on public.scribe_encounters for delete to authenticated using ((select auth.uid())=user_id);
revoke all on public.scribe_encounters from anon,authenticated;
grant select,delete on public.scribe_encounters to authenticated;
-- Mutations use an atomic compare-and-swap RPC. Its definer checks auth.uid().
create or replace function public.save_scribe_encounter(encounter_id uuid,expected_version integer,encounter_payload jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid(); next_version integer;
begin
  if owner is null then raise insufficient_privilege; end if;
  if expected_version<0 or expected_version is null or encounter_payload is null or lower(encounter_payload->>'id') is distinct from encounter_id::text or jsonb_typeof(encounter_payload->'patients') is distinct from 'array' then raise exception 'Invalid encounter'; end if;
  if expected_version=0 then
    insert into public.scribe_encounters(user_id,id,payload) values(owner,encounter_id,encounter_payload) on conflict do nothing returning version into next_version;
  else
    update public.scribe_encounters set payload=encounter_payload,version=version+1,updated_at=now()
    where user_id=owner and id=encounter_id and version=expected_version returning version into next_version;
  end if;
  if next_version is null then raise sqlstate 'PT409' using message='Cloud revision conflict'; end if;
  return next_version;
end $$;
revoke all on function public.save_scribe_encounter(uuid,integer,jsonb) from public,anon;
grant execute on function public.save_scribe_encounter(uuid,integer,jsonb) to authenticated;
create table public.scribe_ai_access(user_id uuid primary key references auth.users(id) on delete cascade,enabled boolean not null default false,daily_limit integer not null default 120 check(daily_limit between 1 and 1000));
create table public.scribe_ai_usage(user_id uuid not null references auth.users(id) on delete cascade,day date not null,used integer not null default 0,primary key(user_id,day));
alter table public.scribe_ai_access enable row level security;
alter table public.scribe_ai_usage enable row level security;
revoke all on public.scribe_ai_access,public.scribe_ai_usage from public,anon,authenticated;
create or replace function public.consume_scribe_quota() returns boolean language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid(); cap integer; count_now integer;
begin
  if owner is null then return false; end if;
  select daily_limit into cap from public.scribe_ai_access where user_id=owner and enabled=true;
  if cap is null then return false; end if;
  insert into public.scribe_ai_usage(user_id,day,used) values(owner,(now() at time zone 'UTC')::date,1)
  on conflict(user_id,day) do update set used=public.scribe_ai_usage.used+1 where public.scribe_ai_usage.used<cap
  returning used into count_now;
  return count_now is not null;
end $$;
revoke all on function public.consume_scribe_quota() from public,anon;
grant execute on function public.consume_scribe_quota() to authenticated;
commit;
