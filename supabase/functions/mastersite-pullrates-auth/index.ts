import { betterAuth } from "npm:better-auth@1.7.21";
import { jwt } from "npm:better-auth@1.7.21/plugins";
import { oauthProvider } from "npm:@better-auth/oauth-provider@1.7.21";
import bcrypt from "npm:bcryptjs@3.0.2";
import pg from "npm:pg@8.16.3";
import { PostgresDialect } from "npm:kysely@0.28.7";

const SERVICE = "pokemon-pullrates";
const SCHEMA = "mastersite_pullrates_auth";
const SLUG = "mastersite-pullrates-auth";
const ORIGIN = "https://entbtqtyxhbozjdbdvns.supabase.co";
const basePath = "/functions/v1/" + SLUG;
const mailKey = Deno.env.get("MASTERSITE_RESEND_API_KEY") ?? "";
const mailFrom = Deno.env.get("MASTERSITE_MAIL_FROM") ?? "";
const emailReady = mailKey.startsWith("re_") && mailFrom.includes("@");
const appName = SERVICE === "feelings-turnier" ? "Feelings-Turnier" : "Pokémon Pullrates";
async function sendAuthEmail(to: string, subject: string, url: string): Promise<void> {
  if (!emailReady) throw new Error("MAIL_NOT_CONFIGURED");
  const checked = new URL(url);
  if (checked.origin !== ORIGIN || !checked.pathname.startsWith(basePath + "/")) {
    throw new Error("INVALID_VERIFICATION_URL");
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: "Bearer " + mailKey, "Content-Type": "application/json" },
    body: JSON.stringify({from: mailFrom, to: [to], subject, text: appName + "\n\n" + url + "\n\nDieser Link ist nur für dein eigenes Konto bestimmt."}),
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new Error("MAIL_SEND_FAILED");
}

const trustedOrigins = [
  "https://furfural0405.github.io",
  "https://mastersite-eta.vercel.app",
  "https://mastersite-michaeloeichhorst-8656.vercel.app",
  "https://mastersite-git-main-michaeloeichhorst-8656.vercel.app",
  "https://mastersite-git-auth-cutover-staging-michaeloeichhorst-8656.vercel.app",
] as const;
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
    trustedOrigins: [...trustedOrigins],
    database: {
      dialect: new PostgresDialect({ pool }),
      type: "postgres",
      schemaName: SCHEMA,
    },
    emailAndPassword: {
      enabled: true,
      disableSignUp: !emailReady,
      requireEmailVerification: true,
      minPasswordLength: 10,
      maxPasswordLength: 128,
      revokeSessionsOnPasswordReset: true,
      sendResetPassword: emailReady ? async ({ user, url }: { user: {email: string}; url: string }) => {
        await sendAuthEmail(user.email, appName + ": Passwort zurücksetzen", url);
      } : undefined,
      password: {
        hash: async (password: string) => bcrypt.hash(password, 12),
        verify: async ({ hash, password }: { hash: string; password: string }) =>
          bcrypt.compare(password, hash),
      },
    },
    emailVerification: emailReady ? {
      sendOnSignUp: true,
      sendOnSignIn: true,
      sendVerificationEmail: async ({ user, url }: {user: {email:string}; url:string}) => {
        await sendAuthEmail(user.email, appName + ": E-Mail-Adresse bestätigen", url);
      },
    } : undefined,
    advanced: {
      cookiePrefix: "mastersite_pullrates",
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
      oauthProvider({
        loginPage: "https://mastersite-eta.vercel.app/apps/pokemon-pullrates/",
        consentPage: "https://mastersite-eta.vercel.app/apps/pokemon-pullrates/",
        scopes: ["openid", "email", "profile"],
        customAccessTokenClaims: () => ({ role: "authenticated", app_id: SERVICE }),
        customIdTokenClaims: () => ({ role: "authenticated", app_id: SERVICE }),
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
      return Response.json({ ready: true, login_enabled: enabled, signup_enabled: enabled && emailReady, password_reset_enabled: enabled && emailReady });
    } catch {
      runtimePromise = null;
      return Response.json({ ready: false }, { status: 503 });
    }
  }
  if (req.method === "OPTIONS") {
    const requestOrigin = req.headers.get("origin") || "";
    if (!trustedOrigins.includes(requestOrigin as typeof trustedOrigins[number]))
      return Response.json({ error: "ORIGIN_NOT_ALLOWED" }, { status: 403 });
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": requestOrigin,
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
    if (!enabled && !path.endsWith("/jwks") && !path.endsWith("/.well-known/openid-configuration")) return Response.json({ error: "AUTH_MIGRATION_NOT_ACTIVATED" }, { status: 503 });
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
