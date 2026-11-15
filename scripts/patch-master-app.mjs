/**
 * Applies isolated Supabase integration only to temporary Vercel build clones.
 * Never writes to the original GitHub repositories.
 */
import {copyFile, readFile, writeFile} from "node:fs/promises";
import {join, resolve} from "node:path";

const root = resolve(".");
const TARGET_URL = "https://entbtqtyxhbozjdbdvns.supabase.co";
const TARGET_KEY = "sb_publishable_51Kjy2GfK6fDkcB7QiG5Eg_NUsGhmh2";

function requireAnchor(value, needle, name) {
  if (!value.includes(needle)) {
    throw new Error("MasterSite integration incompatible with source " + name + ": missing expected anchor.");
  }
}
export async function patchClonedApp(sourceDirectory, slug) {
  const bridge = join(root, "integrations", "mastersite-auth-bridge.mjs");
  if (slug === "feelings-turnier") {
    const original = await readFile(join(sourceDirectory, "src/lib/supabase.ts"), "utf8");
    requireAnchor(original, "createClient(", "Feelings-Turnier/src/lib/supabase.ts");
    await copyFile(bridge, join(sourceDirectory, "src/lib/mastersite-auth-bridge.js"));
    await writeFile(join(sourceDirectory, "src/lib/mastersite-auth-bridge.d.ts"), [
      'import type { SupabaseClient, createClient } from "@supabase/supabase-js";',
      "export function createMasterSiteClient(options: {",
      "  createClient: typeof createClient;",
      "  url: string;",
      "  key: string;",
      "  schema: string;",
      '  service: "feelings" | "pullrates";',
      "}): SupabaseClient;",
      "",
    ].join("\n"));
    await writeFile(join(sourceDirectory, "src/lib/supabase.ts"), [
      'import { createClient } from "@supabase/supabase-js";',
      'import { createMasterSiteClient } from "./mastersite-auth-bridge.js";',
      "const url = import.meta.env.VITE_SUPABASE_URL as string;",
      "const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;",
      "export const supabaseConfigured = Boolean(url && key);",
      "export const supabase = supabaseConfigured",
      '  ? createMasterSiteClient({createClient, url, key, schema: "mastersite_feelings", service: "feelings"})',
      "  : null;",
      "",
    ].join("\n"));

    // The original frontend did not provide a password recovery flow.
    // Patch only the local build copy; the original GitHub project remains untouched.
    const appPath=join(sourceDirectory,"src/App.tsx");
    let appText=await readFile(appPath,"utf8");
    function feelingsReplace(from,to){
      if(!appText.includes(from))throw new Error("Feelings source changed: "+from.slice(0,70));
      appText=appText.replace(from,to);
    }
    feelingsReplace(
      "    try {\n      if (authMode === 'register') {",
      "    try {\n      if (new URLSearchParams(window.location.search).has('token')) {\n        const {error}=await supabase.auth.updateUser({password})\n        if(error) throw error\n        setShowLogin(false)\n        setPassword('')\n        setNotice('Passwort geändert. Bitte melde dich mit dem neuen Passwort an.')\n        return\n      }\n      if (authMode === 'register') {",
    );
    feelingsReplace(
      "  const isAdmin = Boolean(profile?.approved && profile.role === 'admin')",
      "  useEffect(() => {\n    if (new URLSearchParams(window.location.search).has('token')) setShowLogin(true)\n  }, [])\n  const isAdmin = Boolean(profile?.approved && profile.role === 'admin')",
    );
    feelingsReplace(
      "Account wurde angelegt und wartet auf Freischaltung. Bitte melde dich jetzt normal an.",
      "Account angelegt. Bitte bestätige zuerst deine E-Mail und warte auf die Adminfreigabe.",
    );
    feelingsReplace(
      "Account angelegt. Keine E-Mail-Bestätigung nötig – die Freischaltung durch den Ersteller/Admin steht noch aus.",
      "Account angelegt. Bitte bestätige die E-Mail-Adresse; die Adminfreigabe steht noch aus.",
    );
    feelingsReplace(
      "<h2>{authMode === 'login' ? 'Admin Login' : 'Account registrieren'}</h2>",
      "<h2>{new URLSearchParams(window.location.search).has('token') ? 'Passwort zurücksetzen' : authMode === 'login' ? 'Admin Login' : 'Account registrieren'}</h2>",
    );
    feelingsReplace(
      "Neue Accounts werden ohne Bestätigungs-Mail angelegt und bleiben zunächst gesperrt. Ausschließlich der Ersteller/Admin kann sie freischalten.",
      "Neue Accounts benötigen eine bestätigte E-Mail-Adresse und die Freigabe des Erstellers/Admins.",
    );
    feelingsReplace(
      '<input className="text-input" type="password" minLength={8} required value={password}',
      '<input className="text-input" type="password" minLength={authMode === "register" || new URLSearchParams(window.location.search).has("token") ? 10 : 1} required value={password}',
    );
    feelingsReplace(
      "{authBusy ? 'Bitte warten …' : authMode === 'login' ? 'Einloggen' : 'Registrieren'}",
      "{authBusy ? 'Bitte warten …' : new URLSearchParams(window.location.search).has('token') ? 'Passwort ändern' : authMode === 'login' ? 'Einloggen' : 'Registrieren'}",
    );
    feelingsReplace(
      `<button className="auth-switch" onClick={() => setAuthMode((mode) => mode === 'login' ? 'register' : 'login')}>{authMode === 'login' ? 'Noch keinen Account? Registrieren' : 'Bereits registriert? Zum Login'}</button>`,
      `{!new URLSearchParams(window.location.search).has('token') && <button className="auth-switch" onClick={() => setAuthMode((mode) => mode === 'login' ? 'register' : 'login')}>{authMode === 'login' ? 'Noch keinen Account? Registrieren' : 'Bereits registriert? Zum Login'}</button>}{authMode === 'login' && !new URLSearchParams(window.location.search).has('token') && <button className="auth-switch" type="button" onClick={() => { if(!email.trim() || !email.includes('@')){setNotice('Bitte zuerst die E-Mail-Adresse eintragen.');return;} void supabase?.auth.resetPasswordForEmail(email,{redirectTo:window.location.origin+window.location.pathname}).then(({error}) => setNotice(error ? error.message : 'Falls ein Account existiert, wurde ein Passwort-Link per E-Mail verschickt.')) }}>Passwort vergessen?</button>}`,
    );
    await writeFile(appPath,appText);
  } else if (slug === "pokemon-pullrates") {
    const configFile = join(sourceDirectory, "config.js");
    const initialConfig = await readFile(configFile, "utf8");
    requireAnchor(initialConfig, "supabaseUrl:", "pokemon-pullrates/config.js");
    await writeFile(configFile, [
      "// MasterSite preview only: separate Better Auth account, shared Supabase database.",
      "// Publishable key is safe for browser use; never put service_role here.",
      "export const config = {",
      '  supabaseUrl: "' + TARGET_URL + '",',
      '  supabaseKey: "' + TARGET_KEY + '",',
      "};",
      "",
    ].join("\n"));
    await copyFile(bridge, join(sourceDirectory, "mastersite-auth-bridge.js"));
    const file = join(sourceDirectory, "app.js");
    let app = await readFile(file, "utf8");
    requireAnchor(app, "import {createClient} from '@supabase/supabase-js';", "pokemon-pullrates/app.js imports");
    requireAnchor(app, "client=createClient(config.supabaseUrl,config.supabaseKey);", "pokemon-pullrates/app.js connection");
    app = app.replace(
      "import {createClient} from '@supabase/supabase-js';",
      "import {createClient} from '@supabase/supabase-js';\nimport {createMasterSiteClient} from './mastersite-auth-bridge.js';",
    );
    app = app.replace(
      "client=createClient(config.supabaseUrl,config.supabaseKey);",
      'client=createMasterSiteClient({createClient,url:config.supabaseUrl,key:config.supabaseKey,schema:"mastersite_pullrates",service:"pullrates"});',
    );
    // The old realtime publication used public. If it has not been enabled on
    // the new schema, the source app automatically falls back to 30s polling.
    app = app.replaceAll("schema:'public',table:'", "schema:'mastersite_pullrates',table:'");
    requireAnchor(app, "new URLSearchParams(location.hash.slice(1)).get('type')==='recovery'", "Pullrates password recovery");
    app=app.replace(
      "new URLSearchParams(location.hash.slice(1)).get('type')==='recovery'",
      "(new URLSearchParams(location.hash.slice(1)).get('type')==='recovery'||new URLSearchParams(location.search).has('token'))",
    );

    await writeFile(file, app);
  }
}
