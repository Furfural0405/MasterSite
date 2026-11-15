// MasterSite staging ONLY. No secrets or user records are returned.
// Public-only probes verify whether Supabase exposes the two new PostgREST schemas.
const target = "https://entbtqtyxhbozjdbdvns.supabase.co";
const key = "sb_publishable_51Kjy2GfK6fDkcB7QiG5Eg_NUsGhmh2";
const checks = [
  {schema:"mastersite_feelings",table:"site_settings"},
  {schema:"mastersite_pullrates",table:"pull_rates"},
];

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow","GET");
    return res.status(405).json({error:"Method not allowed"});
  }
  const results = await Promise.all(checks.map(async ({schema, table}) => {
    try {
      const url = target + "/rest/v1/" + table + "?select=id&limit=1";
      const resp = await fetch(url, {
        headers: {
          apikey:key,
          Authorization:"Bearer " + key,
          "Accept-Profile":schema,
          Accept:"application/json",
        },
        signal:AbortSignal.timeout(7000),
        cache:"no-store",
      });
      let code = null;
      if (!resp.ok) {
        const message = await resp.json().catch(()=>null);
        code = typeof message?.code === "string" ? message.code : null;
      }
      return {schema,available:resp.status===200,httpStatus:resp.status,errorCode:code};
    } catch {
      return {schema,available:false,httpStatus:null,errorCode:"NETWORK"};
    }
  }));
  res.setHeader("Cache-Control","no-store");
  return res.status(200).json({project:"pokemon-hit-tracker",checks:results});
}
