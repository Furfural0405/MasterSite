import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

const feeling=readFileSync("supabase/functions/mastersite-feelings-auth/index.ts","utf8");
const pull=readFileSync("supabase/functions/mastersite-pullrates-auth/index.ts","utf8");
const migrations=[
  readFileSync("supabase/migrations/20261115_independent_better_auth_accounts.sql","utf8"),
  readFileSync("supabase/migrations/20261115_pending_profiles_for_new_better_auth_users.sql","utf8"),
  readFileSync("supabase/migrations/20261115_pullrates_profile_registration_defaults.sql","utf8")
].join("\n");

test("Separate Auth-Services cannot share schema or secrets",()=>{
  assert.match(feeling,/const SERVICE = "feelings-turnier"/);
  assert.match(pull,/const SERVICE = "pokemon-pullrates"/);
  assert.match(feeling,/const SCHEMA = "mastersite_feelings_auth"/);
  assert.match(pull,/const SCHEMA = "mastersite_pullrates_auth"/);
  for(const code of [feeling,pull]){
    assert.match(code,/auth_runtime_config where service_name=\$1/);
    assert.match(code,/!enabled.*AUTH_MIGRATION_NOT_ACTIVATED/);
    assert.match(code,/new PostgresDialect/);
    assert.match(code,/schemaName: SCHEMA/);
    assert.match(code,/bcrypt\.compare/);
    assert.match(code,/cookiePrefix:/);
    assert.match(code,/generateId: \(\) => crypto\.randomUUID\(\)/);
    assert.doesNotMatch(code,/SUPABASE_SERVICE_ROLE_KEY/);
  }
});

test("Auth passwords and JWT keys remain isolated from public SQL roles",()=>{
  assert.match(migrations,/revoke all on schema .* from public, anon, authenticated, service_role/i);
  assert.match(migrations,/alter table mastersite_feelings_auth\."user" enable row level security|alter table %I\."user" enable row level security/);
  assert.match(migrations,/encrypted_password/);
  assert.match(migrations,/create_pending_feelings_profile/);
  assert.match(migrations,/create_pending_pullrates_profile/);
  assert.match(migrations,/request_archived set default false/);
});

test("New profiles default to pending, not admin",()=>{
  assert.match(migrations,/false,'viewer'.*false,'pending'/);
  assert.match(migrations,/'pending','user'/);
  for(const code of [feeling,pull])assert.match(code,/requireEmailVerification: true/);
});
