import {test} from "node:test";
import assert from "node:assert/strict";
import {createMasterSiteClient} from "../integrations/mastersite-auth-bridge.mjs";

const url = "https://entbtqtyxhbozjdbdvns.supabase.co";
const key = "sb_publishable_test_only";
const uid = "20000000-0000-4000-a000-000000000001";
const payload = app => ({
  iss: url + "/functions/v1/mastersite-" + (app === "feelings" ? "feelings" : "pullrates") + "-auth",
  aud: url + "/functions/v1/mastersite-" + (app === "feelings" ? "feelings" : "pullrates") + "-auth",
  role: "authenticated",
  app_id: app === "feelings" ? "feelings-turnier" : "pokemon-pullrates",
  sub: uid,
  exp: Math.floor(Date.now() / 1000) + 3600,
});
const tokenFor = app => [
  Buffer.from('{"alg":"EdDSA","kid":"test"}').toString("base64url"),
  Buffer.from(JSON.stringify(payload(app))).toString("base64url"),
  "test_signature_not_cryptographically_valid",
].join(".");

function construct({service = "feelings", responder = () => ({})} = {}) {
  const calls = [];
  let options;
  const createClient = (_url, _key, opts) => {
    options = opts;
    return {auth: {legacy: true}, functions: {invoke: async name => ({data: {name}, error: null})}};
  };
  const client = createMasterSiteClient({createClient,url,key,schema:service === "feelings" ? "mastersite_feelings" : "mastersite_pullrates", service});
  const beforeFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    calls.push({input, init});
    const response = responder(input, init);
    return new Response(JSON.stringify(response.body ?? response), {
      status: response.status ?? 200,
      headers: {"content-type": "application/json"},
    });
  };
  return {client,calls,options,restore:()=>{globalThis.fetch=beforeFetch;}};
}
test("staging client points to the isolated schema, never the source project's URL", async () => {
  const {client,options,calls,restore}=construct({
    service: "pullrates",
    responder: input => {
      if (input.endsWith("/token")) return {status:401, body:{message:"not signed in"}};
      if (input.endsWith("/get-session")) return {session:null,user:null};
      return {};
    },
  });
  try {
    assert.equal(options.db.schema, "mastersite_pullrates");
    assert.equal(options.auth.persistSession, false);
    assert.equal(typeof options.accessToken, "function");
    assert.equal(await options.accessToken(), null);
    const state=await client.auth.getSession();
    assert.equal(state.data.session, null);
    assert.equal(state.error, null);
    assert.ok(calls.every(c=>String(c.input).startsWith("/api/auth/pullrates/")));
    assert.ok(calls.every(c=>!String(c.input).includes("tmsekorkrnglnfvhudyf")));
  } finally {restore();}
});
test("staging cookie sessions create app-specific JWT and notify listeners", async () => {
  let signedIn=false;
  const {client,calls,options,restore}=construct({
    service:"feelings",
    responder: (input,init)=>{
      if (input.endsWith("/sign-in/email")) {
        assert.equal(init.method,"POST");
        assert.deepEqual(JSON.parse(init.body),{email:"person@example.com",password:"Passphrase for test",rememberMe:true});
        signedIn=true;
        return {user:{id:uid,email:"person@example.com"}};
      }
      if (input.endsWith("/get-session")) return signedIn?{user:{id:uid,email:"person@example.com"},session:{id:"session1"}}:{user:null,session:null};
      if (input.endsWith("/token")) return {token:tokenFor("feelings")};
      if (input.endsWith("/sign-out")) {signedIn=false;return {success:true};}
      return {};
    },
  });
  try {
    const events=[];
    const subscription=client.auth.onAuthStateChange((event,session)=>events.push({event,user:session?.user?.id}));
    assert.equal((await client.auth.getSession()).data.session,null);
    const login=await client.auth.signInWithPassword({email:" Person@Example.COM ",password:"Passphrase for test"});
    assert.equal(login.error,null);
    assert.equal(login.data.user.id,uid);
    assert.equal((await options.accessToken()),tokenFor("feelings"));
    assert.deepEqual(events[0],{event:"SIGNED_IN",user:uid});
    const signout=await client.auth.signOut();
    assert.equal(signout.error,null);
    assert.deepEqual(events.at(-1),{event:"SIGNED_OUT",user:undefined});
    subscription.data.subscription.unsubscribe();
    assert.ok(calls.some(c=>c.input.endsWith("/sign-in/email")));
  } finally {restore();}
});
test("wrong app issuer fails closed and account mutations remain disabled", async () => {
  const {client,options,restore}=construct({
    service:"pullrates",
    responder: input => {
      if (input.endsWith("/get-session")) return {user:{id:uid},session:{id:"1"}};
      if (input.endsWith("/token")) return {token:tokenFor("feelings")};
      return {};
    },
  });
  try {
    const result=await client.auth.getSession();
    assert.equal(result.data.session,null);
    assert.ok(result.error);
    assert.equal(await options.accessToken(),null);
    const blocked=await client.auth.signUp({email:"person@example.com",password:"anything"});
    assert.match(blocked.error.message,/noch nicht freigegeben/);
    assert.match((await client.auth.updateUser({password:"x"})).error.message,/noch nicht freigegeben/);
    assert.match((await client.auth.resetPasswordForEmail("person@example.com")).error.message,/noch nicht freigegeben/);
  } finally {restore();}
});
test("legacy Feelings registration and deletion functions are never called on old Supabase", async () => {
  const {client,restore}=construct({service:"feelings"});
  try {
    const created=await client.functions.invoke("register-admin-request",{body:{}});
    const removed=await client.functions.invoke("remove-rejected-admin-request",{body:{}});
    assert.ok(created.error);
    assert.ok(removed.error);
    assert.equal((await client.functions.invoke("unrelated")).data.name,"unrelated");
  } finally {restore();}
});

