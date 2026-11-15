-- Issuer gates for every authenticated SECURITY DEFINER RPC entry point.
-- Prevent a token issued to another MasterSite app from accessing Pullrates profiles.
begin;
create or replace function mastersite_pullrates_private.issuer_allowed()
returns boolean
language sql stable security invoker set search_path=''
as $guard$
select (auth.jwt()->>'iss') = 'https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-pullrates-auth'
 and (auth.jwt()->>'app_id') = 'pokemon-pullrates'
 and (auth.jwt()->>'role') = 'authenticated'
 and (auth.jwt()->>'sub') is not null;
$guard$;
revoke all on function mastersite_pullrates_private.issuer_allowed() from PUBLIC, anon, authenticated, service_role;
set local check_function_bodies=off;

-- Protected entry point application
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; rec record; result jsonb; item jsonb;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if operation='public-counts' then
  select to_jsonb(show_public_counts) into result from mastersite_pullrates.settings where id=true;
  if result='true'::jsonb or exists(select 1 from mastersite_pullrates.profiles where id=auth.uid() and role='admin' and status='approved') then
   return mastersite_pullrates_private.community_counts() || jsonb_build_object('enabled',result);
  end if;
  return jsonb_build_object('enabled',false,'counts',null,'boosters',null);
 end if;
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 -- Serializes publication and prevents lost updates across concurrent contributors.
 perform pg_advisory_xact_lock(3046103);
 select * into me from mastersite_pullrates.profiles where id=auth.uid() for update;
 if not found then raise exception 'PROFILE_MISSING'; end if;
 if operation='me' then
  return jsonb_build_object('id',me.id,'email',me.email,'role',me.role,'status',me.status,
   'counts',case when me.status='approved' then me.counts else '{}'::jsonb end,
   'version',me.version,'snapshot_version',me.snapshot_version);
 end if;
 if me.status<>'approved' then raise exception 'NOT_APPROVED'; end if;
 if operation='save' then
  perform mastersite_pullrates_private.validate_counts(payload->'counts');
  if (payload->>'version')::integer is distinct from me.version then raise exception 'VERSION_CONFLICT'; end if;
  insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,me.id,'save',to_jsonb(me));
  update mastersite_pullrates.profiles set counts=payload->'counts',version=version+1,updated_at=now() where id=me.id;
  if me.role='admin' then perform mastersite_pullrates_private.refresh_rates(); end if;
  return jsonb_build_object('version',me.version+1);
 end if;
 if operation='export-own' then
  return jsonb_build_object('format','pokemon-pullrates','schema_version',1,'set','30thC-zh-Hans',
   'scope','own','created_at',now(),'counts',me.counts);
 end if;
 if me.role<>'admin' then raise exception 'ADMIN_REQUIRED'; end if;
 if operation='archive-rejected' then
  if me.id<>'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid then raise exception 'ADMIN_REQUIRED'; end if;
  select * into target from mastersite_pullrates.profiles where id=(payload->>'user_id')::uuid for update;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if target.role='admin' or target.status<>'rejected' then raise exception 'ONLY_REJECTED_USERS'; end if;
  if (payload->>'version')::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
  insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,target.id,'archive-rejected',to_jsonb(target));
  update mastersite_pullrates.profiles set request_archived=true,version=version+1,updated_at=now() where id=target.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation='set-count-visibility' then
  if me.id<>'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid then raise exception 'ADMIN_REQUIRED'; end if;
  if jsonb_typeof(payload->'enabled') is distinct from 'boolean' then raise exception 'INVALID_SETTING'; end if;
  update mastersite_pullrates.settings set show_public_counts=(payload->>'enabled')::boolean where id=true;
  return jsonb_build_object('ok',true);
 end if;
 if operation='users' then
  select coalesce(jsonb_agg(to_jsonb(p) order by p.email),'[]'::jsonb) into result from mastersite_pullrates.profiles p;
  return result;
 end if;
 if operation in ('approve','reject','include','exclude') then
  select * into target from mastersite_pullrates.profiles where id=(payload->>'user_id')::uuid for update;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if target.role='admin' then raise exception 'ADMIN_PROTECTED'; end if;
  if (payload->>'version')::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
  if operation='include' and target.status<>'approved' then raise exception 'NOT_APPROVED'; end if;
  insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,target.id,operation,to_jsonb(target));
  if operation='approve' then update mastersite_pullrates.profiles set status='approved' where id=target.id; end if;
  if operation='reject' then update mastersite_pullrates.profiles set status='rejected',snapshot=null,snapshot_version=null where id=target.id; end if;
  if operation='include' then update mastersite_pullrates.profiles set snapshot=counts,snapshot_version=version where id=target.id; end if;
  if operation='exclude' then update mastersite_pullrates.profiles set snapshot=null,snapshot_version=null where id=target.id; end if;
  -- Permission and snapshot changes also increment the revision for stale dialogs.
  update mastersite_pullrates.profiles set version=version+1,updated_at=now() where id=target.id;
  if operation='include' then update mastersite_pullrates.profiles set snapshot_version=version where id=target.id; end if;
  perform mastersite_pullrates_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 if operation='export-all' then
  select jsonb_agg(jsonb_build_object('user_id',id,'email',email,'counts',counts,'snapshot',snapshot))
   into result from mastersite_pullrates.profiles;
  return jsonb_build_object('format','pokemon-pullrates','schema_version',1,'set','30thC-zh-Hans',
   'scope','all','created_at',now(),'datasets',result);
 end if;
 if operation='restore-all' then
  if (payload->>'format') is distinct from 'pokemon-pullrates' or (payload->>'set') is distinct from '30thC-zh-Hans'
   or (payload->>'schema_version') is distinct from '1' or (payload->>'scope') is distinct from 'all'
   or jsonb_typeof(payload->'datasets') is distinct from 'array' then raise exception 'INVALID_BACKUP'; end if;
  if jsonb_array_length(payload->'datasets')>10000 then raise exception 'INVALID_BACKUP'; end if;
  if exists(select 1 from jsonb_array_elements(payload->'datasets') a group by a->>'user_id' having count(*)>1) then raise exception 'DUPLICATE_USER'; end if;
  for item in select * from jsonb_array_elements(payload->'datasets') loop
   perform mastersite_pullrates_private.validate_counts(item->'counts');
   if not (item ? 'snapshot') then raise exception 'INVALID_BACKUP'; end if;
   if item->'snapshot'<>'null'::jsonb then perform mastersite_pullrates_private.validate_counts(item->'snapshot'); end if;
   select * into target from mastersite_pullrates.profiles where id=(item->>'user_id')::uuid for update;
   if not found then raise exception 'USER_NOT_FOUND'; end if;
   if (payload->'expected_versions'->>target.id::text)::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
   insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,target.id,'restore',to_jsonb(target));
   update mastersite_pullrates.profiles set counts=item->'counts',snapshot=nullif(item->'snapshot','null'::jsonb),
    version=version+1,snapshot_version=case when item->'snapshot'<>'null'::jsonb then version+1 else null end,updated_at=now() where id=target.id;
  end loop;
  perform mastersite_pullrates_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Protected entry point chat_application
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 -- Serialize chat changes; prevents request, report-snapshot and retention races.
 perform pg_advisory_xact_lock(3046104);
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 if not found or me.status<>'approved' then raise exception 'CHAT_REQUIRES_APPROVAL';end if;
 own_admin:=me.id=admin_id and me.role='admin';
 select * into rule from mastersite_pullrates.chat_rules where active;
 if not found then raise exception 'CHAT_NOT_CONFIGURED';end if;
 perform mastersite_pullrates_private.chat_purge();
 if operation in ('admin-consents','admin-reports','admin-report','close-report','suspend') then return mastersite_pullrates_private.chat_admin_operation(operation,payload);end if;
 if operation='state' then
  return jsonb_build_object('user_id',me.id,'username',me.username,'rule',to_jsonb(rule),'accepted',exists(select 1 from mastersite_pullrates.chat_consents where user_id=me.id and version=rule.version),
   'banned',exists(select 1 from mastersite_pullrates.chat_bans where user_id=me.id),'can_chat',me.username is not null and not me.username_blocked,
   'identity',(select to_jsonb(i) from mastersite_pullrates.chat_identities i where user_id=me.id),
   'devices',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]') from mastersite_pullrates.chat_devices x where owner_id=me.id),
   'admin_identity',(select jsonb_build_object('user_id',user_id,'public_bundle',public_bundle,'key_id',key_id) from mastersite_pullrates.chat_identities where user_id=admin_id));
 end if;
 if me.username is null or me.username_blocked then raise exception 'CHAT_REQUIRES_USERNAME';end if;
 if operation='accept-rules' then
  if payload->>'version' is distinct from rule.version or payload->'confirmed' is distinct from 'true'::jsonb then raise exception 'RULE_CONFIRMATION_REQUIRED';end if;
  insert into mastersite_pullrates.chat_consents(user_id,version) values(me.id,rule.version) on conflict do nothing;
  return (select to_jsonb(a) from mastersite_pullrates.chat_consents a where user_id=me.id and version=rule.version);
 end if;
 if not exists(select 1 from mastersite_pullrates.chat_consents where user_id=me.id and version=rule.version) then raise exception 'RULES_REQUIRED';end if;
 if operation in ('identity-create','device-request','device-approve','device-revoke') then return mastersite_pullrates_private.chat_identity_operation(operation,payload);end if;
 if not exists(select 1 from mastersite_pullrates.chat_identities where user_id=me.id) then raise exception 'IDENTITY_REQUIRED';end if;
 if not exists(select 1 from mastersite_pullrates.chat_identities where user_id=admin_id) then raise exception 'ADMIN_KEY_REQUIRED';end if;
 if operation in ('conversations','request') then return mastersite_pullrates_private.chat_contact_operation(operation,payload);end if;
 if operation in ('view','read','delete','block','unblock','report-prepare','report-submit') then return mastersite_pullrates_private.chat_history_operation(operation,payload);end if;
 return mastersite_pullrates_private.chat_send_operation(operation,payload);
