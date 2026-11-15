-- Bereits in Supabase pokemon-hit-tracker (entbtqtyxhbozjdbdvns) angelegt.
-- Diese Datei dokumentiert die bestehende Änderung. Nicht erneut blind ausführen.
-- Benutzer und Anwendungsdaten wurden dabei NICHT migriert.
begin;
create schema if not exists mastersite_feelings;
create schema if not exists mastersite_pullrates;
revoke all on schema mastersite_feelings from public, anon, authenticated;
revoke all on schema mastersite_pullrates from public, anon, authenticated;

create table if not exists public.master_site_apps (
  slug text primary key check (slug ~ '^[a-z0-9-]+$'),
  title text not null,
  description text not null,
  icon text not null,
  app_path text not null check (app_path like 'apps/%/' and app_path not like '%..%'),
  repository_url text not null,
  display_order integer not null,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.master_site_apps enable row level security;
revoke all on table public.master_site_apps from public, anon, authenticated;
grant select on table public.master_site_apps to anon, authenticated;
create policy master_site_apps_public_read
  on public.master_site_apps for select to anon, authenticated
  using (is_active = true);
insert into public.master_site_apps
  (slug,title,description,icon,app_path,repository_url,display_order,is_active)
values
 ('pokemon-hit-tracker','Pokémon Hit Tracker','Öffnungen, garantierte Hits und persönliche Auswertungen.','target','apps/pokemon-hit-tracker/','https://github.com/Furfural0405/pokemon-hit-tracker',1,true),
 ('pokemon-pullrates','Pokémon Pullrates','Kartensammlung, Pullraten und persönliche Übersichten.','cards','apps/pokemon-pullrates/','https://github.com/Furfural0405/pokemon-pullrates',2,true),
 ('feelings-turnier','Feelings-Turnier','Teilnehmer, Spielrunden und Turnierverwaltung.','trophy','apps/feelings-turnier/','https://github.com/Furfural0405/Feelings-Turnier',3,true)
on conflict (slug) do update
set title=excluded.title,description=excluded.description,icon=excluded.icon,
    app_path=excluded.app_path,repository_url=excluded.repository_url,
    display_order=excluded.display_order,is_active=excluded.is_active,updated_at=now();
commit;
