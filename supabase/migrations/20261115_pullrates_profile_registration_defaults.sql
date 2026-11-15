begin;
-- Match the source application's safe default values on the private migration mirror.
alter table mastersite_pullrates.profiles
  alter column status set default 'pending',
  alter column role set default 'user',
  alter column counts set default '{}'::jsonb,
  alter column version set default 0,
  alter column updated_at set default now(),
  alter column request_archived set default false,
  alter column username_blocked set default false;
commit;