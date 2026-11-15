-- Draft RLS policies for the staged mirror tables. The schemas remain unexposed
-- and their USAGE is denied to anon/authenticated until both JWT issuers are
-- registered and tested; no rows are changed by this migration.
begin;
create or replace function mastersite_feelings_private.correct_issuer()
returns boolean language sql stable security invoker set search_path=''
as $$
select auth.jwt()->>'iss'='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-feelings-auth'
  and auth.jwt()->>'app_id'='feelings-turnier';
$$;
create or replace function mastersite_pullrates_private.correct_issuer()
returns boolean language sql stable security invoker set search_path=''
as $$
select auth.jwt()->>'iss'='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-pullrates-auth'
  and auth.jwt()->>'app_id'='pokemon-pullrates';
$$;
revoke all on function mastersite_feelings_private.correct_issuer() from PUBLIC,anon,authenticated,service_role;
revoke all on function mastersite_pullrates_private.correct_issuer() from PUBLIC,anon,authenticated,service_role;
-- Feelings private user profiles: self sees own row, creator can manage non-creator rows
create policy mastersite_feelings_profile_self_select on mastersite_feelings.profiles
 for select to authenticated using ((select mastersite_feelings_private.correct_issuer()) and id=(select auth.uid()));
create policy mastersite_feelings_profile_creator_select on mastersite_feelings.profiles
 for select to authenticated using ((select mastersite_feelings_private.is_creator_admin()));
create policy mastersite_feelings_profile_creator_update on mastersite_feelings.profiles
 for update to authenticated using ((select mastersite_feelings_private.is_creator_admin()) and not is_creator)
 with check ((select mastersite_feelings_private.is_creator_admin()) and not is_creator);
-- Public site settings are safe to read; only approved Feelings admins may change them
create policy mastersite_feelings_settings_read on mastersite_feelings.site_settings
 for select to anon,authenticated using (id=1);
create policy mastersite_feelings_settings_admin_update on mastersite_feelings.site_settings
 for update to authenticated using (id=1 and (select mastersite_feelings_private.is_approved_admin()))
 with check (id=1 and (select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_settings_admin_insert on mastersite_feelings.site_settings
 for insert to authenticated with check (id=1 and (select mastersite_feelings_private.is_approved_admin()));
-- Tournament state and participant roster must not leak to unrelated auth issuers
create policy mastersite_feelings_participant_admin_select on mastersite_feelings.participants
 for select to authenticated using ((select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_participant_admin_update on mastersite_feelings.participants
 for update to authenticated using ((select mastersite_feelings_private.is_approved_admin()))
 with check ((select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_participant_admin_delete on mastersite_feelings.participants
 for delete to authenticated using ((select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_tournament_admin_select on mastersite_feelings.tournament_state
 for select to authenticated using ((select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_tournament_admin_insert on mastersite_feelings.tournament_state
 for insert to authenticated with check (id=1 and (select mastersite_feelings_private.is_approved_admin()));
create policy mastersite_feelings_tournament_admin_update on mastersite_feelings.tournament_state
 for update to authenticated using (id=1 and (select mastersite_feelings_private.is_approved_admin()))
 with check (id=1 and (select mastersite_feelings_private.is_approved_admin()));
-- Pullrates original public read-only catalogs; private cards/lists/chat stay RPC-only
create policy mastersite_pullrates_card_details_public on mastersite_pullrates.card_details
 for select to anon,authenticated using (true);
create policy mastersite_pullrates_card_images_public on mastersite_pullrates.card_images
 for select to anon,authenticated using (true);
create policy mastersite_pullrates_prices_public on mastersite_pullrates.cardmarket_prices
 for select to anon,authenticated using (true);
create policy mastersite_pullrates_rates_public on mastersite_pullrates.pull_rates
 for select to anon,authenticated using (true);
create policy mastersite_pullrates_catalog_owner on mastersite_pullrates.cardmarket_catalog
 for select to authenticated using
  ((select mastersite_pullrates_private.correct_issuer())
   and exists (select 1 from mastersite_pullrates.profiles p where p.id=(select auth.uid()) and p.role='admin' and p.status='approved'));
-- Protect remaining Pullrates tables with the current default-deny RLS (no direct policies).
-- Keep all application and migration schema USAGE privileges revoked.
commit;
