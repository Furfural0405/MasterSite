-- Workaround for PGRST106 as documented by Supabase Knowledge Base.
-- Keep existing public / graphql_public APIs available. Add only the two user-app schemas.
-- This is a database role-level override; Dashboard "Exposed schemas" is not authoritative
-- until it is reset using ALTER ROLE authenticator RESET pgrst.db_schemas.
alter role authenticator set pgrst.db_schemas = 'public, graphql_public, mastersite_feelings, mastersite_pullrates';
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
