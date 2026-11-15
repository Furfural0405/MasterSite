-- API-ready, least-privilege grants. RLS policies are installed before granting access.
-- Auth and preservation schemas remain fully inaccessible to anon/authenticated.
begin;
grant usage on schema mastersite_feelings to anon,authenticated;
grant usage on schema mastersite_feelings_private to authenticated;
grant usage on schema mastersite_pullrates to anon,authenticated;
grant usage on schema mastersite_pullrates_private to anon,authenticated;
grant select on mastersite_feelings.site_settings to anon,authenticated;
grant select on mastersite_feelings.profiles to authenticated;
grant select on mastersite_feelings.participants to authenticated;
grant update,delete on mastersite_feelings.participants to authenticated;
grant select,insert,update on mastersite_feelings.tournament_state to authenticated;
grant update,insert on mastersite_feelings.site_settings to authenticated;
grant update on mastersite_feelings.profiles to authenticated;
grant select on mastersite_pullrates.card_details to anon,authenticated;
grant select on mastersite_pullrates.card_images to anon,authenticated;
grant select on mastersite_pullrates.cardmarket_prices to anon,authenticated;
grant select on mastersite_pullrates.pull_rates to anon,authenticated;
grant select on mastersite_pullrates.cardmarket_catalog to authenticated;
-- Do not grant direct SELECT/INSERT/UPDATE/DELETE on Pullrates user profile, lists,
-- inventory, chat, or any account/password table; private SEC DEFINER RPCs retain access control.
commit;
