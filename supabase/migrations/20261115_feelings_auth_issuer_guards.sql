-- Separate Feelings application authentication from Pokémon users.
-- These functions retain creator/admin checks and require the exact Feelings issuer.
begin;
create or replace function mastersite_feelings_private.is_approved_admin()
returns boolean language sql stable security definer set search_path=''
as $gate$
select (auth.jwt()->>'iss')='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-feelings-auth'
  and (auth.jwt()->>'app_id')='feelings-turnier'
  and (auth.jwt()->>'role')='authenticated'
  and exists (
    select 1 from mastersite_feelings.profiles p
    where p.id = auth.uid() and p.approved = true and p.role='admin'
  );
$gate$;
create or replace function mastersite_feelings_private.is_creator_admin()
returns boolean language sql stable security definer set search_path=''
as $gate$
select (auth.jwt()->>'iss')='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-feelings-auth'
  and (auth.jwt()->>'app_id')='feelings-turnier'
  and (auth.jwt()->>'role')='authenticated'
  and exists (
    select 1 from mastersite_feelings.profiles p
    where p.id=auth.uid() and p.approved=true and p.role='admin'
    and p.is_creator=true and lower(p.email)=lower('turnier.admin@gmx.de')
  );
$gate$;
revoke all on function mastersite_feelings_private.is_approved_admin() from PUBLIC, anon, authenticated, service_role;
revoke all on function mastersite_feelings_private.is_creator_admin() from PUBLIC, anon, authenticated, service_role;
grant execute on function mastersite_feelings_private.is_approved_admin() to authenticated;
grant execute on function mastersite_feelings_private.is_creator_admin() to authenticated;
commit;
