-- Generated from pullrates ORIGINAL Supabase project function definitions. No production rows in this file.
-- Only stage these functions until all user-data hashes, cross-app issuer gates, and RLS are tested.
-- User-data migration is handled separately without DELETE/TRUNCATE/replacement.
begin;
create schema if not exists mastersite_pullrates_private;
revoke all on schema mastersite_pullrates_private from PUBLIC, anon, authenticated, service_role;
-- Existing mirrored tables are in mastersite_pullrates; private helper functions stay outside the Data API.
set local check_function_bodies = off;

-- Originally pull_private.application (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; rec record; result jsonb; item jsonb;
begin
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

-- Originally pull_private.chat_admin_operation (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_admin_operation(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 select * into rule from mastersite_pullrates.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='admin-consents' then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('user_id',p.id,'username',p.username,'email',p.email,'version',a.version,'accepted_at',a.accepted_at) order by a.accepted_at desc),'[]') from mastersite_pullrates.chat_consents a join mastersite_pullrates.profiles p on p.id=a.user_id);
 end if;
 if operation='admin-reports' then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'reporter',p.username,'created_at',r.created_at,'status',r.status,'message_count',jsonb_array_length(r.evidence)) order by r.created_at desc),'[]') from mastersite_pullrates.chat_reports r join mastersite_pullrates.profiles p on p.id=r.reporter where r.status<>'draft');
 end if;
 if operation in ('admin-report','close-report','suspend') then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  if operation='suspend' then
   if (payload->>'user_id')::uuid=me.id then raise exception 'ADMIN_PROTECTED';end if;
   if coalesce((payload->>'suspended')::boolean,false) then insert into mastersite_pullrates.chat_bans(user_id,reason) values((payload->>'user_id')::uuid,left(coalesce(payload->>'reason','Verstoß gegen Chatregeln'),500)) on conflict(user_id) do update set reason=excluded.reason;else delete from mastersite_pullrates.chat_bans where user_id=(payload->>'user_id')::uuid;end if;
   return jsonb_build_object('ok',true);
  end if;
  select * into report from mastersite_pullrates.chat_reports where id=(payload->>'report_id')::uuid and status<>'draft';if not found then raise exception 'REPORT_NOT_FOUND';end if;
  if operation='close-report' then update mastersite_pullrates.chat_reports set status='closed' where id=report.id;return jsonb_build_object('ok',true);end if;
  return to_jsonb(report);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Originally pull_private.chat_application (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
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

-- Originally pull_private.chat_contact_operation (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_contact_operation(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 select * into rule from mastersite_pullrates.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='conversations' then
  return (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'status',x.status,'inviter',x.inviter,'ttl',x.ttl,'proposed_ttl',x.proposed_ttl,'proposer',x.proposer,'version',x.version,'peer_id',p.id,'username',p.username,'blocked',exists(select 1 from mastersite_pullrates.chat_blocks where (blocker=me.id and blocked=p.id) or (blocker=p.id and blocked=me.id)),'blocked_by_me',exists(select 1 from mastersite_pullrates.chat_blocks where blocker=me.id and blocked=p.id),'unread',exists(select 1 from mastersite_pullrates.chat_messages where conversation_id=x.id and sender<>me.id and seq>m.read_seq and seq>m.hidden_before)) order by x.updated_at desc),'[]') from mastersite_pullrates.chat_conversations x join mastersite_pullrates.chat_members m on m.conversation_id=x.id and m.user_id=me.id join mastersite_pullrates.profiles p on p.id=case when x.a=me.id then x.b else x.a end where not m.archived);
 end if;
 if operation='request' then
  if exists(select 1 from mastersite_pullrates.chat_bans where user_id=me.id) then raise exception 'CHAT_SUSPENDED';end if;
  select * into target from mastersite_pullrates.profiles where lower(username)=lower(btrim(payload->>'username')) and status='approved' and not username_blocked and id<>me.id;
  if not found or not exists(select 1 from mastersite_pullrates.chat_identities where user_id=target.id) or not exists(select 1 from mastersite_pullrates.chat_consents where user_id=target.id and version=rule.version) or exists(select 1 from mastersite_pullrates.chat_bans where user_id=target.id) then raise exception 'CONTACT_UNAVAILABLE';end if;
  if exists(select 1 from mastersite_pullrates.chat_blocks where (blocker=me.id and blocked=target.id) or (blocker=target.id and blocked=me.id)) then raise exception 'CONTACT_UNAVAILABLE';end if;
  if (select count(*) from mastersite_pullrates.chat_conversations where inviter=me.id and created_at>now()-interval '1 day')>=10 then raise exception 'REQUEST_LIMIT';end if;
  select * into c from mastersite_pullrates.chat_conversations where a=least(me.id,target.id) and b=greatest(me.id,target.id);
  if found then
   if c.status='rejected' then
    if c.inviter=me.id then raise exception 'CONTACT_UNAVAILABLE';end if;
    update mastersite_pullrates.chat_conversations set status='pending',inviter=me.id,version=version+1,updated_at=now() where id=c.id returning * into c;
    update mastersite_pullrates.chat_members set archived=false where conversation_id=c.id;
   end if;
   update mastersite_pullrates.chat_members set archived=false where conversation_id=c.id and user_id=me.id;
   return to_jsonb(c);
  end if;
  insert into mastersite_pullrates.chat_conversations(a,b,inviter) values(least(me.id,target.id),greatest(me.id,target.id),me.id) returning * into c;
  insert into mastersite_pullrates.chat_members(conversation_id,user_id) values(c.id,me.id),(c.id,target.id);
  return to_jsonb(c);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Originally pull_private.chat_history_operation (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_history_operation(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 select * into rule from mastersite_pullrates.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 select * into c from mastersite_pullrates.chat_conversations where id=(payload->>'conversation_id')::uuid and (a=me.id or b=me.id) for update;
 if not found then raise exception 'CONVERSATION_NOT_FOUND';end if;
 other_id:=case when c.a=me.id then c.b else c.a end;
 select * into target from mastersite_pullrates.profiles where id=other_id;
 is_blocked:=exists(select 1 from mastersite_pullrates.chat_blocks where (blocker=me.id and blocked=other_id) or (blocker=other_id and blocked=me.id));
 if operation='view' then
  return jsonb_build_object('conversation',to_jsonb(c),'peer',jsonb_build_object('user_id',target.id,'username',target.username,'public_bundle',(select public_bundle from mastersite_pullrates.chat_identities where user_id=target.id),'key_id',(select key_id from mastersite_pullrates.chat_identities where user_id=target.id)),
   'messages',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('read',x.sender=me.id and x.seq<=(select read_seq from mastersite_pullrates.chat_members where conversation_id=c.id and user_id=other_id)) order by x.seq),'[]') from (select * from mastersite_pullrates.chat_messages where conversation_id=c.id and seq>(select hidden_before from mastersite_pullrates.chat_members where conversation_id=c.id and user_id=me.id) and seq>coalesce((payload->>'after_seq')::bigint,0) order by seq limit 100) x));
 end if;
 if operation='read' then
  select coalesce(max(seq),0) into n from mastersite_pullrates.chat_messages where conversation_id=c.id;
  update mastersite_pullrates.chat_members set read_seq=greatest(read_seq,least(n,greatest(0,(payload->>'seq')::bigint))) where conversation_id=c.id and user_id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation='delete' then
  update mastersite_pullrates.chat_members set archived=true,hidden_before=(select coalesce(max(seq),hidden_before) from mastersite_pullrates.chat_messages where conversation_id=c.id) where conversation_id=c.id and user_id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation in ('block','unblock') then
  if operation='block' then insert into mastersite_pullrates.chat_blocks(blocker,blocked) values(me.id,other_id) on conflict do nothing;else delete from mastersite_pullrates.chat_blocks where blocker=me.id and blocked=other_id;end if;
  return jsonb_build_object('ok',true);
 end if;
 if operation='report-prepare' then
  if payload->'confirmed' is distinct from 'true'::jsonb then raise exception 'REPORT_CONFIRMATION_REQUIRED';end if;
  if (select count(*) from mastersite_pullrates.chat_reports where reporter=me.id and created_at>now()-interval '1 day')>=10 then raise exception 'REPORT_LIMIT';end if;
  select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('sender_public',i.public_bundle,'sender_username',p.username) order by m.seq),'[]') into result from mastersite_pullrates.chat_messages m join mastersite_pullrates.chat_identities i on i.user_id=m.sender join mastersite_pullrates.profiles p on p.id=m.sender where m.conversation_id=c.id;
  if jsonb_array_length(result)=0 then raise exception 'NO_MESSAGES_TO_REPORT';end if;
  if pg_column_size(result)>15000000 then raise exception 'REPORT_TOO_LARGE';end if;
  insert into mastersite_pullrates.chat_reports(conversation_id,reporter,evidence,admin_key_id,reporter_public) values(c.id,me.id,result,(select key_id from mastersite_pullrates.chat_identities where user_id=admin_id),(select public_bundle from mastersite_pullrates.chat_identities where user_id=me.id)) returning * into report;
  return to_jsonb(report);
 end if;
 if operation='report-submit' then
  select * into report from mastersite_pullrates.chat_reports where id=(payload->>'report_id')::uuid and reporter=me.id and conversation_id=c.id and status='draft';if not found then raise exception 'REPORT_NOT_FOUND';end if;
  if payload->'confirmed' is distinct from 'true'::jsonb or (payload->>'message_count')::int is distinct from jsonb_array_length(report.evidence) or payload->'packet'->'context'->>'report_id' is distinct from report.id::text or payload->'packet'->'context'->>'sender' is distinct from me.id::text or payload->'packet'->'wraps'->admin_id::text->>'key_id' is distinct from report.admin_key_id or pg_column_size(payload)>2000000 then raise exception 'INVALID_REPORT';end if;
  update mastersite_pullrates.chat_reports set encrypted_packet=payload->'packet',status='open' where id=report.id;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Originally pull_private.chat_identity_operation (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_identity_operation(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 select * into rule from mastersite_pullrates.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='identity-create' then
  if exists(select 1 from mastersite_pullrates.chat_identities where user_id=me.id) then raise exception 'IDENTITY_EXISTS';end if;
  if pg_column_size(payload)>20000 or payload->'public_bundle'->>'v' is distinct from '1' or not(payload->'public_bundle' ? 'enc') or not(payload->'public_bundle' ? 'sig') or (payload->'public_bundle'->'enc') ? 'd' or (payload->'public_bundle'->'sig') ? 'd' or char_length(payload->>'key_id')<>43 or payload->'encrypted_vault'->>'iv' is null or payload->'encrypted_vault'->>'data' is null then raise exception 'INVALID_KEY';end if;
  insert into mastersite_pullrates.chat_identities(user_id,public_bundle,key_id,encrypted_vault) values(me.id,payload->'public_bundle',payload->>'key_id',payload->'encrypted_vault');
  return jsonb_build_object('ok',true);
 end if;
 if operation='device-request' then
  if (select count(*) from mastersite_pullrates.chat_devices where owner_id=me.id and status<>'revoked')>=20 then raise exception 'DEVICE_LIMIT';end if;
  if pg_column_size(payload)>6000 or payload->'public_key'->>'kty' is distinct from 'EC' or (payload->'public_key') ? 'd' then raise exception 'INVALID_KEY';end if;
  insert into mastersite_pullrates.chat_devices(id,owner_id,label,public_key,status) values((payload->>'id')::uuid,me.id,left(coalesce(nullif(btrim(payload->>'label'),''),'Browser'),80),payload->'public_key','pending');return jsonb_build_object('ok',true);
 end if;
 if operation in ('device-approve','device-revoke') then
  select * into d from mastersite_pullrates.chat_devices where id=(payload->>'id')::uuid and owner_id=me.id for update;if not found then raise exception 'DEVICE_NOT_FOUND';end if;
  if operation='device-revoke' then if d.status<>'pending' then raise exception 'DEVICE_ALREADY_APPROVED';end if;update mastersite_pullrates.chat_devices set status='revoked',encrypted_grant=null where id=d.id;
  else
   if d.status<>'pending' or pg_column_size(payload)>10000 or payload->'grant'->>'data' is null then raise exception 'INVALID_DEVICE_GRANT';end if;
   update mastersite_pullrates.chat_devices set status='approved',approved_at=now(),encrypted_grant=payload->'grant' where id=d.id;
  end if;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Originally pull_private.chat_purge ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_purge()
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 delete from mastersite_pullrates.chat_messages where expires_at is not null and expires_at<=clock_timestamp();
 delete from mastersite_pullrates.chat_reports where status='draft' and created_at<now()-interval '1 day';
$function$;

-- Originally pull_private.chat_send_operation (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.chat_send_operation(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; c mastersite_pullrates.chat_conversations; rule mastersite_pullrates.chat_rules; d mastersite_pullrates.chat_devices; identity mastersite_pullrates.chat_identities; report mastersite_pullrates.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from mastersite_pullrates.profiles where id=auth.uid();
 select * into rule from mastersite_pullrates.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 select * into c from mastersite_pullrates.chat_conversations where id=(payload->>'conversation_id')::uuid and (a=me.id or b=me.id) for update;
 if not found then raise exception 'CONVERSATION_NOT_FOUND';end if;
 other_id:=case when c.a=me.id then c.b else c.a end;
 select * into target from mastersite_pullrates.profiles where id=other_id;
 is_blocked:=exists(select 1 from mastersite_pullrates.chat_blocks where (blocker=me.id and blocked=other_id) or (blocker=other_id and blocked=me.id));
 if exists(select 1 from mastersite_pullrates.chat_bans where user_id in (me.id,other_id)) or target.status<>'approved' or target.username is null or target.username_blocked then raise exception 'CHAT_SUSPENDED';end if;
 if is_blocked then raise exception 'CHAT_BLOCKED';end if;
 if operation='respond' then
  if c.status<>'pending' or c.inviter=me.id or payload->>'response' not in ('accepted','rejected') then raise exception 'INVALID_REQUEST';end if;
  update mastersite_pullrates.chat_conversations set status=payload->>'response',version=version+1,updated_at=now() where id=c.id;
  return jsonb_build_object('ok',true);
 end if;
 if c.status<>'accepted' then raise exception 'REQUEST_NOT_ACCEPTED';end if;
 if operation in ('retention-propose','retention-respond') then
  if (payload->>'version')::integer is distinct from c.version then raise exception 'VERSION_CONFLICT';end if;
  if operation='retention-propose' then
   ttl_value:=(payload->>'ttl')::int;if ttl_value not in (0,86400,604800,2592000,7776000) or ttl_value is null then raise exception 'INVALID_RETENTION';end if;
   update mastersite_pullrates.chat_conversations set proposed_ttl=ttl_value,proposer=me.id,version=version+1 where id=c.id;
  else
   if c.proposer is null or c.proposer=me.id or jsonb_typeof(payload->'accept') is distinct from 'boolean' then raise exception 'INVALID_RETENTION';end if;
   update mastersite_pullrates.chat_conversations set ttl=case when (payload->>'accept')::boolean then proposed_ttl else ttl end,proposed_ttl=null,proposer=null,version=version+1 where id=c.id;
  end if;
  return jsonb_build_object('ok',true);
 end if;
 if operation='send' then
  if (select count(*) from mastersite_pullrates.chat_messages where sender=me.id and sent_at>now()-interval '1 minute')>=30 then raise exception 'MESSAGE_LIMIT';end if;
  v_id:=(payload->>'id')::uuid;
  if pg_column_size(payload)>24000 or payload->'envelope'->>'v' is distinct from '1' or payload->'envelope'->'context'->>'type' is distinct from 'message' or payload->'envelope'->'context'->>'id' is distinct from v_id::text or payload->'envelope'->'context'->>'conversation_id' is distinct from c.id::text or payload->'envelope'->'context'->>'sender' is distinct from me.id::text or payload->'envelope'->>'signature' is null or payload->'envelope'->'body'->>'data' is null then raise exception 'INVALID_MESSAGE';end if;
  if (select count(*) from jsonb_object_keys(payload->'envelope'->'wraps'))<>2 or payload->'envelope'->'wraps'->me.id::text->>'key_id' is distinct from (select key_id from mastersite_pullrates.chat_identities where user_id=me.id) or payload->'envelope'->'wraps'->other_id::text->>'key_id' is distinct from (select key_id from mastersite_pullrates.chat_identities where user_id=other_id) then raise exception 'INVALID_MESSAGE_KEYS';end if;
  insert into mastersite_pullrates.chat_messages(id,conversation_id,sender,envelope,expires_at) values(v_id,c.id,me.id,payload->'envelope',case when c.ttl=0 then null else clock_timestamp()+make_interval(secs=>c.ttl) end);
  update mastersite_pullrates.chat_conversations set updated_at=now() where id=c.id;
  update mastersite_pullrates.chat_members set archived=false where conversation_id=c.id;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
 raise exception 'UNKNOWN_OPERATION';
end $function$;

-- Originally pull_private.community_counts ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.community_counts()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 with effective as (
 select case when l.owner_live then l.counts else l.snapshot end counts from mastersite_pullrates.lists l join mastersite_pullrates.profiles p on p.id=l.owner_id
 where p.status='approved' and l.purpose='pulls' and (l.owner_live or l.snapshot is not null)
 ), totals as (
 select c.id,c.booster_slot,coalesce(sum(coalesce((e.counts->>c.id)::numeric,0)),0) n
 from mastersite_pullrates.cards c left join effective e on true group by c.id,c.booster_slot
 ) select jsonb_build_object('counts',jsonb_object_agg(id,n),'boosters',coalesce(sum(n) filter(where booster_slot),0)) from totals;
$function$;

-- Originally pull_private.copy_pulls_to_trade (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.copy_pulls_to_trade(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare source mastersite_pullrates.lists;destination mastersite_pullrates.lists;preview jsonb;merged jsonb;
begin
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

-- Originally pull_private.guard_stock_totals ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.guard_stock_totals()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare i mastersite_pullrates.inventory;
begin
 select * into i from mastersite_pullrates.inventory where list_id=new.id;
 if found then
  perform mastersite_pullrates_private.validate_stock(new.counts,i.master,i.binder,i.given);
  if new.purpose<>old.purpose and exists(select 1 from jsonb_each_text(i.master||'{}'::jsonb) where value::int>0 union all select 1 from jsonb_each_text(i.binder) where value::int>0 union all select 1 from jsonb_each_text(i.given) where value::int>0) then raise exception 'CLEAR_STOCK_BEFORE_PURPOSE_CHANGE';end if;
 end if;
 return new;
end $function$;

-- Originally pull_private.inventory_application (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.inventory_application(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare l mastersite_pullrates.lists;i mastersite_pullrates.inventory;totals jsonb;m jsonb;b jsonb;g jsonb;available jsonb;missing jsonb;result jsonb;previous_binder int;delta int;req uuid;prior mastersite_pullrates.inventory_requests;
begin
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

-- Originally pull_private.list_application (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.list_application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me mastersite_pullrates.profiles; target mastersite_pullrates.profiles; item mastersite_pullrates.lists; result jsonb; clean text; total numeric; r jsonb; full_access boolean; entry jsonb;
begin
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

-- Originally pull_private.market_worker (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.market_worker(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare state mastersite_pullrates.market_worker_state;row jsonb;at_time timestamptz;
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'WORKER_REQUIRED';end if;
 select * into state from mastersite_pullrates.market_worker_state where id=true for update;
 if state.token_hash is null or state.token_hash<>encode(extensions.digest(coalesce(payload->>'token',''),'sha256'),'hex') then raise exception 'WORKER_REQUIRED';end if;
 if operation='claim' then
  if state.running_until>now() then return jsonb_build_object('run',false);end if;
  update mastersite_pullrates.market_worker_state set running_until=now()+interval '4 minutes',last_attempt=now() where id=true;
  return jsonb_build_object('run',true);
 elsif operation='finish' then
  at_time:=(payload->>'source_at')::timestamptz;
  if at_time>now()+interval '1 day' or at_time is null or at_time<(select max(source_at) from mastersite_pullrates.cardmarket_catalog) or jsonb_array_length(payload->'products') not between 1 and 1000 then raise exception 'INVALID_SOURCE';end if;
  for row in select * from jsonb_array_elements(payload->'products') loop
   insert into mastersite_pullrates.cardmarket_catalog(product_id,name,low,avg7,source_at) values((row->>'product_id')::bigint,row->>'name',(row->>'low')::numeric,(row->>'avg7')::numeric,at_time)
   on conflict(product_id) do update set name=excluded.name,low=excluded.low,avg7=excluded.avg7,source_at=excluded.source_at;
  end loop;
  update mastersite_pullrates.cardmarket_prices p set
   low=case when c.low is not null and c.avg7 is not null then c.low else p.low end,
   avg7=case when c.low is not null and c.avg7 is not null then c.avg7 else p.avg7 end,
   source_at=case when c.low is not null and c.avg7 is not null then c.source_at else p.source_at end,
   checked_at=now(),status=case when c.low is null or c.avg7 is null then 'missing' else 'ok' end
  from mastersite_pullrates.cardmarket_catalog c where c.product_id=p.product_id and c.source_at=at_time;
  update mastersite_pullrates.cardmarket_prices p set status='missing',checked_at=now() where product_id is not null and not exists(select 1 from mastersite_pullrates.cardmarket_catalog c where c.product_id=p.product_id and c.source_at=at_time);
  update mastersite_pullrates.market_worker_state set running_until=null,last_success=now(),last_error=null where id=true;
 elsif operation='fail' then
  update mastersite_pullrates.cardmarket_prices set status='error',checked_at=now() where product_id is not null;
  update mastersite_pullrates.market_worker_state set running_until=null,last_error=left(payload->>'error',200) where id=true;
 else raise exception 'UNKNOWN_OPERATION';end if;
 return jsonb_build_object('ok',true);
end $function$;

-- Originally pull_private.public_rarity_statistics ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.public_rarity_statistics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare totals jsonb;visible_counts boolean;
begin
 totals:=mastersite_pullrates_private.community_counts();
 visible_counts:=coalesce((select show_public_counts from mastersite_pullrates.settings where id=true),false) or exists(select 1 from mastersite_pullrates.profiles where id=auth.uid() and status='approved' and role='admin');
 return mastersite_pullrates_private.rarity_statistics(totals->'counts',visible_counts);
end $function$;

-- Originally pull_private.rarity_statistics (card_counts jsonb, show_counts boolean)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.rarity_statistics(card_counts jsonb, show_counts boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 with card_values as (
  select c.id,c.booster_slot,coalesce(d.rarity,b.rarity,'Unbekannt') rarity,coalesce((card_counts->>c.id)::numeric,0) n
  from mastersite_pullrates.cards c left join mastersite_pullrates.card_rarities b on b.card_id=c.id left join mastersite_pullrates.card_details d on d.card_id=c.id
 ), totals as (select rarity,sum(n) n from card_values group by rarity), base as (select coalesce(sum(n) filter(where booster_slot),0) n from card_values)
 select jsonb_build_object('classes',(select coalesce(jsonb_object_agg(t.rarity,jsonb_build_object('rate',case when t.n>0 and b.n>0 then b.n/t.n else null end,'fraction',case when b.n>0 then t.n/b.n else null end)||case when show_counts then jsonb_build_object('count',t.n) else '{}'::jsonb end),'{}') from totals t cross join base b),
 'within',(select coalesce(jsonb_object_agg(c.id,jsonb_build_object('rarity',c.rarity,'rate',case when c.n>0 and t.n>0 then t.n/c.n else null end,'fraction',case when t.n>0 then c.n/t.n else null end)),'{}') from card_values c join totals t using(rarity)));
$function$;

-- Originally pull_private.refresh_rates ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.refresh_rates()
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 with totals as (select mastersite_pullrates_private.community_counts() d)
 update mastersite_pullrates.pull_rates set rates=(select jsonb_object_agg(c.id,case when (d->>'boosters')::numeric=0 or coalesce((d->'counts'->>c.id)::numeric,0)=0 then null else round((d->>'boosters')::numeric/(d->'counts'->>c.id)::numeric,2) end) from mastersite_pullrates.cards c cross join totals),updated_at=now() where id=1;
$function$;

-- Originally pull_private.save_market_link (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.save_market_link(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare card text:=payload->>'card_id';link text:=nullif(btrim(payload->>'url'),'');product mastersite_pullrates.cardmarket_catalog;pid bigint;slug text;
begin
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

-- Originally pull_private.stock_available (totals jsonb, m jsonb, b jsonb, g jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.stock_available(totals jsonb, m jsonb, b jsonb, g jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select coalesce(jsonb_object_agg(id,coalesce((totals->>id)::int,0)-coalesce((m->>id)::int,0)-coalesce((b->>id)::int,0)-coalesce((g->>id)::int,0)),'{}') from mastersite_pullrates.cards;
$function$;

-- Originally pull_private.stock_result (list_id uuid)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.stock_result(list_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('list',to_jsonb(l),'master',coalesce(i.master,'{}'),'binder',coalesce(i.binder,'{}'),'given',coalesce(i.given,'{}'),'revision',coalesce(i.revision,0),'available',mastersite_pullrates_private.stock_available(l.counts,coalesce(i.master,'{}'),coalesce(i.binder,'{}'),coalesce(i.given,'{}')),'master_sets',mastersite_pullrates_private.stock_sets(coalesce(i.master,'{}')),'binder_sets',mastersite_pullrates_private.stock_sets(coalesce(i.binder,'{}'))) from mastersite_pullrates.lists l left join mastersite_pullrates.inventory i on i.list_id=l.id where l.id=stock_result.list_id;
$function$;

-- Originally pull_private.stock_sets (bound jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.stock_sets(bound jsonb)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select coalesce(min(coalesce((bound->>id)::int,0)),0) from mastersite_pullrates.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b');
$function$;

-- Originally pull_private.sync_legacy_list ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.sync_legacy_list()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if tg_op='INSERT' then
  insert into mastersite_pullrates.lists(owner_id,name,counts,version,snapshot,snapshot_version,owner_live,is_legacy)
   values(new.id,'Meine Sammlung',new.counts,new.version,new.snapshot,new.snapshot_version,new.role='admin',true);
 else
  if new.counts is distinct from old.counts or new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then
   update mastersite_pullrates.lists set counts=new.counts,
    snapshot=case when new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then new.snapshot else snapshot end,
    snapshot_version=case when new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then case when new.snapshot is null then null else version+1 end else snapshot_version end,
    version=version+1,updated_at=now() where owner_id=new.id and is_legacy;
  end if;
  if new.status='rejected' and old.status<>'rejected' then
   update mastersite_pullrates.lists set snapshot=null,snapshot_version=null,owner_live=false,visibility='private',version=version+1,updated_at=now() where owner_id=new.id;
  end if;
  if new.username is null or new.username_blocked then
   update mastersite_pullrates.lists set visibility='private',version=version+1,updated_at=now() where owner_id=new.id and visibility='public';
  end if;
 end if;
 return new;
end $function$;

-- Originally pull_private.trade_transfer_preview (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.trade_transfer_preview(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare source mastersite_pullrates.lists;destination mastersite_pullrates.lists;stock jsonb;available jsonb;rows jsonb;
begin
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

-- Originally pull_private.validate_counts (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.validate_counts(payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare item record;
begin
 if payload is null or jsonb_typeof(payload)<>'object' then raise exception 'INVALID_BACKUP: Kartenwerte müssen ein Objekt sein'; end if;
 if pg_column_size(payload)>100000 then raise exception 'INVALID_BACKUP: Datei zu groß'; end if;
 for item in select * from jsonb_each(payload) loop
  if not exists(select 1 from mastersite_pullrates.cards where id=item.key)
   or jsonb_typeof(item.value)<>'number' or item.value::text !~ '^[0-9]+$'
  then raise exception 'INVALID_COUNTS: Unbekannte Karte oder ungültige Stückzahl'; end if;
  if (item.value::text)::numeric>1000000 then raise exception 'INVALID_COUNTS: Maximal 1.000.000 je Karte'; end if;
 end loop;
end $function$;

-- Originally pull_private.validate_pull_deltas (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.validate_pull_deltas(payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare item record;
begin
 if payload is null or jsonb_typeof(payload)<>'object' then raise exception 'INVALID_PULL_DELTAS: Kartenwerte müssen ein Objekt sein';end if;
 if pg_column_size(payload)>100000 then raise exception 'INVALID_PULL_DELTAS: Eingabe zu groß';end if;
 for item in select * from jsonb_each(payload) loop
  if not exists(select 1 from mastersite_pullrates.cards where id=item.key) or jsonb_typeof(item.value)<>'number' or item.value::text !~ '^-?[0-9]+$' then raise exception 'INVALID_PULL_DELTAS: Unbekannte Karte oder ungültige Korrektur';end if;
  if abs((item.value::text)::numeric)>1000000 then raise exception 'INVALID_PULL_DELTAS: Maximal +/- 1.000.000 je Karte';end if;
 end loop;
end $function$;

-- Originally pull_private.validate_stock (totals jsonb, m jsonb, b jsonb, g jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.validate_stock(totals jsonb, m jsonb, b jsonb, g jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 perform mastersite_pullrates_private.validate_counts(totals);perform mastersite_pullrates_private.validate_counts(m);perform mastersite_pullrates_private.validate_counts(b);perform mastersite_pullrates_private.validate_counts(g);
 if exists(select 1 from jsonb_each_text(mastersite_pullrates_private.stock_available(totals,m,b,g)) where value::int<0) then raise exception 'STOCK_EXCEEDS_TOTAL';end if;
end $function$;

-- Originally pull_private.validate_username (value text)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.validate_username(value text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare cleaned text:=nullif(btrim(value),''); normalized text;
begin
 if cleaned is null then return null; end if;
 if char_length(cleaned) not between 3 and 24 or cleaned !~ '^[[:alpha:]0-9_-]+$' then raise exception 'USERNAME_FORMAT'; end if;
 normalized:=lower(cleaned);
 normalized:=replace(replace(replace(replace(normalized,'ä','a'),'ö','o'),'ü','u'),'ß','ss');
 normalized:=translate(normalized,'013457','oieast');
 normalized:=regexp_replace(normalized,'[^[:alpha:]]','','g');
 -- Conservative maintained denylist, also matching separators and common leetspeak.
 if normalized ~ '(arschloch|hurensohn|hurentochter|wichser|fotze|fickdich|scheisse|shithead|asshole|motherfucker|bastard|schlampe|fuck|bitch|cunt|nigger|neger|heilhitler|siegheil|hitler|nazi|hakenkreuz|whitepower|ku[ck]luxklan|judentod|judenvergas|holocaustleug|ssdivision|waffenss|nsdap|untermensch)' or lower(cleaned) ~ '(1488|(^|[_-])88([_-]|$))' or normalized in ('admin','administrator','moderator','support') then raise exception 'USERNAME_BLOCKED'; end if;
 return cleaned;
end $function$;

-- Originally pull_private.valuation (card_counts jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.valuation(card_counts jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('total_eur',coalesce(sum(n*p.unit_eur),0),'valued_copies',coalesce(sum(n) filter(where p.unit_eur is not null),0),'unvalued_copies',coalesce(sum(n) filter(where p.unit_eur is null),0),'stale_copies',coalesce(sum(n) filter(where p.unit_eur is not null and (p.status<>'ok' or p.source_at<now()-interval '48 hours')),0),'source_at',min(p.source_at) filter(where p.unit_eur is not null)) from jsonb_each_text(card_counts) c cross join lateral (select c.value::numeric n) v left join mastersite_pullrates.cardmarket_prices p on p.card_id=c.key where n>0;
$function$;

-- Originally pull_private.visible_community_counts ()
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.visible_community_counts()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare enabled boolean;
begin
 select show_public_counts into enabled from mastersite_pullrates.settings where id=true;
 if coalesce(enabled,false) or exists(select 1 from mastersite_pullrates.profiles where id=auth.uid() and role='admin' and status='approved') then
  return mastersite_pullrates_private.community_counts()||jsonb_build_object('enabled',coalesce(enabled,false));
 end if;
 return jsonb_build_object('enabled',false,'counts',null,'boosters',null);
end $function$;

-- Originally pull_private.visible_valuation (card_counts jsonb, show_counts boolean)
CREATE OR REPLACE FUNCTION mastersite_pullrates_private.visible_valuation(card_counts jsonb, show_counts boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select case when show_counts then v else (v-'valued_copies'-'unvalued_copies'-'stale_copies')||jsonb_build_object('has_prices',(v->>'valued_copies')::numeric>0,'incomplete',(v->>'unvalued_copies')::numeric>0,'stale',(v->>'stale_copies')::numeric>0) end from (select mastersite_pullrates_private.valuation(card_counts) v) x;
$function$;

-- Originally public.pull_app (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_app(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select mastersite_pullrates_private.application(operation,payload); $function$;

-- Originally public.pull_chat (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_chat(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.chat_application(operation,payload);$function$;

-- Originally public.pull_community_counts ()
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_community_counts()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.visible_community_counts();$function$;

-- Originally public.pull_copy_to_trade (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_copy_to_trade(payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.copy_pulls_to_trade(payload);$function$;

-- Originally public.pull_inventory (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_inventory(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.inventory_application(operation,payload);$function$;

-- Originally public.pull_lists (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_lists(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select mastersite_pullrates_private.list_application(operation,payload); $function$;

-- Originally public.pull_market_worker (operation text, payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_market_worker(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.market_worker(operation,payload);$function$;

-- Originally public.pull_rarity_stats ()
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_rarity_stats()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.public_rarity_statistics();$function$;

-- Originally public.pull_save_market_link (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_save_market_link(payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.save_market_link(payload);$function$;

-- Originally public.pull_trade_preview (payload jsonb)
CREATE OR REPLACE FUNCTION mastersite_pullrates.pull_trade_preview(payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select mastersite_pullrates_private.trade_transfer_preview(payload);$function$;

-- Keep Data API schemas isolated until the OIDC issuers are registered and claims tested.
revoke all on schema mastersite_pullrates from PUBLIC, anon, authenticated, service_role;
revoke all on schema mastersite_pullrates_private from PUBLIC, anon, authenticated, service_role;
-- Per-function ACLs mirror original grants but schema USAGE remains disabled for external roles.
revoke all on function mastersite_pullrates_private.application(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.application(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.chat_admin_operation(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.chat_application(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.chat_application(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.chat_contact_operation(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.chat_history_operation(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.chat_identity_operation(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.chat_purge() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.chat_send_operation(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.community_counts() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.copy_pulls_to_trade(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.copy_pulls_to_trade(payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.guard_stock_totals() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.inventory_application(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.inventory_application(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.list_application(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.list_application(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.market_worker(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.market_worker(operation text, payload jsonb) to service_role;
revoke all on function mastersite_pullrates_private.public_rarity_statistics() from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.public_rarity_statistics() to anon;
grant execute on function mastersite_pullrates_private.public_rarity_statistics() to authenticated;
revoke all on function mastersite_pullrates_private.rarity_statistics(card_counts jsonb, show_counts boolean) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.refresh_rates() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.save_market_link(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.save_market_link(payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.stock_available(totals jsonb, m jsonb, b jsonb, g jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.stock_result(list_id uuid) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.stock_sets(bound jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.sync_legacy_list() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.trade_transfer_preview(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.trade_transfer_preview(payload jsonb) to authenticated;
revoke all on function mastersite_pullrates_private.validate_counts(payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.validate_pull_deltas(payload jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.validate_stock(totals jsonb, m jsonb, b jsonb, g jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.validate_username(value text) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.valuation(card_counts jsonb) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates_private.visible_community_counts() from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates_private.visible_community_counts() to anon;
grant execute on function mastersite_pullrates_private.visible_community_counts() to authenticated;
revoke all on function mastersite_pullrates_private.visible_valuation(card_counts jsonb, show_counts boolean) from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_pullrates.pull_app(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_app(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_chat(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_chat(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_community_counts() from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_community_counts() to anon;
grant execute on function mastersite_pullrates.pull_community_counts() to authenticated;
revoke all on function mastersite_pullrates.pull_copy_to_trade(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_copy_to_trade(payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_inventory(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_inventory(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_lists(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_lists(operation text, payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_market_worker(operation text, payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_market_worker(operation text, payload jsonb) to service_role;
revoke all on function mastersite_pullrates.pull_rarity_stats() from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_rarity_stats() to anon;
grant execute on function mastersite_pullrates.pull_rarity_stats() to authenticated;
revoke all on function mastersite_pullrates.pull_save_market_link(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_save_market_link(payload jsonb) to authenticated;
revoke all on function mastersite_pullrates.pull_trade_preview(payload jsonb) from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_pullrates.pull_trade_preview(payload jsonb) to authenticated;
commit;
