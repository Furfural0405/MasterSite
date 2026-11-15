-- MasterSite validation: use after migrations, before any frontend cutover.
-- READ ONLY; no user rows are modified or removed.
select 'feelings_profiles' as check_name, count(*)::bigint as observed from mastersite_feelings.profiles
union all select 'feelings_participants',count(*) from mastersite_feelings.participants
union all select 'feelings_site_settings',count(*) from mastersite_feelings.site_settings
union all select 'feelings_tournament_state',count(*) from mastersite_feelings.tournament_state
union all select 'pullrates_profiles',count(*) from mastersite_pullrates.profiles
union all select 'pullrates_lists',count(*) from mastersite_pullrates.lists
union all select 'pullrates_chat_messages',count(*) from mastersite_pullrates.chat_messages
union all select 'pullrates_inventory_requests',count(*) from mastersite_pullrates.inventory_requests
union all select 'pullrates_card_images_metadata',count(*) from mastersite_pullrates.card_images
union all select 'feelings_login_accounts',count(*) from mastersite_feelings_auth."user"
union all select 'feelings_password_hashes',count(*) from mastersite_feelings_auth."account" where "providerId"='credential' and "password" like '$2%'
union all select 'pullrates_login_accounts',count(*) from mastersite_pullrates_auth."user"
union all select 'pullrates_password_hashes',count(*) from mastersite_pullrates_auth."account" where "providerId"='credential' and "password" like '$2%'
union all select 'storage_card_images',count(*) from storage.objects where bucket_id='card-images'
order by check_name;

-- Any result >0 is an access-control regression. Do not expose private snapshots.
select n.nspname as private_schema,
count(*) filter(where has_table_privilege('anon',c.oid,'SELECT'))::int as anon_readable_tables,
count(*) filter(where has_table_privilege('authenticated',c.oid,'SELECT'))::int as authenticated_readable_tables,
count(*) filter(where not c.relrowsecurity)::int as rls_disabled_tables
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname in
 ('mastersite_feelings_auth','mastersite_pullrates_auth','mastersite_migration','mastersite_preservation')
group by n.nspname order by n.nspname;

-- Cryptographic row-set fingerprints for exact comparisons with the ORIGINAL archives.
-- MD5 is used only to detect changes, not for passwords or authentication.
select 'feelings.profiles' as table_name,
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_feelings.profiles t),'[]'::jsonb)::text) as digest
union all select 'feelings.participants',
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_feelings.participants t),'[]'::jsonb)::text)
union all select 'feelings.tournament_state',
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_feelings.tournament_state t),'[]'::jsonb)::text)
union all select 'pullrates.profiles',
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_pullrates.profiles t),'[]'::jsonb)::text)
union all select 'pullrates.lists',
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_pullrates.lists t),'[]'::jsonb)::text)
union all select 'pullrates.chat_messages',
 md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from mastersite_pullrates.chat_messages t),'[]'::jsonb)::text)
order by table_name;
