-- Protected, read/write only by the Postgres owner; NOT exposed by Data API.
-- Temporary migration staging. Contains personal data and password hashes.
-- Never grant anon/authenticated/service_role SELECT or publish contents.
begin;
create schema if not exists mastersite_migration;
revoke all on schema mastersite_migration from public, anon, authenticated, service_role;

create table if not exists mastersite_migration.data_snapshots (
  app_slug text not null check(app_slug in ('feelings-turnier','pokemon-pullrates')),
  source_ref text not null,
  source_name text not null,
  captured_at timestamptz not null default now(),
  row_count integer not null check(row_count>=0),
  data_json jsonb not null check(jsonb_typeof(data_json)='array'),
  md5_checksum text not null,
  primary key (app_slug, source_name)
);
create table if not exists mastersite_migration.auth_snapshots (
  app_slug text not null check(app_slug in ('feelings-turnier','pokemon-pullrates')),
  source_ref text not null,
  source_name text not null check(source_name in ('auth.users','auth.identities')),
  captured_at timestamptz not null default now(),
  row_count integer not null check(row_count>=0),
  data_json jsonb not null check(jsonb_typeof(data_json)='array'),
  md5_checksum text not null,
  primary key (app_slug,source_name)
);

alter table mastersite_migration.data_snapshots enable row level security;
alter table mastersite_migration.auth_snapshots enable row level security;
revoke all on mastersite_migration.data_snapshots from public, anon, authenticated, service_role;
revoke all on mastersite_migration.auth_snapshots from public, anon, authenticated, service_role;
commit;
