begin;
-- Better Auth v1.7 "user" IDs are generated as UUID strings in the Edge Functions.
-- These triggers preserve the original manual-approval workflows.
create or replace function mastersite_feelings_auth.create_pending_feelings_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into mastersite_feelings.profiles
    (id,email,approved,role,created_at,is_creator,access_status)
  values
    (new."id"::uuid, new."email",false,'viewer',new."createdAt",false,'pending')
  on conflict (id) do update set email=excluded.email;
  return new;
end;
$$;
revoke all on function mastersite_feelings_auth.create_pending_feelings_profile() from public,anon,authenticated,service_role;
drop trigger if exists mastersite_feelings_new_user on mastersite_feelings_auth."user";
create trigger mastersite_feelings_new_user
after insert or update of "email" on mastersite_feelings_auth."user"
for each row execute function mastersite_feelings_auth.create_pending_feelings_profile();

create or replace function mastersite_pullrates_auth.create_pending_pullrates_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into mastersite_pullrates.profiles
    (id,email,status,role,counts,version,updated_at)
  values
    (new."id"::uuid,new."email",'pending','user','{}'::jsonb,0,now())
  on conflict (id) do update set email=excluded.email;
  return new;
end;
$$;
revoke all on function mastersite_pullrates_auth.create_pending_pullrates_profile() from public,anon,authenticated,service_role;
drop trigger if exists mastersite_pullrates_new_user on mastersite_pullrates_auth."user";
create trigger mastersite_pullrates_new_user
after insert or update of "email" on mastersite_pullrates_auth."user"
for each row execute function mastersite_pullrates_auth.create_pending_pullrates_profile();
commit;