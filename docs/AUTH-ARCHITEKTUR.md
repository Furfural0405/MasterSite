# Authentifizierung für drei voneinander unabhängige Webseiten

## Vorgabe
Ein Benutzer soll auf `Feelings-Turnier`, `pokemon-pullrates` und `pokemon-hit-tracker` dieselbe E-Mail-Adresse mit **drei unterschiedlichen Passwörtern** besitzen können. Eine Anmeldung, Benutzerlöschung, Konto-Freigabe oder Passwortänderung darf nicht auf die anderen Apps durchschlagen.

## Entscheidung
Für die Datenbank **ein** Supabase-Projekt verwenden, aber **drei logisch getrennte Auth-Bereiche**:
- `pokemon-hit-tracker`: bisherige Supabase-Auth-Instanz des Zielprojekts, eigenes `auth.users` und `public.app_profiles`.
- `feelings-turnier`: eigener Better-Auth-Dienst mit eigenem PostgreSQL-Schema `mastersite_feelings_auth`.
- `pokemon-pullrates`: eigener Better-Auth-Dienst mit eigenem PostgreSQL-Schema `mastersite_pullrates_auth`.

Die per-App-Schemas müssen per `database.schemaName` (Better Auth PostgreSQL Adapter) getrennt sein; jede Instanz benötigt einen eigenen `BETTER_AUTH_SECRET`, eine eigene Cookie-Präfix-Konfiguration und separate, überprüfte Rechte auf Tabellen und APIs.

## Hosting
GitHub Pages kann nur statische Webseiten hosten. Zwei Better-Auth-Dienste benötigen einen Node-Server / Hosting mit sicheren Umgebungsvariablen, etwa Vercel. Eine eigene Domain/Reverse-Proxy-Lösung vermeidet Probleme mit Drittanbieter-Cookies bei `github.io` gegenüber `vercel.app`. Keine Produktion mit unsicheren Cross-Origin-Cookies starten.

## Migration der Passwort-Hashes
Supabase Auth nutzt bcrypt. Better Auth unterstützt bcrypt-Verifikation als Anpassung in `emailAndPassword.password.verify`; die dokumentierte Supabase→Better-Auth-Migration kann vorhandene Hashes übernehmen. Diese Hashes **nicht** in Git committen, in Ausgaben protokollieren oder in Browser-Code ausliefern. Die ursprünglichen UUID-Benutzer-IDs möglichst beibehalten, damit historische Anwendungsdaten zugeordnet bleiben.

**Achtung:** Die offiziellen Better-Auth-Migrationsanweisungen decken die Migration von RLS und 2FA nicht vollständig ab. Ohne explizite Anpassung der Tabellen, APIs und Berechtigungen wäre dies noch keine sichere Migration.

## Migration der bestehenden Anwendungscode-Pfade
- Supabase-Login-Aufrufe (`auth.signUp`, `auth.signInWithPassword`, `auth.onAuthStateChange`, `auth.getSession`, `auth.signOut`) zu app-spezifischen Better-Auth-Endpunkten ändern.
- Zugriff auf `auth.uid()`, `auth.users` und alle `SECURITY DEFINER`-Funktionen ändern oder durch eine korrekt registrierte, signierte OIDC/JWT-Integration ersetzen.
- Die beiden App-Bereiche `mastersite_feelings` und `mastersite_pullrates` dürfen nur den jeweils eigenen Login-Tokens Berechtigungen gewähren. Nicht nur `TO authenticated` als Schutz benutzen.
- Storage-Buckets, Realtime, Edge Functions und Chat müssen die Auth-Tokens korrekt prüfen; für Storage-Sperren einzelne Buckets und Pfade gegen App-Grenzen testen.

## Unbedingt prüfen vor Freigabe
1. Dieselbe E-Mail auf Feelings-Turnier und Pullrates kann mit unterschiedlichen Passwörtern angemeldet werden.
2. Passwortänderung oder Login bei App A verändert weder Passwort noch Sitzung bei App B.
3. Jeder Zugriff von App A auf App-B-Daten wird auf Datenbank-/API-Ebene abgewiesen.
4. Private Chat-Nachrichten, Gerätedaten, Inventar, Admin-Freigaben, Turnier-Backups, Storage und Edge Functions erfüllen ihre bisherigen Zugriffsregeln.
5. Alte Sessions laufen nach der Migration korrekt aus, und Benutzer können ohne Datenverlust wieder anmelden.
6. Prüfergebnisse dokumentieren, bevor alte Supabase-Projekte pausiert bleiben.

## Quellen
- https://better-auth.com/docs/guides/supabase-migration-guide
- https://better-auth.com/docs/adapters/postgresql
- https://supabase.com/docs/guides/auth/third-party/overview
- https://supabase.com/docs/guides/api/securing-your-api
