-- MasterSite preservation: append-only archives in the ORIGINAL Supabase projects.
-- The archives contain real user data and password hashes. Do not expose these schemas.
begin;
create schema if not exists mastersite_preservation;
revoke all on schema mastersite_preservation from public, anon, authenticated, service_role;
create table if not exists mastersite_preservation.archives(
  archive_id uuid not null,
  source_schema text not null,
  source_table text not null,
  captured_at timestamptz not null default now(),
  row_count integer not null,
  digest_md5 text not null,
  rows jsonb not null,
  primary key(archive_id, source_schema, source_table),
  check(row_count >= 0),
  check(jsonb_typeof(rows) = 'array')
);
alter table mastersite_preservation.archives enable row level security;
revoke all on all tables in schema mastersite_preservation from public, anon, authenticated, service_role;
commit;