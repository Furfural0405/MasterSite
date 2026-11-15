# Nachweis: Migration der Anwendungsdaten (15.11.2026)

**Ziel:** Supabase-Projekt `pokemon-hit-tracker`, ID `entbtqtyxhbozjdbdvns`.
**Stand:** Daten kopiert und geprüft; AUTH, Storage-Bytes, Serverfunktionen und App-Umschaltung **noch offen**.

## Bestätigte Übertragung

| Quellprojekt | Spiegel-Schema | Anwendungstabellen | Anwendungszeilen | Login-Benutzer |
|---|---|---:|---:|---:|
| Feelings-Turnier | `mastersite_feelings` | 4 | 5 | 2 (separat gesichert) |
| pokemon-pullrates | `mastersite_pullrates` | 25 | 781 | 4 (separat gesichert) |

- 25 Pullrates-Datenbankspiegel wurden vollständig mit ihren Tabellenzeilen befüllt: **781/781**; symmetrischer JSONB-Zeilenvergleich gegenüber den Ziel-Snapshots: **0 Unterschiede**.
- Feelings-Datenbankspiegel wurden vollständig befüllt: Profile 2, Teilnehmer 1, Site-Settings 1, Turnierstatus 1; symmetrischer JSONB-Zeilenvergleich: **0 Unterschiede**.
- Im rein privaten Schema `mastersite_migration` gibt es **6 Feelings-Snapshots** (4 Daten + 2 Auth) und **29 Pullrates-Snapshots** (25 Daten + 2 Auth + 2 Storage-Metadaten). Alle Zeilenzahlen und MD5-Prüfsummen dieser übertragenen Snapshots waren korrekt.
- Die bisherigen bcrypt-Passworthashes sind in `mastersite_migration.auth_snapshots` geschützt gesichert, **nicht** in Better-Auth-Login-Tabellen importiert und **nicht** für neue Logins freigeschaltet.
- Pullrates Storage: Metadaten zu 1 Bucket und 9 Dateien übertragen, die **Binärdateien selbst fehlen noch**.
- Der Transferbereich `mastersite_transfer` im Pullrates-Quellprojekt wurde nach verifiziertem Kopieren wieder entfernt.

## Sicherheitsstatus
- `mastersite_feelings`, `mastersite_pullrates`, `mastersite_migration`, `mastersite_feelings_auth` und `mastersite_pullrates_auth` sind für `anon` und `authenticated` nicht benutzbar.
- 4+25 gespiegelt importierte Anwendungstabellen und 2 Snapshot-Tabellen haben RLS aktiviert, ohne öffentlichen Zugriff.
- **Bewusste SQL-Linter-Warnung:** RLS ohne Policy bei den Spiegel-/Stagingtabellen. Diese Tabellen sind absichtlich gesperrt und noch nicht produktive APIs. Keine permissiven Policies hinzufügen, bevor Auth und Berechtigungen geprüft sind.
- Bestehende weitere Hinweise im Zielprojekt: [SECURITY DEFINER RPC durch anon ausführbar](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) und [Leaked Password Protection deaktiviert](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Diese beiden Punkte wurden nicht durch die Datenspiegel erzeugt und vor einer Produktivfreigabe zu prüfen.

## Noch ausstehend für einen funktionsfähigen gemeinsamen Betrieb
1. Für Feelings und Pullrates eigene, voll funktionsfähige Better-Auth-Dienste in getrennten Schemas `mastersite_feelings_auth` und `mastersite_pullrates_auth` installieren und im Server-Hosting bereitstellen. Der ursprüngliche Hit Tracker behält seine eigene Auth-Instanz.
2. Passwort-Hashes aus privaten Snapshots nur im sicheren Backend in die endgültigen Better-Auth-Tabellen übertragen; Anmeldungen mit derselben E-Mail und unterschiedlichen Passwörtern testen. Keine Hashwerte in Logs.
3. Alle DB-Funktionen, Trigger, RLS-/Storage-Policies, Edge Functions und Realtime-Kanäle passend zu den neuen Benutzerausstellern portieren. Pullrates enthält 43 eigene Datenbankfunktionen; Feelings 10 sowie 2 Edge Functions.
4. Die 9 Pullrates-Bilddateien (nicht nur Metadaten) in einen passenden Bucket im Zielprojekt übertragen und URLs im neuen Frontend aktualisieren.
5. Individuelle App-Frontends/Backends für die neue Auth-/Data-API anpassen und testen. Die aktuellen Kopien in MasterSite benutzen bis dahin die **alten** Auth-/API-Verbindungen.
6. **Finale Synchronisierung** von Pullrates-Daten kurz vor Umschaltung: Die Quelle ist aktiv und kann seit dem Snapshot neue Einträge enthalten. Gegen aktuelle Quelle verifizieren; niemals nur die heute kopierten 781 Zeilen als garantierten endgültigen Stand betrachten.
7. Nach getesteter Daten- und Login-Funktion die bisherigen Quellen als Rollback-Option zunächst erhalten (pausieren statt löschen).

## Aktive Projekte (am Ende dieser Migration)
- `pokemon-pullrates`: **aktiv**, produktive Quelle weiterhin in Benutzung.
- `pokemon-hit-tracker`: **aktiv**, gemeinsames Zielprojekt und MasterSite-Katalog.
- `Feelings-Turnier`: **inaktiv/pausiert**, Originaldaten weiterhin vorhanden.

**Alle Original-GitHub-Repositories bleiben unverändert.**

## Referenzen
- [Better Auth: Supabase-Migration](https://better-auth.com/docs/guides/supabase-migration-guide)
- [Better Auth: PostgreSQL-Schemas](https://better-auth.com/docs/adapters/postgresql)
- [Supabase: Eigene OIDC-Identitätsanbieter](https://supabase.com/docs/guides/auth/third-party/custom-oidc)
