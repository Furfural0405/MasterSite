-- MasterSite: isolated Better Auth v1.7 core tables and imported credentials.
-- No change to original Supabase Auth or existing app APIs.
-- No SELECT/USAGE granted to anon, authenticated or service_role.
-- Users and bcrypt password hashes are imported from non-exposed snapshots,
-- preserving original UUIDs as text IDs and existing confirmation state.
begin;

do $$
declare schema_name text;
begin
  foreach schema_name in array array['mastersite_feelings_auth','mastersite_pullrates_auth']
  loop
    execute format('create schema if not exists %I',schema_name);
    execute format('revoke all on schema %I from public, anon, authenticated, service_role',schema_name);
    execute format($f$
      create table if not exists %I."user" (
        "id" text primary key,
        "name" text not null,
        "email" text not null unique,
        "emailVerified" boolean not null default false,
        "image" text,
        "createdAt" timestamptz not null default now(),
        "updatedAt" timestamptz not null default now()
      )$f$,schema_name);
    execute format($f$
      create table if not exists %I."session" (
        "id" text primary key,
        "expiresAt" timestamptz not null,
        "token" text not null unique,
        "createdAt" timestamptz not null default now(),
        "updatedAt" timestamptz not null default now(),
        "ipAddress" text,
        "userAgent" text,
        "userId" text not null references %I."user"("id") on delete cascade
      )$f$,schema_name,schema_name);
    execute format($f$
      create table if not exists %I."account" (
        "id" text primary key,
        "accountId" text not null,
        "providerId" text not null,
        "userId" text not null references %I."user"("id") on delete cascade,
        "accessToken" text,
        "refreshToken" text,
        "idToken" text,
        "accessTokenExpiresAt" timestamptz,
        "refreshTokenExpiresAt" timestamptz,
        "scope" text,
        "password" text,
        "createdAt" timestamptz not null default now(),
        "updatedAt" timestamptz not null default now()
      )$f$,schema_name,schema_name);
    execute format('create index if not exists %I on %I."session"("userId")',schema_name||'_session_user_idx',schema_name);
    execute format('create index if not exists %I on %I."account"("userId")',schema_name||'_account_user_idx',schema_name);
    execute format('create unique index if not exists %I on %I."account"("providerId","accountId")',schema_name||'_account_provider_uidx',schema_name);
    execute format($f$
      create table if not exists %I."verification" (
        "id" text primary key,
        "identifier" text not null,
        "value" text not null,
        "expiresAt" timestamptz not null,
        "createdAt" timestamptz not null default now(),
        "updatedAt" timestamptz not null default now()
      )$f$,schema_name);
    execute format('create index if not exists %I on %I."verification"("identifier")',schema_name||'_verification_identifier_idx',schema_name);
    execute format($f$
      create table if not exists %I."jwks" (
        "id" text primary key,
        "publicKey" text not null,
        "privateKey" text not null,
        "alg" text,
        "crv" text,
        "createdAt" timestamptz not null default now(),
        "expiresAt" timestamptz
      )$f$,schema_name);
    execute format('alter table %I."user" enable row level security',schema_name);
    execute format('alter table %I."session" enable row level security',schema_name);
    execute format('alter table %I."account" enable row level security',schema_name);
    execute format('alter table %I."verification" enable row level security',schema_name);
    execute format('alter table %I."jwks" enable row level security',schema_name);
    execute format('revoke all on all tables in schema %I from public, anon, authenticated, service_role',schema_name);
  end loop;
end
$$;

-- Preserve original Supabase auth UUIDs; use two distinct schemas to avoid email collisions.
insert into mastersite_feelings_auth."user"
 ("id","name","email","emailVerified","createdAt","updatedAt")
select
  obj->>'id',
  split_part(obj->>'email','@',1),
  obj->>'email',
  (obj->>'email_confirmed_at') is not null,
  coalesce((obj->>'created_at')::timestamptz,now()),
  coalesce((obj->>'updated_at')::timestamptz,now())
from mastersite_migration.auth_snapshots snap,
lateral jsonb_array_elements(snap.data_json) obj
where snap.app_slug='feelings-turnier' and snap.source_name='auth.users'
on conflict("id") do nothing;

insert into mastersite_pullrates_auth."user"
 ("id","name","email","emailVerified","createdAt","updatedAt")
select
  obj->>'id',
  split_part(obj->>'email','@',1),
  obj->>'email',
  (obj->>'email_confirmed_at') is not null,
  coalesce((obj->>'created_at')::timestamptz,now()),
  coalesce((obj->>'updated_at')::timestamptz,now())
from mastersite_migration.auth_snapshots snap,
lateral jsonb_array_elements(snap.data_json) obj
where snap.app_slug='pokemon-pullrates' and snap.source_name='auth.users'
on conflict("id") do nothing;

insert into mastersite_feelings_auth."account"
 ("id","accountId","providerId","userId","password","createdAt","updatedAt")
select
  gen_random_uuid()::text,
  obj->>'id','credential',obj->>'id',
  obj->>'encrypted_password',
  coalesce((obj->>'created_at')::timestamptz,now()),
  coalesce((obj->>'updated_at')::timestamptz,now())
from mastersite_migration.auth_snapshots snap,
lateral jsonb_array_elements(snap.data_json) obj
where snap.app_slug='feelings-turnier' and snap.source_name='auth.users'
and left(obj->>'encrypted_password',3) in ('$2a','$2b','$2y')
on conflict ("providerId","accountId") do nothing;

insert into mastersite_pullrates_auth."account"
 ("id","accountId","providerId","userId","password","createdAt","updatedAt")
select
  gen_random_uuid()::text,
  obj->>'id','credential',obj->>'id',
  obj->>'encrypted_password',
  coalesce((obj->>'created_at')::timestamptz,now()),
  coalesce((obj->>'updated_at')::timestamptz,now())
from mastersite_migration.auth_snapshots snap,
lateral jsonb_array_elements(snap.data_json) obj
where snap.app_slug='pokemon-pullrates' and snap.source_name='auth.users'
and left(obj->>'encrypted_password',3) in ('$2a','$2b','$2y')
on conflict ("providerId","accountId") do nothing;

do $$
declare f_u int; f_a int; p_u int; p_a int;
begin
  select count(*) into f_u from mastersite_feelings_auth."user";
  select count(*) into f_a from mastersite_feelings_auth."account" where "providerId"='credential';
  select count(*) into p_u from mastersite_pullrates_auth."user";
  select count(*) into p_a from mastersite_pullrates_auth."account" where "providerId"='credential';
  if (f_u,f_a,p_u,p_a) is distinct from (2,2,4,4) then
    raise exception 'Unexpected migrated account counts; rolled back';
  end if;
end $$;
commit;