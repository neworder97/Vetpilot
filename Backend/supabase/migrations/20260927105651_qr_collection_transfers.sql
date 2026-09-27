-- QR snapshots are separate from existing account collections.
create table public.qr_transfers (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 collection text not null check(collection in ('clinic','cytology')),
 token_hash text not null unique check(token_hash ~ '^[0-9a-f]{64}$'),
 payload jsonb not null check(octet_length(payload::text)<=15000000),
 title text not null check(length(title)<=200),
 item_count integer not null check(item_count between 1 and 1000),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '24 hours',
 check(expires_at>created_at and expires_at<=created_at+interval '24 hours')
);
create index qr_transfers_owner_expiry on public.qr_transfers(owner_id,expires_at);
create index qr_transfers_expiry on public.qr_transfers(expires_at);
alter table public.qr_transfers enable row level security;
revoke all on public.qr_transfers from public,anon,authenticated;
grant select,insert,delete on public.qr_transfers to service_role;
-- Only the authenticated edge service has access. Atomic per-owner quota.
create function public.create_qr_transfer(transfer_owner uuid,transfer_collection text,transfer_hash text,transfer_payload jsonb)
returns setof public.qr_transfers language plpgsql security invoker set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(transfer_owner::text,92701));
 delete from public.qr_transfers where owner_id=transfer_owner and expires_at<=now();
 if(select count(*) from public.qr_transfers where owner_id=transfer_owner)>=10 then raise exception 'QR_ACTIVE_LIMIT';end if;
 if transfer_payload->>'format' is distinct from 'VetPilot.MyClinic' or transfer_payload->>'schemaVersion' is distinct from '1' or jsonb_typeof(transfer_payload->'items') is distinct from 'array' then raise exception 'Invalid transfer package';end if;
 return query insert into public.qr_transfers(owner_id,collection,token_hash,payload,title,item_count)
 values(transfer_owner,transfer_collection,transfer_hash,transfer_payload,left(transfer_payload->'items'->0->>'title',200),jsonb_array_length(transfer_payload->'items')) returning *;
end;
$$;
revoke all on function public.create_qr_transfer(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.create_qr_transfer(uuid,text,text,jsonb) to service_role;
select cron.schedule('vetpilot-expired-qr-transfers','17 * * * *',$$delete from public.qr_transfers where expires_at<=now()$$);
