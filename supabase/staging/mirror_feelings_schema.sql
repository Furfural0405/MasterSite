-- ARCHIVE/IMPORT-STAGING ONLY. DO NOT SWITCH EXISTING APPS TO THESE TABLES.
-- Derived from live Feelings-Turnier schema audit (2026-11-15).
-- Private mirror: columns and PKs; existing security/functions/triggers are not migrated here.
begin;
create schema if not exists mastersite_feelings;
revoke all on schema mastersite_feelings from public, anon, authenticated, service_role;

create table if not exists mastersite_feelings.profiles (
  id uuid primary key,
  email text not null,
  approved boolean not null,
  role text not null,
  created_at timestamptz not null,
  is_creator boolean not null,
  access_status text not null
);
create table if not exists mastersite_feelings.participants (
  id uuid primary key,
  name text not null,
  submitted_by uuid,
  created_at timestamptz not null,
  team_size smallint not null,
  members jsonb not null
);
create table if not exists mastersite_feelings.site_settings (
  id smallint primary key,
  hero jsonb not null,
  updated_at timestamptz not null,
  updated_by uuid,
  background jsonb not null,
  scoring jsonb not null,
  competition jsonb not null
);
create table if not exists mastersite_feelings.tournament_state (
  id smallint primary key,
  payload jsonb not null,
  updated_at timestamptz not null,
  updated_by uuid
);
alter table mastersite_feelings.profiles enable row level security;
alter table mastersite_feelings.participants enable row level security;
alter table mastersite_feelings.site_settings enable row level security;
alter table mastersite_feelings.tournament_state enable row level security;
revoke all on all tables in schema mastersite_feelings from public, anon, authenticated, service_role;
commit;
