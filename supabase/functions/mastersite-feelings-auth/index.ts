import { betterAuth } from "npm:better-auth@1.7.21";
import { jwt } from "npm:better-auth@1.7.21/plugins";
import bcrypt from "npm:bcryptjs@3.0.2";
import pg from "npm:pg@8.16.3";
import { PostgresDialect } from "npm:kysely@0.28.7";

const SERVICE = "feelings-turnier";
const SCHEMA = "mastersite_feelings_auth";
const SLUG = "mastersite-feelings-auth";
const ORIGIN = "https://entbtqtyxhbozjdbdvns.supabase.co";
const basePath = "/functions/v1/" + SLUG;
const pool = new pg.Pool({
  connectionString: Deno.env.get("SUPABASE_DB_URL") || "",
  max: 1,
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 10000,
});

let runtimePromise: Promise<{ auth: ReturnType<typeof betterAuth> }> | null = null;
async function isEnabledNow(): Promise<boolean> {
  const r = await pool.query("select enabled from mastersite_migration.auth_runtime_config where service_name=$1",[SERVICE]);
  return r.rows[0]?.enabled === true;
}
async function loadRuntime() {
  const result = await pool.query(
    "select auth_secret, enabled from mastersite_migration.auth_runtime_config where service_name=$1",
    [SERVICE],
  );
  if (result.rowCount !== 1 || typeof result.rows[0].auth_secret !== "string") {
    throw new Error("Auth configuration unavailable");
  }
  const auth = betterAuth({
    baseURL: ORIGIN,
    basePath,
    secret: result.rows[0].auth_secret,
    trustedOrigins: ["https://furfural0405.github.io"],
    database: {
      dialect: new PostgresDialect({ pool }),
      type: "postgres",
      schemaName: SCHEMA,
    },
    emailAndPassword: {
      enabled: true,
      disableSignUp: true,
      requireEmailVerification: true,
      password: {
        hash: async (password: string) => bcrypt.hash(password, 12),
        verify: async ({ hash, password }: { hash: string; password: string }) =>
          bcrypt.compare(password, hash),
      },
    },
    advanced: {
      cookiePrefix: "mastersite_feelings",
      useSecureCookies: true,
      database: { generateId: () => crypto.randomUUID() },
    },
    plugins: [
      jwt({
        jwt: {
          issuer: ORIGIN + basePath,
          audience: ORIGIN + basePath,
          definePayload: ({ user }) => ({
            sub: user.id,
            role: "authenticated",
            app_id: SERVICE,
          }),
        },
      }),
    ],
  });
  return { auth };
}

Deno.serve(async (req) => {
  const path = new URL(req.url).pathname;
  if (path.endsWith("/health") && req.method === "GET") {
    try {
      const { auth } = await (runtimePromise ??= loadRuntime());
      const enabled = await isEnabledNow();
      if (!auth) throw Error("Auth unavailable");
      return Response.json({ ready: true, login_enabled: enabled });
    } catch {
      runtimePromise = null;
      return Response.json({ ready: false }, { status: 503 });
    }
  }
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "https://furfural0405.github.io",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "content-type,authorization",
        "Access-Control-Allow-Credentials": "true",
        "Vary": "Origin",
      },
    });
  }
  try {
    const { auth } = await (runtimePromise ??= loadRuntime());
    const enabled = await isEnabledNow();
    if (!enabled && !path.endsWith("/jwks")) return Response.json({ error: "AUTH_MIGRATION_NOT_ACTIVATED" }, { status: 503 });
    const routedUrl = new URL(req.url);
    if (!routedUrl.pathname.startsWith(basePath)) {
      const old = routedUrl.pathname;
      routedUrl.pathname = old.startsWith("/" + SLUG + "/")
        ? "/functions/v1" + old
        : basePath + old;
    }
    return auth.handler(new Request(routedUrl, req));
  } catch {
    runtimePromise = null;
    return Response.json({ error: "AUTH_UNAVAILABLE" }, { status: 503 });
  }
});
