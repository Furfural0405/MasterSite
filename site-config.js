// Nur öffentliche Konfiguration; niemals Supabase Service-Role-/Secret-Schlüssel hinzufügen.
export const SUPABASE_URL = "https://entbtqtyxhbozjdbdvns.supabase.co";
export const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_51Kjy2GfK6fDkcB7QiG5Eg_NUsGhmh2";
export const FALLBACK_APPS = [
  {slug:"pokemon-hit-tracker",title:"Pokémon Hit Tracker",description:"Öffnungen, garantierte Hits und persönliche Auswertungen.",icon:"🎯",app_path:"apps/pokemon-hit-tracker/",repository_url:"https://github.com/Furfural0405/pokemon-hit-tracker",display_order:1},
  {slug:"pokemon-pullrates",title:"Pokémon Pullrates",description:"Kartensammlung, Pullraten und persönliche Übersichten.",icon:"🃏",app_path:"apps/pokemon-pullrates/",repository_url:"https://github.com/Furfural0405/pokemon-pullrates",display_order:2},
  {slug:"feelings-turnier",title:"Feelings-Turnier",description:"Teilnehmer, Spielrunden und Turnierverwaltung.",icon:"🏆",app_path:"apps/feelings-turnier/",repository_url:"https://github.com/Furfural0405/Feelings-Turnier",display_order:3}
];
