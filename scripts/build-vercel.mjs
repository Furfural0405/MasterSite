import {cp, mkdir, rm, writeFile} from "node:fs/promises";
import {join,resolve} from "node:path";
import {execFileSync} from "node:child_process";
import {patchClonedApp} from "./patch-master-app.mjs";

const root=resolve(".");
const sources=join(root,".mastersite-vercel-sources");
const dist=join(root,"dist");
const isolatedPreview=process.env.MASTERSITE_ENABLE_NEW_AUTH === "1";
const SUPABASE={
  hit: "https://entbtqtyxhbozjdbdvns.supabase.co",
  hitKey: "sb_publishable_51Kjy2GfK6fDkcB7QiG5Eg_NUsGhmh2",
  feelings: "https://rwmzxgnbndoeioqksnyn.supabase.co",
  feelingsKey: "sb_publishable_REhjSoFql5jeIPjI3mBwmw_zCjDuSAv"
};
const apps=[
  {owner:"Furfural0405",repo:"pokemon-hit-tracker",slug:"pokemon-hit-tracker",prepare:"install",command:"build",env:{
    VITE_SUPABASE_URL:SUPABASE.hit,
    VITE_SUPABASE_PUBLISHABLE_KEY:SUPABASE.hitKey,
    VITE_BASE_PATH:"/apps/pokemon-hit-tracker/"
  }},
  {owner:"Furfural0405",repo:"pokemon-pullrates",slug:"pokemon-pullrates",prepare:"ci",command:"build",env:{}},
  {owner:"Furfural0405",repo:"Feelings-Turnier",slug:"feelings-turnier",prepare:"install",command:"build",env:{
    VITE_SUPABASE_URL:SUPABASE.feelings,
    VITE_SUPABASE_PUBLISHABLE_KEY:SUPABASE.feelingsKey
  }}
];
function run(program,args,workdir,moreEnv={}){
  execFileSync(program,args,{cwd:workdir,stdio:"inherit",env:{...process.env,...moreEnv},timeout:180000});
}
await rm(sources,{recursive:true,force:true});
try {
  run("npm",["test"],root);
  run("npm",["run","build"],root);
  await mkdir(sources,{recursive:true});
  for (const app of apps){
    const src=join(sources,app.slug);
    const remote="https://github.com/"+app.owner+"/"+app.repo+".git";
    run("git",["clone","--depth","1","--branch","main",remote,src],root);
    run("npm",[app.prepare==="ci"?"ci":"install","--no-audit","--no-fund"],src);
    if(app.slug==="pokemon-pullrates") run("npm",["test"],src);
    if(app.slug==="pokemon-hit-tracker") run("npm",["test"],src);
    if(isolatedPreview && app.slug!=="pokemon-hit-tracker"){
      await patchClonedApp(src,app.slug);
      if(app.slug==="feelings-turnier"){
        app.env.VITE_SUPABASE_URL=SUPABASE.hit;
        app.env.VITE_SUPABASE_PUBLISHABLE_KEY=SUPABASE.hitKey;
      }
      console.log("MasterSite isolated preview enabled:",app.slug);
    }
    run("npm",["run",app.command],src,app.env);
    await mkdir(join(dist,"apps",app.slug),{recursive:true});
    await cp(join(src,"dist"),join(dist,"apps",app.slug),{recursive:true,force:true});
    console.log("MasterSite bundled:",app.slug);
  }
  await writeFile(join(dist,".nojekyll"),"");
} finally {
  await rm(sources,{recursive:true,force:true});
}
