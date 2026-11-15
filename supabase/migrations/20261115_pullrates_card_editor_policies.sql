-- Restore Pullrates owner card-image editing only within its own issuer.
-- Pure ACL/schema migration: no card images, prices, user rows, or storage files are changed.
begin;
create or replace function mastersite_pullrates_private.can_edit_card_media()
returns boolean
language sql stable security definer
set search_path=''
as $auth$
select
  (auth.jwt()->>'iss')='https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-pullrates-auth'
  and (auth.jwt()->>'app_id')='pokemon-pullrates'
  and (auth.jwt()->>'role')='authenticated'
  and (select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid
  and exists (
    select 1 from mastersite_pullrates.profiles p
    where p.id=(select auth.uid()) and p.role='admin' and p.status='approved'
  );
$auth$;
revoke all on function mastersite_pullrates_private.can_edit_card_media() from PUBLIC,anon,authenticated,service_role;
grant execute on function mastersite_pullrates_private.can_edit_card_media() to authenticated;

-- Original app only allows admin to create and update card visual metadata.
create policy mastersite_pullrates_card_details_owner_insert on mastersite_pullrates.card_details
 for insert to authenticated
 with check((select mastersite_pullrates_private.can_edit_card_media()));
create policy mastersite_pullrates_card_details_owner_update on mastersite_pullrates.card_details
 for update to authenticated
 using((select mastersite_pullrates_private.can_edit_card_media()))
 with check((select mastersite_pullrates_private.can_edit_card_media()));
create policy mastersite_pullrates_card_images_owner_insert on mastersite_pullrates.card_images
 for insert to authenticated
 with check((select mastersite_pullrates_private.can_edit_card_media()));
create policy mastersite_pullrates_card_images_owner_update on mastersite_pullrates.card_images
 for update to authenticated
 using((select mastersite_pullrates_private.can_edit_card_media()))
 with check((select mastersite_pullrates_private.can_edit_card_media()));
grant insert,update on mastersite_pullrates.card_details to authenticated;
grant insert,update on mastersite_pullrates.card_images to authenticated;

-- Replace previous catalogue policy, which queried a private profile table
-- without a SELECT grant and could cause permission denied.
drop policy if exists mastersite_pullrates_catalog_owner on mastersite_pullrates.cardmarket_catalog;
create policy mastersite_pullrates_catalog_owner on mastersite_pullrates.cardmarket_catalog
 for select to authenticated
 using((select mastersite_pullrates_private.can_edit_card_media()));

-- Existing images remain public; only the original approved owner can upload.
create policy mastersite_pullrates_card_image_storage_insert on storage.objects
 for insert to authenticated
 with check(
    bucket_id='card-images'
    and name ~ '^[a-z0-9-]+/[0-9a-f-]+\.webp$'
    and (select mastersite_pullrates_private.can_edit_card_media())
 );
create policy mastersite_pullrates_card_image_storage_owner_select on storage.objects
 for select to authenticated
 using(
    bucket_id='card-images'
    and (select mastersite_pullrates_private.can_edit_card_media())
 );
commit;
