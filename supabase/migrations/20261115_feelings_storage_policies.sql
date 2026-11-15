-- MasterSite storage parity for Feelings-Turnier.
-- Creates an empty site-assets bucket only if absent. Never overwrites or deletes files.
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('site-assets','site-assets',true,10485760,array['image/png','image/jpeg','image/webp'])
on conflict(id) do nothing;
create policy "mastersite_feelings_site_assets_insert" on storage.objects
for insert to authenticated
with check(
 bucket_id='site-assets'
 and (storage.foldername(name))[1]='backgrounds'
 and lower(storage.extension(name))=any(array['png','jpg','jpeg','webp'])
 and (select mastersite_feelings_private.is_approved_admin())
);
create policy "mastersite_feelings_site_assets_select" on storage.objects
for select to authenticated
using(
 bucket_id='site-assets'
 and (storage.foldername(name))[1]='backgrounds'
 and (select mastersite_feelings_private.is_approved_admin())
);
create policy "mastersite_feelings_site_assets_update" on storage.objects
for update to authenticated
using(
 bucket_id='site-assets'
 and (storage.foldername(name))[1]='backgrounds'
 and (select mastersite_feelings_private.is_approved_admin())
)
with check(
 bucket_id='site-assets'
 and (storage.foldername(name))[1]='backgrounds'
 and lower(storage.extension(name))=any(array['png','jpg','jpeg','webp'])
 and (select mastersite_feelings_private.is_approved_admin())
);
create policy "mastersite_feelings_site_assets_delete" on storage.objects
for delete to authenticated
using(
 bucket_id='site-assets'
 and (storage.foldername(name))[1]='backgrounds'
 and (select mastersite_feelings_private.is_approved_admin())
);
commit;
