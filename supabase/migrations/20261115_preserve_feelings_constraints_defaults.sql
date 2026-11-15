-- Non-destructive schema fidelity for feelings source app.
-- Apply only after the function migration. All existing row values are preserved.
-- Never run DELETE/TRUNCATE or rewrite existing user data.
begin;

-- Existing values remain untouched; only future INSERT defaults are applied.
alter table mastersite_feelings."participants" alter column "id" set default gen_random_uuid();
alter table mastersite_feelings."participants" alter column "created_at" set default now();
alter table mastersite_feelings."participants" alter column "team_size" set default 1;
alter table mastersite_feelings."participants" alter column "members" set default '[]'::jsonb;
alter table mastersite_feelings."profiles" alter column "approved" set default false;
alter table mastersite_feelings."profiles" alter column "role" set default 'viewer'::text;
alter table mastersite_feelings."profiles" alter column "created_at" set default now();
alter table mastersite_feelings."profiles" alter column "is_creator" set default false;
alter table mastersite_feelings."profiles" alter column "access_status" set default 'pending'::text;
alter table mastersite_feelings."site_settings" alter column "hero" set default jsonb_build_object('titleLine1', 'FEELINGS', 'titleLine2', 'TURNIER', 'lead', 'Drei KDA-Runden. Automatische Gruppen. Eine globale K.O.-Stage. Ein Champion.', 'tags', jsonb_build_array('VALORANT VIBES', 'STREAM MODE', 'KDA TRACKING'));
alter table mastersite_feelings."site_settings" alter column "updated_at" set default now();
alter table mastersite_feelings."site_settings" alter column "background" set default '{"fit": "cover", "url": "", "path": "", "enabled": false, "opacity": 42, "position": "center top", "hideDefaultFloral": false}'::jsonb;
alter table mastersite_feelings."site_settings" alter column "scoring" set default jsonb_build_object('kill', 1, 'assist', 1, 'death', 1.5, 'positiveBonus', 3, 'negativePenalty', 3);
alter table mastersite_feelings."site_settings" alter column "competition" set default jsonb_build_object('teamSize', 1, 'winPoints', 3, 'drawPoints', 1, 'lossPoints', 0);
alter table mastersite_feelings."tournament_state" alter column "payload" set default '{}'::jsonb;
alter table mastersite_feelings."tournament_state" alter column "updated_at" set default now();
-- Identity sequences are aligned beyond the highest preserved value.

-- Mirror source CHECK / UNIQUE and internal FK constraints (no cross-app auth.users FKs).
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='participants' and cc.conname='participants_name_check') then
   alter table mastersite_feelings."participants" add constraint "participants_name_check" CHECK (char_length(TRIM(BOTH FROM name)) >= 2 AND char_length(TRIM(BOTH FROM name)) <= 40);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='participants' and cc.conname='participants_team_size_check') then
   alter table mastersite_feelings."participants" add constraint "participants_team_size_check" CHECK (team_size >= 1 AND team_size <= 5);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='profiles' and cc.conname='profiles_access_status_check') then
   alter table mastersite_feelings."profiles" add constraint "profiles_access_status_check" CHECK (access_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='profiles' and cc.conname='profiles_role_check') then
   alter table mastersite_feelings."profiles" add constraint "profiles_role_check" CHECK (role = ANY (ARRAY['viewer'::text, 'admin'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='site_settings' and cc.conname='site_settings_id_check') then
   alter table mastersite_feelings."site_settings" add constraint "site_settings_id_check" CHECK (id = 1);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_feelings' and tbl.relname='tournament_state' and cc.conname='tournament_state_id_check') then
   alter table mastersite_feelings."tournament_state" add constraint "tournament_state_id_check" CHECK (id = 1);
 end if;
end $constraint$;

-- Secondary indexes (CREATE IF NOT EXISTS).
CREATE UNIQUE INDEX IF NOT EXISTS participants_name_unique_ci ON mastersite_feelings.participants USING btree (lower(TRIM(BOTH FROM name)));
CREATE UNIQUE INDEX IF NOT EXISTS participants_pkey ON mastersite_feelings.participants USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_pkey ON mastersite_feelings.profiles USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS site_settings_pkey ON mastersite_feelings.site_settings USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS tournament_state_pkey ON mastersite_feelings.tournament_state USING btree (id);
-- App-specific triggers (not the old auth.users triggers).

commit;
