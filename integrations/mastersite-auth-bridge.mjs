/**
 * Isolated Supabase Data API + Better Auth bridge for MasterSite staging only.
 *
 * This module is copied into temporary build clones; original repositories
 * and their production Auth configurations are never edited.
 *
 * Security: no service_role key, no direct password storage, no localStorage
 * credential storage. The Better Auth cookie is HttpOnly and same-origin.
 * The external JWT is short-lived and stored in JS memory only.
 */
export function createMasterSiteClient({createClient, url, key, schema, service}) {
  if (!["feelings", "pullrates"].includes(service)) {
    throw new Error("Ungültiger MasterSite-Loginbereich.");
  }
  if (!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url)) {
    throw new Error("Ungültige Supabase-Projektadresse.");
  }
  const path = "/api/auth/" + service;
  let currentSession = null;
  let jwt = null;
  let jwtExpiresAt = 0;
  let nextAnonymousCheck = 0;
  let inFlightToken = null;
  const listeners = new Set();

  async function request(endpoint, {method = "GET", body} = {}) {
    const options = {
      method,
      credentials: "same-origin",
      redirect: "error",
      cache: "no-store",
      headers: {"Accept": "application/json"},
    };
    if (body !== undefined) {
      options.headers["Content-Type"] = "application/json";
      options.body = JSON.stringify(body);
    }
    let response;
    try {
      response = await fetch(path + endpoint, options);
    } catch {
      throw new Error("Der Anmeldeserver ist momentan nicht erreichbar.");
    }
    const data = await response.json().catch(() => null);
    if (!response.ok) {
      const detail = data && (data.message || data.error?.message || data.error);
      if (response.status === 503) {
        throw new Error("Der neue Login wird noch getestet und ist nicht freigeschaltet.");
      }
      throw new Error(typeof detail === "string" ? detail : "Anmeldung fehlgeschlagen (HTTP " + response.status + ").");
    }
    return data;
  }

  function expireJwt() {
    jwt = null;
    jwtExpiresAt = 0;
    nextAnonymousCheck = 0;
  }

  async function getAccessToken() {
    const now = Date.now();
    if (jwt && jwtExpiresAt > now + 60_000) return jwt;
    if (nextAnonymousCheck > now) return null;
    if (inFlightToken) return inFlightToken;
    inFlightToken = (async () => {
      try {
        const data = await request("/token");
        if (!data || typeof data.token !== "string") return null;
        const payload = JSON.parse(atob(data.token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
        if (payload.role !== "authenticated" ||
            payload.app_id !== (service === "feelings" ? "feelings-turnier" : "pokemon-pullrates") ||
            typeof payload.sub !== "string") {
          throw new Error("Das Login-Token gehört nicht zur ausgewählten Anwendung.");
        }
        jwt = data.token;
        jwtExpiresAt = Number(payload.exp) * 1000 || now + 5 * 60_000;
        return jwt;
      } catch {
        expireJwt();
        nextAnonymousCheck = Date.now() + 10_000;
        return null;
      }
    })();
    try { return await inFlightToken; }
    finally { inFlightToken = null; }
  }

  function emit(event, session) {
    for (const fn of listeners) {
      try { fn(event, session); }
      catch (error) { console.error("MasterSite auth listener error:", error); }
    }
  }

  async function readSession() {
    try {
      const result = await request("/get-session");
      const who = result?.user ?? null;
      const previousId = currentSession?.user?.id ?? null;
      let next = null;
      if (who?.id) {
        const token = await getAccessToken();
        if (!token) throw new Error("Der Auth-Server hat kein gültiges Zugriffstoken ausgegeben.");
        next = {user: who, access_token: token, token_type: "bearer", expires_at: Math.floor(jwtExpiresAt / 1000)};
      }
      currentSession = next;
      if (previousId !== (who?.id ?? null)) emit(next ? "SIGNED_IN" : "SIGNED_OUT", next);
      return {data: {session: next}, error: null};
    } catch (error) {
      expireJwt();
      const previous = currentSession;
      currentSession = null;
      if (previous) emit("SIGNED_OUT", null);
      return {data: {session: null}, error};
    }
  }

  function rejected(message) {
    return Promise.resolve({data: {user: null, session: null}, error: new Error(message)});
  }
  const disabledFeature = "Diese Funktion ist während der sicheren MasterSite-Umstellung noch nicht freigegeben. Bestehende Konten bleiben unverändert.";

  const auth = {
    onAuthStateChange(fn) {
      listeners.add(fn);
      return {data: {subscription: {unsubscribe: () => listeners.delete(fn)}}, error: null};
    },
    getSession: readSession,
    async getUser() {
      const result = await readSession();
      return {data: {user: result.data.session?.user ?? null}, error: result.error};
    },
    async signInWithPassword({email, password}) {
      try {
        if (typeof email !== "string" || typeof password !== "string")
          throw new Error("E-Mail und Passwort fehlen.");
        const value = await request("/sign-in/email", {
          method: "POST", body: {email: email.trim().toLowerCase(), password, rememberMe: true},
        });
        expireJwt();
        const result = await readSession();
        if (result.error || !result.data.session) throw result.error ?? new Error("Die Sitzung konnte nicht bestätigt werden.");
        return {data: {user: result.data.session.user, session: result.data.session}, error: null};
      } catch (error) {
        return {data: {user: null, session: null}, error};
      }
    },
    async signOut() {
      try {
        await request("/sign-out", {method: "POST"});
        expireJwt();
        currentSession = null;
        emit("SIGNED_OUT", null);
        return {error: null};
      } catch (error) { return {error}; }
    },
    signUp() { return rejected(disabledFeature); },
    resetPasswordForEmail() { return rejected(disabledFeature); },
    updateUser() { return rejected(disabledFeature); },
  };

  const client = createClient(url, key, {
    db: {schema},
    auth: {autoRefreshToken: false, persistSession: false, detectSessionInUrl: false},
    accessToken: getAccessToken,
  });
  // The current app only uses these legacy Supabase Auth methods.
  // With external JWTs, Supabase's native Auth client must not be used.
  Object.defineProperty(client, "auth", {value: auth, configurable: true});
  if (service === "feelings") {
    // The original registration Edge Functions target the paused Feelings backend.
    // Do not accidentally create or delete a user in the old Auth database.
    const methods = client.functions;
    const originalInvoke = methods.invoke.bind(methods);
    methods.invoke = async (name, options) => {
      if (name === "register-admin-request" || name === "remove-rejected-admin-request") {
        return {data: {error: disabledFeature}, error: new Error(disabledFeature)};
      }
      return originalInvoke(name, options);
    };
  }
  return client;
}
