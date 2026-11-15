import {mkdir,rm,copyFile,writeFile} from "node:fs/promises";
await rm("dist",{recursive:true,force:true});
await mkdir("dist",{recursive:true});
for(const name of ["index.html","styles.css","main.js","site-config.js","favicon.svg"]){
  await copyFile(name,"dist/"+name);
}
await writeFile("dist/.nojekyll","");
console.log("MasterSite-Startseite erstellt.");