end $function$;

-- Protected entry point copy_pulls_to_trade
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.copy_pulls_to_trade(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare source mastersite_pullrates.lists;destination mastersite_pullrates.lists;preview jsonb;merged jsonb;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 if payload->>'protocol' is distinct from '3' then raise exception 'TRANSFER_PREVIEW_REQUIRED';end if;
 perform mastersite_pullrates_private.validate_counts(payload->'counts');
 preview:=mastersite_pullrates_private.trade_transfer_preview(jsonb_build_object('source_id',payload->>'source_id','target_id',payload->>'target_id','card_ids',(select jsonb_agg(key) from jsonb_object_keys(payload->'counts') key)));
 if (preview->>'source_version')::int is distinct from (payload->>'source_version')::int or (preview->>'target_version')::int is distinct from (payload->>'target_version')::int or (preview->>'inventory_revision')::int is distinct from (payload->>'inventory_revision')::int then raise exception 'VERSION_CONFLICT';end if;
 if exists(select 1 from jsonb_each_text(payload->'counts') x where value::int>(preview->'cards'->key->>'available')::int) then raise exception 'OFFER_EXCEEDS_AVAILABLE';end if;
 select * into destination from mastersite_pullrates.lists where id=(payload->>'target_id')::uuid;
 merged:=destination.counts||(payload->'counts');
 return mastersite_pullrates_private.list_application('save',jsonb_build_object('list_id',destination.id,'version',destination.version,'counts',merged));
end $function$;

-- Protected entry point inventory_application
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.inventory_application(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare l mastersite_pullrates.lists;i mastersite_pullrates.inventory;totals jsonb;m jsonb;b jsonb;g jsonb;available jsonb;missing jsonb;result jsonb;previous_binder int;delta int;req uuid;prior mastersite_pullrates.inventory_requests;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 if not exists(select 1 from mastersite_pullrates.profiles where id=auth.uid() and status<>'rejected') then raise exception 'NOT_APPROVED';end if;
 select * into l from mastersite_pullrates.lists where id=(payload->>'list_id')::uuid and owner_id=auth.uid() and purpose='pulls' for update;
 if not found then raise exception 'OWN_PULL_LIST_REQUIRED';end if;
 select * into i from mastersite_pullrates.inventory where list_id=l.id for update;
 m:=coalesce(i.master,'{}');b:=coalesce(i.binder,'{}');g:=coalesce(i.given,'{}');
 if operation='get' then return mastersite_pullrates_private.stock_result(l.id);end if;
 if operation='save' then
  req:=(payload->>'request_id')::uuid;if req is null then raise exception 'REQUEST_ID_REQUIRED';end if;
  select * into prior from mastersite_pullrates.inventory_requests where request_id=req;
  if found then
   if prior.list_id<>l.id or prior.payload<>payload then raise exception 'REQUEST_REUSED';end if;
   return prior.result;
  end if;
 end if;
 if l.version is distinct from (payload->>'version')::int or coalesce(i.revision,0) is distinct from (payload->>'revision')::int then raise exception 'VERSION_CONFLICT';end if;
 previous_binder:=mastersite_pullrates_private.stock_sets(b);
 if operation='save' then
  perform mastersite_pullrates_private.validate_counts(payload->'counts');perform mastersite_pullrates_private.validate_pull_deltas(payload->'new_pulls');
  select jsonb_object_agg(id,coalesce((payload->'counts'->>id)::int,0)+coalesce((payload->'new_pulls'->>id)::int,0)) into totals from mastersite_pullrates.cards;
  m:=payload->'master';b:=payload->'binder';g:=payload->'given';
  perform mastersite_pullrates_private.validate_stock(totals,m,b,g);
 elsif operation='master' then
  delta:=(payload->>'delta')::int;if delta is null or delta=0 or abs(delta::bigint)>1000000 then raise exception 'INVALID_MASTER_DELTA';end if;
  available:=mastersite_pullrates_private.stock_available(l.counts,m,b,g);
  if delta>0 then
   select coalesce(jsonb_agg(jsonb_build_object('card_id',id,'missing',delta-coalesce((available->>id)::int,0)) order by id),'[]') into missing from mastersite_pullrates.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b') and coalesce((available->>id)::int,0)<delta;
   if jsonb_array_length(missing)>0 then return jsonb_build_object('applied',false,'missing',missing);end if;
  end if;
  select m||jsonb_object_agg(id,coalesce((m->>id)::int,0)+delta) into m from mastersite_pullrates.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b');
  totals:=l.counts;perform mastersite_pullrates_private.validate_stock(totals,m,b,g);
 else raise exception 'UNKNOWN_OPERATION';end if;
 -- Allocations must be updated before the total guard runs, in the same transaction.
 insert into mastersite_pullrates.inventory(list_id,master,binder,given,revision) values(l.id,m,b,g,1) on conflict(list_id) do update set master=excluded.master,binder=excluded.binder,given=excluded.given,revision=inventory.revision+1;
 if operation='save' and totals is distinct from (select jsonb_object_agg(id,coalesce((l.counts->>id)::int,0)) from mastersite_pullrates.cards) then
  perform mastersite_pullrates_private.list_application('save',jsonb_build_object('list_id',l.id,'version',l.version,'counts',totals));
 end if;
 result:=mastersite_pullrates_private.stock_result(l.id)||jsonb_build_object('applied',true,'previous_binder_sets',previous_binder);
 if operation='save' then insert into mastersite_pullrates.inventory_requests(request_id,list_id,payload,result) values(req,l.id,payload,result);end if;
 return result;
end $function$;

-- Protected entry point list_application
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.list_application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; item mastersite_pullrates.lists; result jsonb; clean text; total numeric; r jsonb; full_access boolean; entry jsonb;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform pg_advisory_xact_lock(3046103);
 select * into me from mastersite_pullrates.profiles where id=auth.uid() for update;
 if not found then raise exception 'PROFILE_MISSING'; end if;
 if operation='me' then
  return jsonb_build_object('id',me.id,'role',me.role,'status',me.status,'username',me.username,'username_blocked',me.username_blocked,'lists',
   (select coalesce(jsonb_agg(to_jsonb(l) order by l.is_legacy desc,l.updated_at,l.id),'[]') from mastersite_pullrates.lists l where l.owner_id=me.id));
 end if;
 if me.status='rejected' then raise exception 'NOT_APPROVED'; end if;
 if operation='username' then
  if me.username_blocked then raise exception 'USERNAME_LOCKED'; end if;
  clean:=mastersite_pullrates_private.validate_username(payload->>'username');
  if exists(select 1 from mastersite_pullrates.profiles where lower(username)=lower(clean) and id<>me.id) then raise exception 'USERNAME_TAKEN'; end if;
  update mastersite_pullrates.profiles set username=clean where id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation='create' then
  if (select count(*) from mastersite_pullrates.lists where owner_id=me.id)>=10 then raise exception 'LIST_LIMIT'; end if;
  clean:=btrim(payload->>'name');
  if clean is null or char_length(clean) not between 1 and 80 then raise exception 'LIST_NAME'; end if;
  insert into mastersite_pullrates.lists(owner_id,name,purpose) values(me.id,clean,coalesce(payload->>'purpose','pulls')) returning * into item;
  return to_jsonb(item);
 end if;
 if operation='search' then
  if me.role<>'admin' and (me.status<>'approved' or me.username is null or me.username_blocked) then raise exception 'SEARCH_REQUIRES_APPROVAL_AND_USERNAME'; end if;
  select coalesce(jsonb_agg(x),'[]') into result from (
   select l.id,l.name,l.purpose,l.display,p.username from mastersite_pullrates.lists l join mastersite_pullrates.profiles p on p.id=l.owner_id
   where l.visibility='public' and p.status='approved' and p.username is not null and not p.username_blocked
    and position(lower(left(coalesce(payload->>'query',''),24)) in lower(p.username))>0 order by lower(p.username),l.name,l.id limit 100
  ) x;
  return result;
 end if;
 if operation in ('admin-lists','export-all','restore-all','moderate-name') then
  if me.role<>'admin' or me.status<>'approved' then raise exception 'ADMIN_REQUIRED'; end if;
  if operation='admin-lists' then
   select coalesce(jsonb_agg(to_jsonb(l)||jsonb_build_object('username',p.username,'email',p.email,'status',p.status) order by p.email,l.is_legacy desc,l.name),'[]') into result from mastersite_pullrates.lists l join mastersite_pullrates.profiles p on p.id=l.owner_id where not p.request_archived;
   return result;
  end if;
  if operation='moderate-name' then
   if me.id<>'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid then raise exception 'ADMIN_REQUIRED'; end if;
   clean:=mastersite_pullrates_private.validate_username(payload->>'username');
   update mastersite_pullrates.profiles set username=clean,username_blocked=coalesce((payload->>'blocked')::boolean,false) where id=(payload->>'user_id')::uuid;
   return jsonb_build_object('ok',true);
  end if;
  if operation='export-all' then
   return jsonb_build_object('format','pokemon-pullrates','schema_version',2,'set','30thC-zh-Hans','scope','all','created_at',now(),'lists',(select coalesce(jsonb_agg(to_jsonb(l)),'[]') from mastersite_pullrates.lists l));
  end if;
  if operation='restore-all' then
   if payload->>'format' is distinct from 'pokemon-pullrates' or payload->>'schema_version' is distinct from '2' or payload->>'set' is distinct from '30thC-zh-Hans' or payload->>'scope' is distinct from 'all' or jsonb_typeof(payload->'lists') is distinct from 'array' then raise exception 'INVALID_BACKUP';end if;
   if jsonb_array_length(payload->'lists')>10000 or exists(select 1 from jsonb_array_elements(payload->'lists') a group by a->>'id' having count(*)>1) then raise exception 'INVALID_BACKUP';end if;
   for entry in select * from jsonb_array_elements(payload->'lists') loop
    select * into item from mastersite_pullrates.lists where id=(entry->>'id')::uuid for update;
    if not found or item.owner_id::text is distinct from entry->>'owner_id' then raise exception 'LIST_NOT_FOUND';end if;
    if item.version is distinct from (payload->'expected_versions'->>item.id::text)::integer then raise exception 'VERSION_CONFLICT';end if;
    perform mastersite_pullrates_private.validate_counts(entry->'counts');
    if not(entry ? 'snapshot') then raise exception 'INVALID_BACKUP';end if;
    if entry->'snapshot'<>'null'::jsonb then perform mastersite_pullrates_private.validate_counts(entry->'snapshot');end if;
    insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,item.owner_id,'restore-list',to_jsonb(item));
    if item.is_legacy then update mastersite_pullrates.profiles set counts=entry->'counts',version=version+1 where id=item.owner_id;end if;
    update mastersite_pullrates.lists set counts=entry->'counts',snapshot=nullif(entry->'snapshot','null'::jsonb),snapshot_version=case when entry->'snapshot'<>'null'::jsonb then version+1 else null end,version=version+1,updated_at=now() where id=item.id;
   end loop;
   perform mastersite_pullrates_private.refresh_rates();return jsonb_build_object('ok',true);
  end if;
 end if;
 select * into item from mastersite_pullrates.lists where id=(payload->>'list_id')::uuid for update;
 if not found then raise exception 'LIST_NOT_FOUND'; end if;
 select * into target from mastersite_pullrates.profiles where id=item.owner_id;
 full_access:=item.owner_id=me.id or me.role='admin';
 if operation='view' then
  if not full_access and (me.status<>'approved' or me.username is null or me.username_blocked or target.status<>'approved' or target.username is null or target.username_blocked or item.visibility<>'public') then raise exception 'LIST_NOT_FOUND'; end if;
  select coalesce(sum(coalesce((item.counts->>c.id)::numeric,0)),0) into total from mastersite_pullrates.cards c where c.booster_slot;
  select jsonb_object_agg(c.id,case when total=0 or coalesce((item.counts->>c.id)::numeric,0)=0 then null else round(total/(item.counts->>c.id)::numeric,2) end) into r from mastersite_pullrates.cards c;
  return jsonb_build_object('id',item.id,'name',item.name,'username',target.username,'purpose',item.purpose,'display',item.display,'value_public',item.value_public,'valuation',case when full_access or item.value_public then mastersite_pullrates_private.visible_valuation(item.counts,full_access or item.display<>'rates_only') else null end,
   'counts',case when full_access or item.display<>'rates_only' then item.counts else null end,
   'boosters',case when full_access or (item.display='all' and item.purpose='pulls') then total else null end,
   'rates',case when item.purpose='pulls' then r else null end,'rarity_stats',case when item.purpose='pulls' then mastersite_pullrates_private.rarity_statistics(item.counts,full_access or item.display<>'rates_only') else null end);
 end if;
 if operation in ('include','exclude') then
  if me.role<>'admin' or me.status<>'approved' then raise exception 'ADMIN_REQUIRED';end if;
  if item.version is distinct from (payload->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
  if operation='include' and (item.purpose<>'pulls' or target.status<>'approved') then raise exception 'NOT_ELIGIBLE';end if;
  insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,item.owner_id,operation||'-list',to_jsonb(item));
  update mastersite_pullrates.lists set snapshot=case when operation='include' then counts else null end,snapshot_version=case when operation='include' then version+1 else null end,owner_live=false,version=version+1,updated_at=now() where id=item.id;
  perform mastersite_pullrates_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 if item.owner_id<>me.id then raise exception 'NOT_OWNER';end if;
 if item.version is distinct from (payload->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
 if operation='save' then
  perform mastersite_pullrates_private.validate_counts(payload->'counts');
  insert into mastersite_pullrates.history(actor,target,action,previous_state) values(me.id,me.id,'save-list',to_jsonb(item));
  if item.is_legacy then
   update mastersite_pullrates.profiles set counts=payload->'counts',version=version+1,updated_at=now() where id=me.id;
  else
   update mastersite_pullrates.lists set counts=payload->'counts',version=version+1,updated_at=now() where id=item.id;
  end if;
  perform mastersite_pullrates_private.refresh_rates();
  select * into item from mastersite_pullrates.lists where id=item.id;
  return to_jsonb(item);
 end if;
 if operation='settings' then
  clean:=btrim(payload->>'name');
  if clean is null or char_length(clean) not between 1 and 80 then raise exception 'LIST_NAME';end if;
  if payload->>'visibility'='public' and (me.status<>'approved' or me.username is null or me.username_blocked) then raise exception 'PUBLIC_REQUIRES_APPROVAL_AND_USERNAME';end if;
  if item.purpose is distinct from payload->>'purpose' and (item.owner_live or item.snapshot is not null) then raise exception 'EXCLUDE_BEFORE_PURPOSE_CHANGE';end if;
  update mastersite_pullrates.lists set name=clean,purpose=payload->>'purpose',visibility=payload->>'visibility',display=payload->>'display',value_public=case when payload ? 'value_public' then (payload->>'value_public')::boolean else value_public end,version=version+1,updated_at=now() where id=item.id returning * into item;
  return to_jsonb(item);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Protected entry point save_market_link
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.save_market_link(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare card text:=payload->>'card_id';link text:=nullif(btrim(payload->>'url'),'');product mastersite_pullrates.cardmarket_catalog;pid bigint;slug text;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is distinct from 'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid or not exists(select 1 from mastersite_pullrates.profiles where id=auth.uid() and role='admin' and status='approved') then raise exception 'OWNER_REQUIRED';end if;
 if not exists(select 1 from mastersite_pullrates.cards where id=card) then raise exception 'UNKNOWN_CARD';end if;
 if link is null then delete from mastersite_pullrates.cardmarket_prices where card_id=card;return jsonb_build_object('ok',true);end if;
 if link !~ '^https://www[.]cardmarket[.]com/(de|en)/Pokemon/Products/Singles/30th-Celebration-Simplified-Chinese/[A-Za-z0-9-]+$' then raise exception 'INVALID_CARDMARKET_LINK';end if;
 pid:=nullif(payload->>'product_id','')::bigint;
 if pid is not null then
  select * into product from mastersite_pullrates.cardmarket_catalog where product_id=pid;
  if not found then raise exception 'UNKNOWN_PRODUCT';end if;
  slug:=regexp_replace(regexp_replace(regexp_replace(link,'^.*/',''),'-30thC[0-9]+$','','i'),'-V[0-9]+$','','i');
  if regexp_replace(lower(slug),'[^a-z0-9]','','g')<>regexp_replace(translate(lower(split_part(product.name,' [',1)),'éèêëáàâäíìîïóòôöúùûüñç','eeeeaaaaiiiioooouuuunc'),'[^a-z0-9]','','g') then raise exception 'PRODUCT_LINK_MISMATCH';end if;
 end if;
 insert into mastersite_pullrates.cardmarket_prices(card_id,cardmarket_url,product_id,low,avg7,source_at,checked_at,status)
 values(card,link,pid,product.low,product.avg7,product.source_at,now(),case when pid is null then 'unmapped' when product.low is null or product.avg7 is null then 'missing' else 'ok' end)
 on conflict(card_id) do update set cardmarket_url=excluded.cardmarket_url,product_id=excluded.product_id,low=excluded.low,avg7=excluded.avg7,source_at=excluded.source_at,checked_at=excluded.checked_at,status=excluded.status;
 return jsonb_build_object('ok',true);
end $function$;

-- Protected entry point trade_transfer_preview
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.trade_transfer_preview(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare source mastersite_pullrates.lists;destination mastersite_pullrates.lists;stock jsonb;available jsonb;rows jsonb;
begin
 if not mastersite_pullrates_private.issuer_allowed() then
   raise exception 'APP_AUTH_REQUIRED' using errcode='42501';
 end if;

 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 stock:=mastersite_pullrates_private.inventory_application('get',jsonb_build_object('list_id',payload->>'source_id'));
 select * into source from mastersite_pullrates.lists where id=(payload->>'source_id')::uuid;
 select * into destination from mastersite_pullrates.lists where id=(payload->>'target_id')::uuid and owner_id=auth.uid() and purpose='trade';if not found then raise exception 'OWN_TRADE_LIST_REQUIRED';end if;
 if jsonb_typeof(payload->'card_ids') is distinct from 'array' or jsonb_array_length(payload->'card_ids') not between 1 and 176 then raise exception 'NO_CARDS_SELECTED';end if;
 if exists(select 1 from jsonb_array_elements_text(payload->'card_ids') k where not exists(select 1 from mastersite_pullrates.cards where id=k)) then raise exception 'INVALID_COUNTS';end if;
 available:=stock->'available';
 select jsonb_object_agg(k,jsonb_build_object('available',coalesce((available->>k)::int,0),'offer_count',coalesce((destination.counts->>k)::int,0))) into rows from (select distinct value k from jsonb_array_elements_text(payload->'card_ids')) x;
 return jsonb_build_object('protocol',3,'source_id',source.id,'source_version',source.version,'inventory_revision',stock->'revision','target_id',destination.id,'target_version',destination.version,'cards',rows);
end $function$;
commit;
