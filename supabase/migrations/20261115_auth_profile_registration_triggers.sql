-- New Better-Auth registrants get isolated, pending app profiles.
-- INSERT-only triggers. Never rewrites existing profiles or passwords.
begin;
create or replace function mastersite_feelings_private.create_pending_signup_profile()
returns trigger language plpgsql security definer set search_path=''
as $body$
begin
 insert into mastersite_feelings.profiles(id,email,approved,role,is_creator,access_status)
 values(new.id::uuid,lower(new.email),false,'viewer',false,'pending')
 on conflict (id) do nothing;
 return new;
end $body$;
revoke all on function mastersite_feelings_private.create_pending_signup_profile() from PUBLIC,anon,authenticated,service_role;
create trigger mastersite_feelings_new_auth_user
after insert on mastersite_feelings_auth."user"
for each row execute function mastersite_feelings_private.create_pending_signup_profile();

create or replace function mastersite_pullrates_private.create_pending_signup_profile()
returns trigger language plpgsql security definer set search_path=''
as $body$
begin
 insert into mastersite_pullrates.profiles(id,email,username,status,role)
 values(new.id::uuid,lower(new.email),mastersite_pullrates_private.validate_username(new.name),'pending','user')
 on conflict (id) do nothing;
 return new;
end $body$;
revoke all on function mastersite_pullrates_private.create_pending_signup_profile() from PUBLIC,anon,authenticated,service_role;
create trigger mastersite_pullrates_new_auth_user
after insert on mastersite_pullrates_auth."user"
for each row execute function mastersite_pullrates_private.create_pending_signup_profile();
commit;