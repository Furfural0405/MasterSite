-- Non-destructive schema fidelity for pullrates source app.
-- Apply only after the function migration. All existing row values are preserved.
-- Never run DELETE/TRUNCATE or rewrite existing user data.
begin;

-- Existing values remain untouched; only future INSERT defaults are applied.
alter table mastersite_pullrates."card_details" alter column "updated_at" set default now();
alter table mastersite_pullrates."card_images" alter column "updated_at" set default now();
-- mastersite_pullrates."cardmarket_prices"."unit_eur" originally GENERATED s: preserving already copied values, do not drop/rewrite this column.
alter table mastersite_pullrates."cardmarket_prices" alter column "status" set default 'unmapped'::text;
alter table mastersite_pullrates."pull_rates" alter column "rates" set default '{}'::jsonb;
alter table mastersite_pullrates."pull_rates" alter column "updated_at" set default now();
alter table mastersite_pullrates."chat_bans" alter column "created_at" set default now();
alter table mastersite_pullrates."chat_consents" alter column "accepted_at" set default clock_timestamp();
alter table mastersite_pullrates."chat_conversations" alter column "id" set default gen_random_uuid();
alter table mastersite_pullrates."chat_conversations" alter column "status" set default 'pending'::text;
alter table mastersite_pullrates."chat_conversations" alter column "ttl" set default 0;
alter table mastersite_pullrates."chat_conversations" alter column "version" set default 0;
alter table mastersite_pullrates."chat_conversations" alter column "created_at" set default now();
alter table mastersite_pullrates."chat_conversations" alter column "updated_at" set default now();
alter table mastersite_pullrates."chat_devices" alter column "created_at" set default now();
alter table mastersite_pullrates."chat_identities" alter column "created_at" set default now();
alter table mastersite_pullrates."chat_members" alter column "hidden_before" set default 0;
alter table mastersite_pullrates."chat_members" alter column "archived" set default false;
alter table mastersite_pullrates."chat_members" alter column "read_seq" set default 0;
alter table mastersite_pullrates."chat_messages" alter column "sent_at" set default clock_timestamp();
alter table mastersite_pullrates."chat_reports" alter column "id" set default gen_random_uuid();
alter table mastersite_pullrates."chat_reports" alter column "status" set default 'draft'::text;
alter table mastersite_pullrates."chat_reports" alter column "created_at" set default clock_timestamp();
alter table mastersite_pullrates."chat_rules" alter column "active" set default true;
alter table mastersite_pullrates."history" alter column "created_at" set default now();
alter table mastersite_pullrates."inventory" alter column "master" set default '{}'::jsonb;
alter table mastersite_pullrates."inventory" alter column "binder" set default '{}'::jsonb;
alter table mastersite_pullrates."inventory" alter column "given" set default '{}'::jsonb;
alter table mastersite_pullrates."inventory" alter column "revision" set default 0;
alter table mastersite_pullrates."inventory_requests" alter column "created_at" set default now();
alter table mastersite_pullrates."lists" alter column "id" set default gen_random_uuid();
alter table mastersite_pullrates."lists" alter column "purpose" set default 'pulls'::text;
alter table mastersite_pullrates."lists" alter column "visibility" set default 'private'::text;
alter table mastersite_pullrates."lists" alter column "display" set default 'all'::text;
alter table mastersite_pullrates."lists" alter column "counts" set default '{}'::jsonb;
alter table mastersite_pullrates."lists" alter column "version" set default 0;
alter table mastersite_pullrates."lists" alter column "owner_live" set default false;
alter table mastersite_pullrates."lists" alter column "is_legacy" set default false;
alter table mastersite_pullrates."lists" alter column "updated_at" set default now();
alter table mastersite_pullrates."lists" alter column "value_public" set default false;
alter table mastersite_pullrates."market_worker_state" alter column "id" set default true;
alter table mastersite_pullrates."profiles" alter column "status" set default 'pending'::text;
alter table mastersite_pullrates."profiles" alter column "role" set default 'user'::text;
alter table mastersite_pullrates."profiles" alter column "counts" set default '{}'::jsonb;
alter table mastersite_pullrates."profiles" alter column "version" set default 0;
alter table mastersite_pullrates."profiles" alter column "updated_at" set default now();
alter table mastersite_pullrates."profiles" alter column "request_archived" set default false;
alter table mastersite_pullrates."profiles" alter column "username_blocked" set default false;
alter table mastersite_pullrates."settings" alter column "id" set default true;
alter table mastersite_pullrates."settings" alter column "show_public_counts" set default false;
alter table mastersite_pullrates."trade_transfer_marks" alter column "version" set default 1;
-- Identity sequences are aligned beyond the highest preserved value.
do $id$
begin
  if coalesce((select a.attidentity from pg_attribute a join pg_class cls on cls.oid=a.attrelid join pg_namespace ns on ns.oid=cls.relnamespace where ns.nspname='mastersite_pullrates' and cls.relname='chat_messages' and a.attname='seq'),'')='' then
    alter table mastersite_pullrates."chat_messages" alter column "seq" add generated by default as identity;
  end if;
  perform setval(pg_get_serial_sequence('mastersite_pullrates.chat_messages','seq'),
    greatest(coalesce((select max("seq")::bigint from mastersite_pullrates."chat_messages"),0)+1,1),false);
