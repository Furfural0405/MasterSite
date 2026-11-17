-- Revert custom PostgREST schema override if the Supabase dashboard is managing
-- the same settings or when this workaround is no longer needed.
-- DOES NOT ALTER/DROP any application data.
alter role authenticator reset pgrst.db_schemas;
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
