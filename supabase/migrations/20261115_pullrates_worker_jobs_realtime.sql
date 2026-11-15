-- MasterSite Pullrates background service: source project parity.
-- Already applied once in target. Idempotent reapply; never store plaintext tokens in code.
-- IMPORTANT: Copy source data and take private append-only backups before applying.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema mastersite_pullrates to service_role;
grant usage on schema mastersite_pullrates_private to service_role;
grant execute on function mastersite_pullrates.pull_market_worker(text,jsonb) to service_role;

do $worker$
declare new_token text;
begin
 if not exists(select 1 from vault.secrets where name='mastersite_pullrates_market_worker_token') then
  new_token:=encode(extensions.gen_random_bytes(32),'hex');
  perform vault.create_secret(
    new_token,'mastersite_pullrates_market_worker_token',
    'Encrypted per-project Cardmarket worker token; never share or commit.'
  );
  update mastersite_pullrates.market_worker_state
   set token_hash=encode(extensions.digest(new_token,'sha256'),'hex'),
       running_until=null
   where id=true;
  if not found then raise exception 'Missing market worker state row'; end if;
 end if;
end $worker$;

select cron.schedule('mastersite-pullrates-cardmarket-refresh','*/30 * * * *',$job$
 select net.http_post(
 url:='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-cardmarket-refresh',
 headers:=jsonb_build_object('Content-Type','application/json',
  'x-price-worker-token',(select decrypted_secret from vault.decrypted_secrets where name='mastersite_pullrates_market_worker_token')),
 body:='{}'::jsonb,timeout_milliseconds:=120000
);
$job$);

select cron.schedule('mastersite-pullrates-chat-expiry','* * * * *',$job$
 select mastersite_pullrates_private.chat_purge();
$job$);

do $replication$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='mastersite_pullrates' and tablename='card_details') then
  alter publication supabase_realtime add table mastersite_pullrates.card_details;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='mastersite_pullrates' and tablename='card_images') then
  alter publication supabase_realtime add table mastersite_pullrates.card_images;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='mastersite_pullrates' and tablename='pull_rates') then
  alter publication supabase_realtime add table mastersite_pullrates.pull_rates;
 end if;
end $replication$;
