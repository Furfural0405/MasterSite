-- ARCHIVE/IMPORT-STAGING ONLY. DO NOT SWITCH APPLICATIONS TO THESE TABLES.
-- Generated from the live 2026-11-15 Pokémon Pullrates database structure.
-- Types/NOT NULL/PK only; excludes policies, triggers, functions, indexes, FKs, grants, realtime.
-- Objects are not exposed to any API role. Migrate production logic separately.
begin;
create schema if not exists mastersite_pullrates;
revoke all on schema mastersite_pullrates from public, anon, authenticated, service_role;

-- From public.card_details
create table if not exists mastersite_pullrates."card_details" (
  "card_id" text not null,
  "name" text not null,
  "rarity" text not null,
  "updated_at" timestamp with time zone not null,
  PRIMARY KEY (card_id)
);
alter table mastersite_pullrates."card_details" enable row level security;
revoke all on mastersite_pullrates."card_details" from public, anon, authenticated, service_role;

-- From public.card_images
create table if not exists mastersite_pullrates."card_images" (
  "card_id" text not null,
  "path" text not null,
  "updated_at" timestamp with time zone not null,
  PRIMARY KEY (card_id)
);
alter table mastersite_pullrates."card_images" enable row level security;
revoke all on mastersite_pullrates."card_images" from public, anon, authenticated, service_role;

-- From public.cardmarket_catalog
create table if not exists mastersite_pullrates."cardmarket_catalog" (
  "product_id" bigint not null,
  "name" text not null,
  "low" numeric,
  "avg7" numeric,
  "source_at" timestamp with time zone not null,
  PRIMARY KEY (product_id)
);
alter table mastersite_pullrates."cardmarket_catalog" enable row level security;
revoke all on mastersite_pullrates."cardmarket_catalog" from public, anon, authenticated, service_role;

-- From public.cardmarket_prices
create table if not exists mastersite_pullrates."cardmarket_prices" (
  "card_id" text not null,
  "cardmarket_url" text not null,
  "product_id" bigint,
  "low" numeric,
  "avg7" numeric,
  "unit_eur" numeric,
  "source_at" timestamp with time zone,
  "checked_at" timestamp with time zone,
  "status" text not null,
  PRIMARY KEY (card_id)
);
alter table mastersite_pullrates."cardmarket_prices" enable row level security;
revoke all on mastersite_pullrates."cardmarket_prices" from public, anon, authenticated, service_role;

