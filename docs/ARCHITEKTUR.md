# Architektur MasterSite

## Drei Anwendungen
- Pokémon Hit Tracker: React + Vite, ursprüngliches Repository `Furfural0405/pokemon-hit-tracker`
- Pokémon Pullrates: statisches JavaScript + esbuild, ursprüngliches Repository `Furfural0405/pokemon-pullrates`
- Feelings-Turnier: React + Vite, ursprüngliches Repository `Furfural0405/Feelings-Turnier`

## Integration ohne Veränderung der Originale
MasterSite besitzt eine eigene GitHub-Pages-Startseite. Ein GitHub-Actions-Workflow lädt die drei Original-Repositories, baut sie in getrennten Verzeichnissen und fügt deren statische Build-Artefakte in MasterSite unter `apps/<slug>/` ein. Die Original-Repositories werden nicht verändert. Durch geplante Builds werden Updates periodisch übernommen; für sofortige Builds gibt es workflow_dispatch.

## Supabase
Die Startseite lädt den öffentlichen Katalog aus `public.master_site_apps` im Supabase-Zielprojekt `pokemon-hit-tracker`. Wenn die kostenlose Datenbank pausiert ist, benutzt die Startseite eine fest einprogrammierte Liste mit exakt drei Anwendungen.

Zur späteren Zusammenführung wurden `mastersite_feelings` und `mastersite_pullrates` als gesperrte **leere** Schemas erstellt. Bestehende Daten wurden nicht migriert.

## Grenzen
GitHub Pages hostet statisch. Für vollständig getrennte Logins im **selben** Supabase-Projekt sind unabhängige Authentifizierungsdienste plus eine serverseitige Autorisierung und RLS-Integration notwendig. Der Workflow schaltet die Auth-Projekte daher bewusst **nicht** automatisch auf eine gemeinsame Projekt-URL.
