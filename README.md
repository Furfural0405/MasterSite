# MasterSite

Gemeinsames Webportal für **Pokémon Hit Tracker**, **Pokémon Pullrates** und **Feelings-Turnier**.

## Architektur
- Das neue Repository ist eigenständig. Die drei Original-Repositories bleiben erhalten und unverändert.
- GitHub Actions baut die drei Anwendungen aus ihren Original-Repositories und veröffentlicht sie unter `/MasterSite/apps/...`.
- Die MasterSite-Startseite nutzt den öffentlich lesbaren App-Katalog `public.master_site_apps` des Supabase-Projekts **pokemon-hit-tracker** (`entbtqtyxhbozjdbdvns`), mit lokaler Ausweichliste bei Ausfall.
- **Wichtig:** Die Logins und Anwendungsdaten sind NOCH NICHT in einem Supabase-Projekt zusammengeführt. Die drei Anwendungen verwenden vorübergehend ihre bisherigen Auth-/Datenbankverbindungen. Die getrennten Passwörter bei derselben E-Mail-Adresse müssen vor der Zusammenführung erhalten bleiben.

## Aufbau
- `index.html`, `styles.css`, `main.js`, `site-config.js` – MasterSite-Startseite
- `.github/workflows/pages.yml` – drei Anwendungen automatisch bauen und zusammen veröffentlichen
- `scripts/build.mjs` – Webportal bauen
- `docs/MIGRATION.md` – notwendige sichere Migrationsschritte
- `supabase/migrations/` – MasterSite-Katalog und Namensräume

## Einrichtung
1. In **Settings → Pages** als Quelle **GitHub Actions** auswählen.
2. Den Workflow **Publish MasterSite** unter **Actions** ausführen oder auf den ersten Commit warten.
3. MasterSite ist danach (wenn die Veröffentlichung erfolgreich war) unter `https://furfural0405.github.io/MasterSite/` erreichbar.
4. Vor dem gemeinsamen Datenbankbetrieb die dokumentierte Auth-/Datenmigration und Sicherheitsprüfung abschließen.

Die Ziel-Supabase-Datenbank enthält bereits den Katalog für exakt drei Anwendungen. Hier werden keine Passwörter oder Secret-/Service-Role-Schlüssel hinterlegt.

## Original-Repositories
- https://github.com/Furfural0405/pokemon-hit-tracker
- https://github.com/Furfural0405/pokemon-pullrates
- https://github.com/Furfural0405/Feelings-Turnier

Die drei Apps werden zu Build-Zeit jeweils separat ausgecheckt. Änderungen an ihren bestehenden Repositories werden von MasterSite nicht zurückgeschrieben.