-- From public.pull_rates
create table if not exists mastersite_pullrates."pull_rates" (
  "id" smallint not null,
  "rates" jsonb not null,
  "updated_at" timestamp with time zone not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."pull_rates" enable row level security;
revoke all on mastersite_pullrates."pull_rates" from public, anon, authenticated, service_role;

-- From pull_private.card_rarities
create table if not exists mastersite_pullrates."card_rarities" (
  "card_id" text not null,
  "rarity" text not null,
  PRIMARY KEY (card_id)
);
alter table mastersite_pullrates."card_rarities" enable row level security;
revoke all on mastersite_pullrates."card_rarities" from public, anon, authenticated, service_role;

-- From pull_private.cards
create table if not exists mastersite_pullrates."cards" (
  "id" text not null,
  "booster_slot" boolean not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."cards" enable row level security;
revoke all on mastersite_pullrates."cards" from public, anon, authenticated, service_role;

-- From pull_private.chat_bans
create table if not exists mastersite_pullrates."chat_bans" (
  "user_id" uuid not null,
  "reason" text not null,
  "created_at" timestamp with time zone not null,
  PRIMARY KEY (user_id)
);
alter table mastersite_pullrates."chat_bans" enable row level security;
revoke all on mastersite_pullrates."chat_bans" from public, anon, authenticated, service_role;

-- From pull_private.chat_blocks
create table if not exists mastersite_pullrates."chat_blocks" (
  "blocker" uuid not null,
  "blocked" uuid not null,
  PRIMARY KEY (blocker, blocked)
);
alter table mastersite_pullrates."chat_blocks" enable row level security;
revoke all on mastersite_pullrates."chat_blocks" from public, anon, authenticated, service_role;

-- From pull_private.chat_consents
create table if not exists mastersite_pullrates."chat_consents" (
  "user_id" uuid not null,
  "version" text not null,
  "accepted_at" timestamp with time zone not null,
  PRIMARY KEY (user_id, version)
);
alter table mastersite_pullrates."chat_consents" enable row level security;
revoke all on mastersite_pullrates."chat_consents" from public, anon, authenticated, service_role;

-- From pull_private.chat_conversations
create table if not exists mastersite_pullrates."chat_conversations" (
  "id" uuid not null,
  "a" uuid not null,
  "b" uuid not null,
  "inviter" uuid not null,
  "status" text not null,
  "ttl" integer not null,
  "proposed_ttl" integer,
  "proposer" uuid,
  "version" integer not null,
  "created_at" timestamp with time zone not null,
  "updated_at" timestamp with time zone not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."chat_conversations" enable row level security;
revoke all on mastersite_pullrates."chat_conversations" from public, anon, authenticated, service_role;

-- From pull_private.chat_devices
create table if not exists mastersite_pullrates."chat_devices" (
  "id" uuid not null,
  "owner_id" uuid not null,
  "label" text not null,
  "public_key" jsonb not null,
  "status" text not null,
  "encrypted_grant" jsonb,
  "created_at" timestamp with time zone not null,
  "approved_at" timestamp with time zone,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."chat_devices" enable row level security;
revoke all on mastersite_pullrates."chat_devices" from public, anon, authenticated, service_role;

-- From pull_private.chat_identities
create table if not exists mastersite_pullrates."chat_identities" (
  "user_id" uuid not null,
  "public_bundle" jsonb not null,
  "key_id" text not null,
  "encrypted_vault" jsonb not null,
  "created_at" timestamp with time zone not null,
  PRIMARY KEY (user_id)
);
alter table mastersite_pullrates."chat_identities" enable row level security;
revoke all on mastersite_pullrates."chat_identities" from public, anon, authenticated, service_role;

-- From pull_private.chat_members
create table if not exists mastersite_pullrates."chat_members" (
  "conversation_id" uuid not null,
  "user_id" uuid not null,
  "hidden_before" bigint not null,
  "archived" boolean not null,
  "read_seq" bigint not null,
  PRIMARY KEY (conversation_id, user_id)
);
alter table mastersite_pullrates."chat_members" enable row level security;
revoke all on mastersite_pullrates."chat_members" from public, anon, authenticated, service_role;

-- From pull_private.chat_messages
create table if not exists mastersite_pullrates."chat_messages" (
  "id" uuid not null,
  "seq" bigint not null,
  "conversation_id" uuid not null,
  "sender" uuid not null,
  "envelope" jsonb not null,
  "sent_at" timestamp with time zone not null,
  "expires_at" timestamp with time zone,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."chat_messages" enable row level security;
revoke all on mastersite_pullrates."chat_messages" from public, anon, authenticated, service_role;

-- From pull_private.chat_reports
create table if not exists mastersite_pullrates."chat_reports" (
  "id" uuid not null,
  "conversation_id" uuid not null,
  "reporter" uuid not null,
  "evidence" jsonb not null,
  "encrypted_packet" jsonb,
  "admin_key_id" text not null,
  "reporter_public" jsonb not null,
  "status" text not null,
  "created_at" timestamp with time zone not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."chat_reports" enable row level security;
revoke all on mastersite_pullrates."chat_reports" from public, anon, authenticated, service_role;

-- From pull_private.chat_rules
create table if not exists mastersite_pullrates."chat_rules" (
  "version" text not null,
  "body" text not null,
  "active" boolean not null,
  PRIMARY KEY (version)
);
alter table mastersite_pullrates."chat_rules" enable row level security;
revoke all on mastersite_pullrates."chat_rules" from public, anon, authenticated, service_role;

-- From pull_private.history
create table if not exists mastersite_pullrates."history" (
  "id" bigint not null,
  "actor" uuid,
  "target" uuid,
  "action" text not null,
  "previous_state" jsonb,
  "created_at" timestamp with time zone not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."history" enable row level security;
revoke all on mastersite_pullrates."history" from public, anon, authenticated, service_role;

-- From pull_private.inventory
create table if not exists mastersite_pullrates."inventory" (
  "list_id" uuid not null,
  "master" jsonb not null,
  "binder" jsonb not null,
  "given" jsonb not null,
  "revision" integer not null,
  PRIMARY KEY (list_id)
);
alter table mastersite_pullrates."inventory" enable row level security;
revoke all on mastersite_pullrates."inventory" from public, anon, authenticated, service_role;

-- From pull_private.inventory_requests
create table if not exists mastersite_pullrates."inventory_requests" (
  "request_id" uuid not null,
  "list_id" uuid not null,
  "payload" jsonb not null,
  "result" jsonb not null,
  "created_at" timestamp with time zone not null,
  PRIMARY KEY (request_id)
);
alter table mastersite_pullrates."inventory_requests" enable row level security;
revoke all on mastersite_pullrates."inventory_requests" from public, anon, authenticated, service_role;

-- From pull_private.lists
create table if not exists mastersite_pullrates."lists" (
  "id" uuid not null,
  "owner_id" uuid not null,
  "name" text not null,
  "purpose" text not null,
  "visibility" text not null,
  "display" text not null,
  "counts" jsonb not null,
  "version" integer not null,
  "snapshot" jsonb,
  "snapshot_version" integer,
  "owner_live" boolean not null,
  "is_legacy" boolean not null,
  "updated_at" timestamp with time zone not null,
  "value_public" boolean not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."lists" enable row level security;
revoke all on mastersite_pullrates."lists" from public, anon, authenticated, service_role;

-- From pull_private.market_worker_state
create table if not exists mastersite_pullrates."market_worker_state" (
  "id" boolean not null,
  "token_hash" text not null,
  "running_until" timestamp with time zone,
  "last_attempt" timestamp with time zone,
  "last_success" timestamp with time zone,
  "last_error" text,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."market_worker_state" enable row level security;
revoke all on mastersite_pullrates."market_worker_state" from public, anon, authenticated, service_role;

-- From pull_private.profiles
create table if not exists mastersite_pullrates."profiles" (
  "id" uuid not null,
  "email" text not null,
  "status" text not null,
  "role" text not null,
  "counts" jsonb not null,
  "version" integer not null,
  "snapshot" jsonb,
  "snapshot_version" integer,
  "updated_at" timestamp with time zone not null,
  "request_archived" boolean not null,
  "username" text,
  "username_blocked" boolean not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."profiles" enable row level security;
revoke all on mastersite_pullrates."profiles" from public, anon, authenticated, service_role;

-- From pull_private.settings
create table if not exists mastersite_pullrates."settings" (
  "id" boolean not null,
  "admin_email" text,
  "show_public_counts" boolean not null,
  PRIMARY KEY (id)
);
alter table mastersite_pullrates."settings" enable row level security;
revoke all on mastersite_pullrates."settings" from public, anon, authenticated, service_role;

-- From pull_private.trade_transfer_marks
create table if not exists mastersite_pullrates."trade_transfer_marks" (
  "source_id" uuid not null,
  "target_id" uuid not null,
  "card_id" text not null,
  "pull_count" integer not null,
  "version" integer not null,
  PRIMARY KEY (source_id, target_id, card_id)
);
alter table mastersite_pullrates."trade_transfer_marks" enable row level security;
revoke all on mastersite_pullrates."trade_transfer_marks" from public, anon, authenticated, service_role;
commit;
