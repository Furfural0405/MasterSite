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
    await writeFile(file, app);
  }
}
