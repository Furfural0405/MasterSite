/**
 * TEMPORARY staging-only end-to-end authentication smoke test.
 * Credentials are encrypted, branch-scoped Vercel environment variables.
 * This endpoint never returns accounts, passwords, session cookies, or JWTs.
 */
const target = "https://entbtqtyxhbozjdbdvns.supabase.co";
const apikey = "sb_publishable_51Kjy2GfK6fDkcB7QiG5Eg_NUsGhmh2";
const appDetails = [
  {name:"feelings", slug:"mastersite-feelings-auth", schema:"mastersite_feelings", expectedAppId:"feelings-turnier", passwordEnv:"MASTERSITE_QA_FEELINGS_PASSWORD"},
  {name:"pullrates", slug:"mastersite-pullrates-auth", schema:"mastersite_pullrates", expectedAppId:"pokemon-pullrates", passwordEnv:"MASTERSITE_QA_PULLRATES_PASSWORD"},
];
const origin="https://mastersite-eta.vercel.app";
function cookieHeader(response) {
  const headerValues=typeof response.headers.getSetCookie==="function"?
    response.headers.getSetCookie() : [response.headers.get("set-cookie")||""];
  return headerValues.filter(Boolean).map(v=>v.split(";")[0]).join("; ");
}
async function request(url, options={}) {
  return fetch(url, {signal:AbortSignal.timeout(10000),cache:"no-store",...options});
}
async function signIn(app, email, password) {
  const base=target+"/functions/v1/"+app.slug;
  const response=await request(base+"/sign-in/email",{
    method:"POST",
    headers:{"Content-Type":"application/json",Accept:"application/json",Origin:origin},
    body:JSON.stringify({email,password,rememberMe:false}),
  });
  return {response, base, cookie:cookieHeader(response)};
}
function safeClaim(token) {
  try {
    const parts=token.split(".");
    if(parts.length!==3) return null;
    return JSON.parse(Buffer.from(parts[1],"base64url").toString("utf8"));
  }catch {return null}
}
async function apiTest(app, bearer) {
  const headers={
    apikey,
    Authorization:"Bearer "+bearer,
    Accept:"application/json",
    "Accept-Profile":app.schema,
  };
  if(app.name==="feelings"){
    const r=await request(target+"/rest/v1/profiles?select=id&limit=1",{headers});
    return {http:r.status,rows:r.ok?(await r.json().catch(()=>[])).length:null};
  }
  const r=await request(target+"/rest/v1/rpc/pull_lists",{
    method:"POST",
    headers:{...headers,"Content-Profile":app.schema,"Content-Type":"application/json"},
    body:JSON.stringify({operation:"me",payload:{}}),
  });
  return {http:r.status,rpcSucceeded:r.ok};
}
export default async function handler(req,res) {
  if (req.method!=="GET") {res.setHeader("Allow","GET");return res.status(405).json({error:"Method not allowed"});}
  const email=process.env.MASTERSITE_QA_EMAIL;
  if(!email || !appDetails.every(a=>process.env[a.passwordEnv])){
    return res.status(503).json({ready:false,reason:"QA credentials missing"});
  }
  const results=[];
  const tokens={};
  for(const app of appDetails){
    const result={app:app.name};
    try{
      const login=await signIn(app,email,process.env[app.passwordEnv]);
      result.signInHttp=login.response.status;
      result.sessionCookie=Boolean(login.cookie);
      if(login.response.ok && login.cookie){
        const tokenResponse=await request(login.base+"/token",{
          headers:{Cookie:login.cookie,Origin:origin,Accept:"application/json"},
        });
        result.jwtHttp=tokenResponse.status;
        if(tokenResponse.ok){
          const raw=await tokenResponse.json();
          const jwt=raw?.token;
          const claims=typeof jwt==="string"?safeClaim(jwt):null;
          result.jwtCorrectApp=Boolean(claims && claims.app_id===app.expectedAppId && claims.role==="authenticated" && claims.iss===login.base);
          if(result.jwtCorrectApp){
            tokens[app.name]=jwt;
            result.dataApi=await apiTest(app,jwt);
          }
        }
        await request(login.base+"/sign-out",{
          method:"POST",
          headers:{Cookie:login.cookie,Origin:origin,"Content-Type":"application/json"},
          body:"{}",
        }).catch(()=>{});
      }
    }catch{result.errorCode="NETWORK_OR_RUNTIME";}
    results.push(result);
  }
  // Cross-app password acceptance must fail, even though e-mail is identical.
  try{
    const swapped=await signIn(appDetails[0],email,process.env.MASTERSITE_QA_PULLRATES_PASSWORD);
    results[0].wrongPasswordRejected=!swapped.response.ok;
  }catch{results[0].wrongPasswordRejected=false}
  // Feelings JWT must never access the authenticated Pullrates list RPC.
  if(tokens.feelings){
    try {
      const swapped=await apiTest(appDetails[1],tokens.feelings);
      results[0].otherAppRpcDenied=swapped.http===401||swapped.http===403||swapped.http===400;
    }catch{results[0].otherAppRpcDenied=false}
  }
  res.setHeader("Cache-Control","no-store");
  return res.status(200).json({ready:true,checks:results});
}
