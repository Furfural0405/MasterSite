-- The preservation archives are append-only.
-- This prevents accidental UPDATE/DELETE even by a privileged migration routine.
create or replace function mastersite_preservation.reject_snapshot_mutation()
returns trigger language plpgsql security invoker set search_path=''
as $guard$
begin
  raise exception 'MASTERSITE_ARCHIVE_APPEND_ONLY: existing backup snapshots must not be modified';
end;
$guard$;
revoke all on function mastersite_preservation.reject_snapshot_mutation() from PUBLIC,anon,authenticated,service_role;
drop trigger if exists mastersite_preservation_archive_append_only on mastersite_preservation.archives;
create trigger mastersite_preservation_archive_append_only
before update or delete on mastersite_preservation.archives
for each row execute function mastersite_preservation.reject_snapshot_mutation();
