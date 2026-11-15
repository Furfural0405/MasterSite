import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {FALLBACK_APPS} from "../site-config.js";

test("exakt die drei vereinbarten Projekte",()=>{
  assert.deepEqual(FALLBACK_APPS.map(app=>app.slug),[
    "pokemon-hit-tracker","pokemon-pullrates","feelings-turnier"
  ]);
});
test("gültige lokale Anwendungspfade",()=>{
  for(const app of FALLBACK_APPS){
    assert.match(app.app_path,/^apps\/[a-z0-9-]+\/$/);
    assert.match(app.repository_url,/^https:\/\/github\.com\/Furfural0405\//);
  }
});
test("GitHub Actions baut jede Anwendung separat",()=>{
  const yaml=readFileSync(".github/workflows/pages.yml","utf8");
  for(const app of ["pokemon-hit-tracker","pokemon-pullrates","Feelings-Turnier"]){
    assert.ok(yaml.includes("Furfural0405/"+app),app+" fehlt");
  }
  assert.ok(!yaml.includes("BiteFigth"));
  assert.ok(!yaml.includes("Excel_try"));
});
