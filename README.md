# MasterSite

Gemeinsames Webportal für **Pokémon Hit Tracker**, **Pokémon Pullrates** und **Feelings-Turnier**.

## Architektur
- Das neue Repository ist eigenständig. Die drei Original-Repositories bleiben erhalten und unverändert.
- GitHub Actions baut die drei Anwendungen aus ihren Original-Repositories und veröffentlicht sie unter `/MasterSite/apps/...`.
- Die MasterSite-Startseite nutzt den öffentlich lesbaren App-Katalog `public.master_site_apps` des Supabase-Projekts **pokemon-hit-tracker** (`entbtqtyxhbozjdbdvns`), mit lokaler Ausweichliste bei Ausfall.
- **Aktueller Migrationsstand (15.11.2026):** Feelings-Turnier (4 Tabellen, 5 Datenzeilen) und Pokémon Pullrates (25 Tabellen, 781 Datenzeilen) sind in gesperrte, getrennte Schemas des Supabase-Zielprojekts kopiert und auf Datenunterschiede geprüft. Alle **9 Pullrates-Storage-Dateien** sind ebenfalls übertragen. Die **2 Feelings- und 4 Pullrates-Konten** wurden in eigene Better-Auth-Schemas inklusive bcrypt-Passworthashes übernommen; die zwei serverseitigen Auth-Dienste reagieren auf Health/JWKS. **Noch NICHT produktiv umgestellt:** echte Anmeldungen (beide Dienste gesperrt), SQL-/Edge-Geschäftsfunktionen, RLS-Freigaben, Realtime und Anwendungs-APIs. Die Webseiten verwenden bis dahin ihre bisherigen Verbindungen. [Prüfprotokoll](docs/MIGRATION-NACHWEIS-2026-11-15.md).

## Aufbau
- `index.html`, `styles.css`, `main.js`, `site-config.js` – MasterSite-Startseite
- `.github/workflows/pages.yml` – drei Anwendungen automatisch bauen und zusammen veröffentlichen
- `scripts/build.mjs` – Webportal bauen
- `scripts/build-vercel.mjs` / `vercel.json` – Build aller drei Apps und gemeinsame Auth-Proxy-Routen für Vercel (noch nicht bereitgestellt)
- `supabase/functions/mastersite-{feelings,pullrates}-auth/` – voneinander getrennte Better-Auth-Dienste; Logins momentan deaktiviert
- `tests/auth-isolation.test.mjs` – Auth-Schema- und Sicherheitsregressionstests
- `docs/MIGRATION.md` – notwendige sichere Migrationsschritte
- `supabase/migrations/` – MasterSite-Katalog und Namensräume

## Einrichtung
1. In **Settings → Pages** als Quelle **GitHub Actions** auswählen.
2. Den Workflow **Publish MasterSite** unter **Actions** ausführen oder auf den ersten Commit warten.
3. MasterSite ist danach (wenn die Veröffentlichung erfolgreich war) unter `https://furfural0405.github.io/MasterSite/` erreichbar.
4. Für die alternative Vercel-Veröffentlichung die Teamfreigabe autorisieren und das Projekt mit diesem Repository verbinden. Die alten App-Verbindungen bleiben absichtlich erhalten, bis Auth, RLS und Funktionstests bestehen.
5. Vor dem gemeinsamen Datenbankbetrieb die noch offene Auth- und Geschäftsfunktionsmigration, RLS-/Realtime-Umstellung, finale Quell-Synchronisierung und Sicherheitsprüfung abschließen.

Die Ziel-Supabase-Datenbank enthält bereits den Katalog für exakt drei Anwendungen. Hier werden keine Passwörter oder Secret-/Service-Role-Schlüssel hinterlegt.

## Original-Repositories
- https://github.com/Furfural0405/pokemon-hit-tracker
- https://github.com/Furfural0405/pokemon-pullrates
- https://github.com/Furfural0405/Feelings-Turnier

Die drei Apps werden zu Build-Zeit jeweils separat ausgecheckt. Änderungen an ihren bestehenden Repositories werden von MasterSite nicht zurückgeschrieben.

## Sicherheits- und Veröffentlichungsstatus (Stand 15.11.2026)
- Das Supabase-Zielprojekt enthält die beiden isolierten Auth-Instanzen und 29 Anwendungstabellen. **Alle 42 privaten Tabellen** inklusive Auth-/Staging-Tabellen haben RLS, für `anon`/`authenticated` aktuell **keine** SELECT-Berechtigungen. Öffentliche Nutzung erst nach app-spezifischer Auth/RLS-Integration.
- Beide Auth-Dienste: Health und öffentliche JWKS getestet, `login_enabled: false`. Die vorhandenen bcrypt-Hashes werden nicht veröffentlicht.
- Registrierungstest mit temporären UUID-Benutzern und anschließender Transaktions-Rollback erfolgreich; neue Profile sind `pending` ohne Adminrechte. Ein interaktiver Passwort-Login-Test steht noch aus.
- Vercel-Hosting noch **nicht** verknüpft (Teamfreigabe notwendig). GitHub Pages noch **nicht** aktiviert. CI-Build der drei Apps und MasterSite-Tests erfolgreich; GitHub-Pages-Deployment scheitert erst an der fehlenden Pages-Freischaltung.
- Details: [Migrationsnachweis](docs/MIGRATION-NACHWEIS-2026-11-15.md) · [Auth-Architektur](docs/AUTH-ARCHITEKTUR.md).

## Aktueller Login-Notbetrieb (15.11.2026)

**Priorität:** vorhandene Benutzerkonten von Feelings-Turnier und Pokémon Pullrates wieder anmeldbar machen.

- Die beiden Apps verwenden in der vorübergehenden Betriebsphase weiterhin **ihre eigenen Supabase-Auth-Projekte**, damit dieselbe E-Mail-Adresse unterschiedliche Passwörter behalten kann.
- Das kaum genutzte Projekt `pokemon-hit-tracker` wurde zur **Pausierung** angemeldet; währenddessen sind seine Daten und Login-Funktionen nicht erreichbar. Seine Tabellen und bereits migrierten Snapshots werden **nicht gelöscht**.
- Das Quellprojekt `Feelings-Turnier` wurde **erfolgreich wiederhergestellt (`ACTIVE_HEALTHY`)**. Anschließende SQL-Kontrolle: 2 bestätigte Auth-Benutzer, 2 freigeschaltete Profile, 1 Teilnehmer, 1 Turnierzustand. Ein Test mit echten Benutzerpasswörtern steht naturgemäß noch aus.
- Pokémon Pullrates bleibt `ACTIVE_HEALTHY`. Falls ein Login dort scheitert, sind Passwortfehler, E-Mail-Bestätigung oder Benutzerfreigabestatus separat zu prüfen; vorhandene Konten/Passwörter werden nicht automatisch geändert.
- Die Feelings Edge Functions `register-admin-request` und `remove-rejected-admin-request` erlauben jetzt auch die festen Vercel-Domains von MasterSite. Die Original-GitHub-Repositories bleiben unverändert.
- Die in der Hit-Tracker-Zieldatenbank angelegten Better-Auth-Services sind **weiterhin nicht produktiv aktiviert**. Die vollständige gemeinsame Datenbank-/RLS-Migration steht noch aus.
