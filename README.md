# MasterSite

Gemeinsames Webportal für **Pokémon Hit Tracker**, **Pokémon Pullrates** und **Feelings-Turnier**.

## Architektur

- Drei unabhängige Originalanwendungen werden bei jedem Commit von Vercel unter https://mastersite-eta.vercel.app/ gebaut. Die Original-Repositories bleiben erhalten und unverändert.
- Ziel ist **ein einziges Supabase-Projekt** `pokemon-hit-tracker` mit privaten App-Schemas und **getrennten Passwörtern pro Anwendung** (gleichlautende E-Mail-Adressen erlaubt).
- **Kopiert und verifiziert:** 4 Feelings-Anwendungstabellen (5 Zeilen), 25 Pullrates-Anwendungstabellen (781 Zeilen), 9 Pullrates-Bilddateien (524120 Bytes), 2+4 alte Auth-Konten inklusive bcrypt-Hashes.
- **Backend-Migration durchgeführt:** 9 Feelings- und 40 Pullrates-Businessfunktionen, ursprüngliche Indizes und interne Constraints, 2 Trigger, RLS- und Issuer-Schutz, OAuth-Discovery und zwei isolierte Better-Auth-Dienste. Die OIDC-Aussteller antworten auf JWKS und Discovery; Login ist noch absichtlich gesperrt.
- **WICHTIG:** Die Frontends und Supabase Third-Party-OIDC-Konfiguration sind **noch nicht produktiv umgestellt**, sodass die vollständige Ein-Projekt-Anforderung **noch nicht erreicht** wurde. Bestehende Daten bleiben geschützt. [OIDC-/API-Setup](docs/SUPABASE-OIDC-UND-DATENAPI-FREIGABE.md).

## Aufbau
- `index.html`, `styles.css`, `main.js`, `site-config.js` – MasterSite-Startseite
- `.github/workflows/pages.yml` – optionale, ausschließlich manuell auszuführende GitHub-Pages-Alternative
- `scripts/build.mjs` – Webportal bauen
- `scripts/build-vercel.mjs` / `vercel.json` – aktiver Build aller drei Apps und gemeinsame Auth-Proxy-Routen für Vercel
- `supabase/functions/mastersite-{feelings,pullrates}-auth/` – voneinander getrennte Better-Auth-Dienste; Logins momentan deaktiviert
- `tests/auth-isolation.test.mjs` – Auth-Schema- und Sicherheitsregressionstests
- `docs/MIGRATION.md` – notwendige sichere Migrationsschritte
- `supabase/migrations/` – MasterSite-Katalog und Namensräume

## Einrichtung und Live-Zugriff

- **Vercel MasterSite**: https://mastersite-eta.vercel.app/ – automatisch aus `main` bereitgestellt.
- Das alte GitHub-Pages-Workflow bleibt manuell; eine zusätzliche GitHub-Pages-Freischaltung ist für Vercel **nicht** notwendig.
- **Produktive Auth-Migration benötigt OIDC-Konfiguration im Supabase-Dashboard sowie die vollständige Frontend-Integration.** Anleitung: [SUPABASE-OIDC-UND-DATENAPI-FREIGABE.md](docs/SUPABASE-OIDC-UND-DATENAPI-FREIGABE.md).
- Alle Originaldaten und User-Passworthashes sind in privaten Archiven erhalten; keine Nutzerdaten oder Secrets werden in diesem öffentlichen Repo hinterlegt.

## Original-Repositories
- https://github.com/Furfural0405/pokemon-hit-tracker
- https://github.com/Furfural0405/pokemon-pullrates
- https://github.com/Furfural0405/Feelings-Turnier

Die drei Apps werden zu Build-Zeit jeweils separat ausgecheckt. Änderungen an ihren bestehenden Repositories werden von MasterSite nicht zurückgeschrieben.

## Sicherheits- und Veröffentlichungsstatus (15.11.2026)

- Die Originale wurden privat archiviert: Feelings **7 Objekte/10 Zeilen**, Pullrates **28 Objekte/798 Zeilen**. Zusätzlich enthält der Ziel-Supabase ein geschütztes Vor-Migrationsarchiv mit **53 Objekten/1558 Zeilen**.
- Im Ziel existieren RLS und App-spezifische Berechtigungen. Tests: öffentliche Statistiken funktionieren; korrekt simulierte Feelings- und Pullrates-Benutzer können nur ihre jeweiligen Profile/Listen abrufen; falsche Issuer und der native Hit-Tracker-Issuer werden abgewiesen.
- Login-Sicherheit: Zwei unabhängige Better-Auth-Schemas, je sieben OAuth-Provider-Tabellen; OIDC Discovery/JWKS jeweils HTTP 200 mit einem öffentlichen Prüfschlüssel. Die neuen Dienste bleiben `login_enabled=false`, bis Supabase sie als Custom OIDC akzeptiert und echte Browser-Logins getestet sind.
- Der Datensatz `cardmarket_prices` und der Preisdienststatus wurden nach Zielarchiv ohne Löschungen zum Pullrates-Quellprojekt synchronisiert; 9 Storage-Objekte stimmen in Namen und Größe überein.
- Die ursprünglichen App-Logins bleiben eine Rückfallmöglichkeit. Bei der kostenlosen Zwei-Projekte-Grenze sind **noch nicht alle drei Backends gleichzeitig produktiv nutzbar**.
- Weitere Details: [OIDC-/Data-API-Setup](docs/SUPABASE-OIDC-UND-DATENAPI-FREIGABE.md) und [Auth-Architektur](docs/AUTH-ARCHITEKTUR.md).

## Vorübergehender Betrieb

Die Original-Logins von Feelings-Turnier und Pokémon Pullrates haben Vorrang, solange der neue Auth-Cutover nicht getestet ist. Das Hit-Tracker-Projekt wird dafür vorübergehend pausiert; seine Daten und die gesamte vorbereitete Migration bleiben dabei erhalten. Jeder weitere Cutover erfordert einen Delta-Abgleich der in der Zwischenzeit neu gespeicherten Pullrates-Daten.

Die Original-GitHub-Repositories werden nicht umgeschrieben. **Es wurde kein produktiver Benutzerbestand gelöscht.**
