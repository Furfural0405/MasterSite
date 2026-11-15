import {SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,FALLBACK_APPS} from "./site-config.js";

const cards=document.querySelector("#cards");
const search=document.querySelector("#app-search");
const notice=document.querySelector("#catalog-notice");
const empty=document.querySelector("#empty-search");
document.querySelector("#year").textContent=String(new Date().getFullYear());
let apps=FALLBACK_APPS;
const allowed=new Map(FALLBACK_APPS.map(app=>[app.slug,app]));

function element(tag,cls,text){
  const node=document.createElement(tag);
  if(cls)node.className=cls;
  if(text!==undefined)node.textContent=text;
  return node;
}
function render(){
  const query=search.value.toLocaleLowerCase("de").trim();
  cards.replaceChildren();
  const filtered=apps.filter(app=>(app.title+" "+app.description).toLocaleLowerCase("de").includes(query));
  for(const app of filtered){
    const source=allowed.get(app.slug);
    // Einträge aus dem Katalog können keine beliebigen Ziel-URLs einschleusen.
    if(!source)continue;
    const card=element("article","card");
    const icon=element("span","card-icon",source.icon);
    icon.setAttribute("aria-hidden","true");
    card.append(icon,element("span","card-label","Eigenständige Anwendung"));
    card.append(element("h3","",app.title));
    card.append(element("p","",app.description));
    const footer=element("div","card-footer");
    const open=element("a","open","Öffnen →");
    open.href=new URL(source.app_path,document.baseURI).href;
    open.setAttribute("aria-label",source.title+" öffnen");
    const github=element("a","source","GitHub");
    github.href=source.repository_url;
    github.rel="noopener noreferrer";github.target="_blank";
    footer.append(open,github);
    card.append(footer);cards.append(card);
  }
  empty.hidden=cards.childElementCount!==0;
}
async function loadCatalog(){
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),5500);
  try{
    const url=new URL("/rest/v1/master_site_apps",SUPABASE_URL);
    url.search="?select=slug,title,description,display_order&is_active=eq.true&order=display_order.asc";
    const response=await fetch(url,{headers:{apikey:SUPABASE_PUBLISHABLE_KEY},signal:controller.signal});
    if(!response.ok)throw new Error("Supabase returned "+response.status);
    const data=await response.json();
    if(!Array.isArray(data)||data.length===0)throw new Error("Empty catalog");
    const mapped=data.filter(row=>allowed.has(row?.slug) && typeof row.title==="string" && typeof row.description==="string").map(row=>({...allowed.get(row.slug),title:row.title,description:row.description,display_order:row.display_order}));
    if(mapped.length!==3)throw new Error("Catalog incomplete");
    apps=mapped.sort((a,b)=>a.display_order-b.display_order);
    notice.textContent="";
  }catch{
    apps=FALLBACK_APPS;
    notice.textContent="Die Online-Projektübersicht ist nicht erreichbar. Die gespeicherte Übersicht wird angezeigt.";
  }finally{clearTimeout(timer);render();}
}
search.addEventListener("input",render);
render();loadCatalog();