test("email-backed signup and password-reset routing require their own verified service", async () => {
  const originalLocation=globalThis.location, originalHistory=globalThis.history;
  globalThis.location={origin:"https://mastersite-eta.vercel.app",pathname:"/apps/pokemon-pullrates/",search:"?token=reset-opaque-token",href:"https://mastersite-eta.vercel.app/apps/pokemon-pullrates/?token=reset-opaque-token",hash:""};
  let cleanUrl=null;
  globalThis.history={replaceState:(_data,_title,path)=>{cleanUrl=path;}};
  const seen=[];
  const {client,restore}=construct({
    service:"pullrates",
    responder:(input, init)=>{
      if(input.endsWith("/health")) return {signup_enabled:true,password_reset_enabled:true};
      if(input.endsWith("/sign-up/email")){
        const body=JSON.parse(init.body); seen.push({operation:"signup",body});
        return {user:{id:uid,email:body.email}};
      }
      if(input.endsWith("/request-password-reset")){
        seen.push({operation:"request-reset",body:JSON.parse(init.body)});
        return {success:true};
      }
      if(input.endsWith("/reset-password")){
        seen.push({operation:"reset",body:JSON.parse(init.body)});
        return {success:true};
      }
      return {};
    },
  });
  try {
    const signup=await client.auth.signUp({
      email:" Other@Example.com ",password:"This is a valid test password",
      options:{data:{username:"OtherTester"}},
    });
    assert.equal(signup.error,null);
    assert.equal(seen[0].body.name,"OtherTester");
    assert.equal(seen[0].body.callbackURL,"https://mastersite-eta.vercel.app/apps/pokemon-pullrates/");
    assert.equal(seen[0].body.email,"other@example.com");
    assert.equal((await client.auth.resetPasswordForEmail("Other@example.com")).error,null);
    assert.equal(seen[1].body.redirectTo,"https://mastersite-eta.vercel.app/apps/pokemon-pullrates/");
    assert.equal((await client.auth.updateUser({password:"New test password 1234"})).error,null);
    assert.equal(seen[2].body.token,"reset-opaque-token");
    assert.equal(cleanUrl,"/apps/pokemon-pullrates/");
  } finally {
    restore();
    if(originalLocation===undefined)delete globalThis.location;else globalThis.location=originalLocation;
    if(originalHistory===undefined)delete globalThis.history;else globalThis.history=originalHistory;
  }
});
