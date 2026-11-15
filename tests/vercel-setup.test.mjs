import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
const cfg=JSON.parse(readFileSync("vercel.json","utf8"));
test("Vercel builds all three apps",()=>{
  assert.equal(cfg.outputDirectory,"dist");
  const build=readFileSync("scripts/build-vercel.mjs","utf8");
  for(const repo of ["pokemon-hit-tracker","pokemon-pullrates","Feelings-Turnier"]){
    assert.ok(build.includes(repo));
  }
  assert.ok(!build.includes("BiteFigth"));
  assert.ok(!build.includes("Excel_try"));
});
test("Both Better Auth routes use the same origin proxy",()=>{
  assert.equal(cfg.rewrites.length,2);
  assert.ok(cfg.rewrites.some(x=>x.source.includes("feelings")));
  assert.ok(cfg.rewrites.some(x=>x.source.includes("pullrates")));
  for(const rule of cfg.rewrites) assert.match(rule.destination,/^https:\/\/entbtqtyxhbozjdbdvns\.supabase\.co\/functions\/v1\//);
});