end $id$;
do $id$
begin
  if coalesce((select a.attidentity from pg_attribute a join pg_class cls on cls.oid=a.attrelid join pg_namespace ns on ns.oid=cls.relnamespace where ns.nspname='mastersite_pullrates' and cls.relname='history' and a.attname='id'),'')='' then
    alter table mastersite_pullrates."history" alter column "id" add generated by default as identity;
  end if;
  perform setval(pg_get_serial_sequence('mastersite_pullrates.history','id'),
    greatest(coalesce((select max("id")::bigint from mastersite_pullrates."history"),0)+1,1),false);
end $id$;
-- Mirror source CHECK / UNIQUE and internal FK constraints (no cross-app auth.users FKs).
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_details' and cc.conname='card_details_name_check') then
   alter table mastersite_pullrates."card_details" add constraint "card_details_name_check" CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 100);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_details' and cc.conname='card_details_rarity_check') then
   alter table mastersite_pullrates."card_details" add constraint "card_details_rarity_check" CHECK (rarity = ANY (ARRAY['Common'::text, 'Rare'::text, 'Double Rare'::text, 'Pikachu Rare'::text, 'Art Rare'::text, 'Special Art Rare'::text, 'Futuristic Rare'::text, 'Reprint'::text, 'RGB'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_images' and cc.conname='card_images_check') then
   alter table mastersite_pullrates."card_images" add constraint "card_images_check" CHECK (split_part(path, '/'::text, 1) = card_id AND path ~ '^[a-z0-9-]+/[0-9a-f-]+\.webp$'::text);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_catalog' and cc.conname='cardmarket_catalog_avg7_check') then
   alter table mastersite_pullrates."cardmarket_catalog" add constraint "cardmarket_catalog_avg7_check" CHECK (avg7 >= 0::numeric);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_catalog' and cc.conname='cardmarket_catalog_low_check') then
   alter table mastersite_pullrates."cardmarket_catalog" add constraint "cardmarket_catalog_low_check" CHECK (low >= 0::numeric);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_avg7_check') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_avg7_check" CHECK (avg7 >= 0::numeric);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_cardmarket_url_check') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_cardmarket_url_check" CHECK (cardmarket_url ~ '^https://www[.]cardmarket[.]com/(de|en)/Pokemon/Products/Singles/30th-Celebration-Simplified-Chinese/[A-Za-z0-9-]+$'::text);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_low_check') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_low_check" CHECK (low >= 0::numeric);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_status_check') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_status_check" CHECK (status = ANY (ARRAY['unmapped'::text, 'ok'::text, 'missing'::text, 'error'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='pull_rates' and cc.conname='pull_rates_id_check') then
   alter table mastersite_pullrates."pull_rates" add constraint "pull_rates_id_check" CHECK (id = 1);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_blocks' and cc.conname='chat_blocks_check') then
   alter table mastersite_pullrates."chat_blocks" add constraint "chat_blocks_check" CHECK (blocker <> blocked);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_check') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_check" CHECK (a < b);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_check1') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_check1" CHECK (inviter = a OR inviter = b);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_check2') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_check2" CHECK (proposer IS NULL OR proposer = a OR proposer = b);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_proposed_ttl_check') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_proposed_ttl_check" CHECK (proposed_ttl = ANY (ARRAY[0, 86400, 604800, 2592000, 7776000]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_status_check') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_ttl_check') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_ttl_check" CHECK (ttl = ANY (ARRAY[0, 86400, 604800, 2592000, 7776000]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_a_b_key') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_a_b_key" UNIQUE (a, b);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_devices' and cc.conname='chat_devices_label_check') then
   alter table mastersite_pullrates."chat_devices" add constraint "chat_devices_label_check" CHECK (char_length(label) >= 1 AND char_length(label) <= 80);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_devices' and cc.conname='chat_devices_status_check') then
   alter table mastersite_pullrates."chat_devices" add constraint "chat_devices_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'revoked'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_messages' and cc.conname='chat_messages_seq_key') then
   alter table mastersite_pullrates."chat_messages" add constraint "chat_messages_seq_key" UNIQUE (seq);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_reports' and cc.conname='chat_reports_status_check') then
   alter table mastersite_pullrates."chat_reports" add constraint "chat_reports_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'open'::text, 'closed'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='lists' and cc.conname='lists_display_check') then
   alter table mastersite_pullrates."lists" add constraint "lists_display_check" CHECK (display = ANY (ARRAY['all'::text, 'hide_boosters'::text, 'rates_only'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='lists' and cc.conname='lists_name_check') then
   alter table mastersite_pullrates."lists" add constraint "lists_name_check" CHECK (char_length(btrim(name)) >= 1 AND char_length(btrim(name)) <= 80);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='lists' and cc.conname='lists_purpose_check') then
   alter table mastersite_pullrates."lists" add constraint "lists_purpose_check" CHECK (purpose = ANY (ARRAY['pulls'::text, 'trade'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='lists' and cc.conname='lists_visibility_check') then
   alter table mastersite_pullrates."lists" add constraint "lists_visibility_check" CHECK (visibility = ANY (ARRAY['private'::text, 'public'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='market_worker_state' and cc.conname='market_worker_state_id_check') then
   alter table mastersite_pullrates."market_worker_state" add constraint "market_worker_state_id_check" CHECK (id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='profiles' and cc.conname='profiles_role_check') then
   alter table mastersite_pullrates."profiles" add constraint "profiles_role_check" CHECK (role = ANY (ARRAY['user'::text, 'admin'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='profiles' and cc.conname='profiles_status_check') then
   alter table mastersite_pullrates."profiles" add constraint "profiles_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='settings' and cc.conname='settings_id_check') then
   alter table mastersite_pullrates."settings" add constraint "settings_id_check" CHECK (id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='trade_transfer_marks' and cc.conname='trade_transfer_marks_pull_count_check') then
   alter table mastersite_pullrates."trade_transfer_marks" add constraint "trade_transfer_marks_pull_count_check" CHECK (pull_count >= 0 AND pull_count <= 1000000);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_details' and cc.conname='card_details_card_id_fkey') then
   alter table mastersite_pullrates."card_details" add constraint "card_details_card_id_fkey" FOREIGN KEY (card_id) REFERENCES mastersite_pullrates."cards"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_images' and cc.conname='card_images_card_id_fkey') then
   alter table mastersite_pullrates."card_images" add constraint "card_images_card_id_fkey" FOREIGN KEY (card_id) REFERENCES mastersite_pullrates."cards"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_card_id_fkey') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_card_id_fkey" FOREIGN KEY (card_id) REFERENCES mastersite_pullrates."cards"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='cardmarket_prices' and cc.conname='cardmarket_prices_product_id_fkey') then
   alter table mastersite_pullrates."cardmarket_prices" add constraint "cardmarket_prices_product_id_fkey" FOREIGN KEY (product_id) REFERENCES mastersite_pullrates."cardmarket_catalog"(product_id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='card_rarities' and cc.conname='card_rarities_card_id_fkey') then
   alter table mastersite_pullrates."card_rarities" add constraint "card_rarities_card_id_fkey" FOREIGN KEY (card_id) REFERENCES mastersite_pullrates."cards"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_bans' and cc.conname='chat_bans_user_id_fkey') then
   alter table mastersite_pullrates."chat_bans" add constraint "chat_bans_user_id_fkey" FOREIGN KEY (user_id) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_blocks' and cc.conname='chat_blocks_blocked_fkey') then
   alter table mastersite_pullrates."chat_blocks" add constraint "chat_blocks_blocked_fkey" FOREIGN KEY (blocked) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_blocks' and cc.conname='chat_blocks_blocker_fkey') then
   alter table mastersite_pullrates."chat_blocks" add constraint "chat_blocks_blocker_fkey" FOREIGN KEY (blocker) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_consents' and cc.conname='chat_consents_user_id_fkey') then
   alter table mastersite_pullrates."chat_consents" add constraint "chat_consents_user_id_fkey" FOREIGN KEY (user_id) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_consents' and cc.conname='chat_consents_version_fkey') then
   alter table mastersite_pullrates."chat_consents" add constraint "chat_consents_version_fkey" FOREIGN KEY (version) REFERENCES mastersite_pullrates."chat_rules"(version);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_a_fkey') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_a_fkey" FOREIGN KEY (a) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_b_fkey') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_b_fkey" FOREIGN KEY (b) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_conversations' and cc.conname='chat_conversations_inviter_fkey') then
   alter table mastersite_pullrates."chat_conversations" add constraint "chat_conversations_inviter_fkey" FOREIGN KEY (inviter) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_devices' and cc.conname='chat_devices_owner_id_fkey') then
   alter table mastersite_pullrates."chat_devices" add constraint "chat_devices_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_identities' and cc.conname='chat_identities_user_id_fkey') then
   alter table mastersite_pullrates."chat_identities" add constraint "chat_identities_user_id_fkey" FOREIGN KEY (user_id) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_members' and cc.conname='chat_members_conversation_id_fkey') then
   alter table mastersite_pullrates."chat_members" add constraint "chat_members_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES mastersite_pullrates."chat_conversations"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_members' and cc.conname='chat_members_user_id_fkey') then
   alter table mastersite_pullrates."chat_members" add constraint "chat_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_messages' and cc.conname='chat_messages_conversation_id_fkey') then
   alter table mastersite_pullrates."chat_messages" add constraint "chat_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES mastersite_pullrates."chat_conversations"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_messages' and cc.conname='chat_messages_sender_fkey') then
   alter table mastersite_pullrates."chat_messages" add constraint "chat_messages_sender_fkey" FOREIGN KEY (sender) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_reports' and cc.conname='chat_reports_conversation_id_fkey') then
   alter table mastersite_pullrates."chat_reports" add constraint "chat_reports_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES mastersite_pullrates."chat_conversations"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='chat_reports' and cc.conname='chat_reports_reporter_fkey') then
   alter table mastersite_pullrates."chat_reports" add constraint "chat_reports_reporter_fkey" FOREIGN KEY (reporter) REFERENCES mastersite_pullrates."profiles"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='inventory' and cc.conname='inventory_list_id_fkey') then
   alter table mastersite_pullrates."inventory" add constraint "inventory_list_id_fkey" FOREIGN KEY (list_id) REFERENCES mastersite_pullrates."lists"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='inventory_requests' and cc.conname='inventory_requests_list_id_fkey') then
   alter table mastersite_pullrates."inventory_requests" add constraint "inventory_requests_list_id_fkey" FOREIGN KEY (list_id) REFERENCES mastersite_pullrates."lists"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='lists' and cc.conname='lists_owner_id_fkey') then
   alter table mastersite_pullrates."lists" add constraint "lists_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES mastersite_pullrates."profiles"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='trade_transfer_marks' and cc.conname='trade_transfer_marks_card_id_fkey') then
   alter table mastersite_pullrates."trade_transfer_marks" add constraint "trade_transfer_marks_card_id_fkey" FOREIGN KEY (card_id) REFERENCES mastersite_pullrates."cards"(id);
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='trade_transfer_marks' and cc.conname='trade_transfer_marks_source_id_fkey') then
   alter table mastersite_pullrates."trade_transfer_marks" add constraint "trade_transfer_marks_source_id_fkey" FOREIGN KEY (source_id) REFERENCES mastersite_pullrates."lists"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
do $constraint$
begin
 if not exists (select 1 from pg_constraint cc join pg_class tbl on tbl.oid=cc.conrelid join pg_namespace ns on ns.oid=tbl.relnamespace where ns.nspname='mastersite_pullrates' and tbl.relname='trade_transfer_marks' and cc.conname='trade_transfer_marks_target_id_fkey') then
   alter table mastersite_pullrates."trade_transfer_marks" add constraint "trade_transfer_marks_target_id_fkey" FOREIGN KEY (target_id) REFERENCES mastersite_pullrates."lists"(id) ON DELETE CASCADE;
 end if;
end $constraint$;
-- Secondary indexes (CREATE IF NOT EXISTS).
CREATE UNIQUE INDEX IF NOT EXISTS card_details_pkey ON mastersite_pullrates.card_details USING btree (card_id);
CREATE UNIQUE INDEX IF NOT EXISTS card_images_pkey ON mastersite_pullrates.card_images USING btree (card_id);
CREATE UNIQUE INDEX IF NOT EXISTS cardmarket_catalog_pkey ON mastersite_pullrates.cardmarket_catalog USING btree (product_id);
CREATE UNIQUE INDEX IF NOT EXISTS cardmarket_prices_pkey ON mastersite_pullrates.cardmarket_prices USING btree (card_id);
CREATE UNIQUE INDEX IF NOT EXISTS pull_rates_pkey ON mastersite_pullrates.pull_rates USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS card_rarities_pkey ON mastersite_pullrates.card_rarities USING btree (card_id);
CREATE UNIQUE INDEX IF NOT EXISTS cards_pkey ON mastersite_pullrates.cards USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_bans_pkey ON mastersite_pullrates.chat_bans USING btree (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_blocks_pkey ON mastersite_pullrates.chat_blocks USING btree (blocker, blocked);
CREATE UNIQUE INDEX IF NOT EXISTS chat_consents_pkey ON mastersite_pullrates.chat_consents USING btree (user_id, version);
CREATE INDEX IF NOT EXISTS chat_conversation_b ON mastersite_pullrates.chat_conversations USING btree (b);
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_a_b_key ON mastersite_pullrates.chat_conversations USING btree (a, b);
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_pkey ON mastersite_pullrates.chat_conversations USING btree (id);
CREATE INDEX IF NOT EXISTS chat_device_owner ON mastersite_pullrates.chat_devices USING btree (owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_devices_pkey ON mastersite_pullrates.chat_devices USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_identities_pkey ON mastersite_pullrates.chat_identities USING btree (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_members_pkey ON mastersite_pullrates.chat_members USING btree (conversation_id, user_id);
CREATE INDEX IF NOT EXISTS chat_message_conversation ON mastersite_pullrates.chat_messages USING btree (conversation_id, seq);
CREATE INDEX IF NOT EXISTS chat_message_expiry ON mastersite_pullrates.chat_messages USING btree (expires_at) WHERE (expires_at IS NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS chat_messages_pkey ON mastersite_pullrates.chat_messages USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_messages_seq_key ON mastersite_pullrates.chat_messages USING btree (seq);
CREATE INDEX IF NOT EXISTS chat_report_status ON mastersite_pullrates.chat_reports USING btree (status, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS chat_reports_pkey ON mastersite_pullrates.chat_reports USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS chat_one_active_rules ON mastersite_pullrates.chat_rules USING btree (active) WHERE active;
CREATE UNIQUE INDEX IF NOT EXISTS chat_rules_pkey ON mastersite_pullrates.chat_rules USING btree (version);
CREATE UNIQUE INDEX IF NOT EXISTS history_pkey ON mastersite_pullrates.history USING btree (id);
CREATE INDEX IF NOT EXISTS history_target_idx ON mastersite_pullrates.history USING btree (target);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_pkey ON mastersite_pullrates.inventory USING btree (list_id);
CREATE INDEX IF NOT EXISTS inventory_requests_list ON mastersite_pullrates.inventory_requests USING btree (list_id);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_requests_pkey ON mastersite_pullrates.inventory_requests USING btree (request_id);
CREATE UNIQUE INDEX IF NOT EXISTS lists_one_legacy ON mastersite_pullrates.lists USING btree (owner_id) WHERE is_legacy;
CREATE INDEX IF NOT EXISTS lists_owner ON mastersite_pullrates.lists USING btree (owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS lists_pkey ON mastersite_pullrates.lists USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS market_worker_state_pkey ON mastersite_pullrates.market_worker_state USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_pkey ON mastersite_pullrates.profiles USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_unique ON mastersite_pullrates.profiles USING btree (lower(username)) WHERE (username IS NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS settings_pkey ON mastersite_pullrates.settings USING btree (id);
CREATE UNIQUE INDEX IF NOT EXISTS trade_transfer_marks_pkey ON mastersite_pullrates.trade_transfer_marks USING btree (source_id, target_id, card_id);
-- App-specific triggers (not the old auth.users triggers).
do $trigger$
begin
 if not exists (select 1 from pg_trigger tt join pg_class c on c.oid=tt.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='mastersite_pullrates' and c.relname='lists' and tt.tgname='guard_stock_totals') then
   CREATE TRIGGER guard_stock_totals BEFORE UPDATE OF counts, purpose ON mastersite_pullrates.lists FOR EACH ROW EXECUTE FUNCTION mastersite_pullrates_private.guard_stock_totals();
 end if;
end $trigger$;
do $trigger$
begin
 if not exists (select 1 from pg_trigger tt join pg_class c on c.oid=tt.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='mastersite_pullrates' and c.relname='profiles' and tt.tgname='profiles_sync_lists') then
   CREATE TRIGGER profiles_sync_lists AFTER INSERT OR UPDATE ON mastersite_pullrates.profiles FOR EACH ROW EXECUTE FUNCTION mastersite_pullrates_private.sync_legacy_list();
 end if;
end $trigger$;
commit;
