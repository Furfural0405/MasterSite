# Migration in das eine Supabase-Projekt – technischer Stand (2026-11-15)

> **Status: Datenmigration und Auth-Cutover noch NICHT abgeschlossen.**
> Diese Datei ist eine Bestandserhebung, keine Freigabe zum Löschen/Pausieren der Quelldatenbanken.

## Ziel
Die drei MasterSite-Anwendungen weiter unabhängig betreiben, wobei die geschäftlichen Daten zentral in **pokemon-hit-tracker** (Projekt-Ref `entbtqtyxhbozjdbdvns`) liegen:

1. Feelings-Turnier (Quelle `rwmzxgnbndoeioqksnyn`)
2. Pokémon Pullrates (Quelle `tmsekorkrnglnfvhudyf`)
3. Pokémon Hit Tracker (bereits im Zielprojekt)

## Geprüfte Ausgangsdaten
| Anwendung | Auth-Accounts | Dateien im Supabase-Storage | Anwendungsrelationen | DB-Funktionen | Detail |
|---|---:|---:|---:|---:|---|
| Pokémon Pullrates | 4 | 9 in Bucket `card-images` | 25 Tabellen | 43 | Quelle aktiv bei Prüfung |
| Pokémon Hit Tracker | 1 | 0 | Bestehende App-Struktur in `public` | siehe Ausgangsprojekt | Das Zielprojekt enthält MasterSite-Katalog und zwei leere Namensräume |
| Feelings-Turnier | Erhebung ausstehend | Erhebung ausstehend | Quellprojekt beim Start pausiert | mindestens 2 Edge Functions | Aufweckprozess angestoßen |

Die Pullrates-Datenbank enthält Chat-, Geräte-, Inventar-, Markt-, Listen- und Nutzerprofile, persönliche Daten sowie Freigaben/Moderationsdaten. Kein stumpfes `COPY public.*` ausführen.

## Technisch notwendige Grenzen
- Die Grenze von **zwei aktiven kostenlosen Supabase-Projekten** bedeutet nicht, dass Tabellen beliebig auf 2 Projekte zusammengeführt werden können; ein Projekt bleibt eine einzelne Auth-Instanz.
- Auf dem Zielprojekt wird Supabase Auth für Hit Tracker benutzt. Für die beiden anderen Anwendungen müssen separate Auth-Dienste/-Schemas entstehen; die Anforderung *gleiche E-Mail und unterschiedliche Passwörter* wäre sonst nicht erfüllt.
- Für beide Quellen können bcrypt-Hashwerte theoretisch übernommen werden (Better-Auth-Migrationsguide). Niemals Passwörter, Hashwerte oder vollständige Benutzerdaten in öffentliche GitHub-Repositories oder GitHub Actions Logs schreiben.
- Bestehende RLS-Policies, Storage-Policies, Trigger, SQL-Funktionen, Realtime, Chat und Edge Functions sind eng an Supabase Auth und `auth.users` gebunden. Daher müssen sie appweise umgebaut werden; reine Änderung der API-URL wäre unsicher und würde Benutzerzugriffe stören.
- Sicherheitskritische, personenbezogene Daten niemals nur in `public` ohne RLS abspeichern.

## Sichere Reihenfolge
1. Quellstrukturen + Konten-/Daten-/Storage-Metadaten erfassen. Sicherheits- und Datenschutzvorgaben prüfen.
2. Gesicherte vollständige Backups beider Quellen erstellen; Wiederherstellbarkeit verifizieren; Quellen niemals vor diesem Schritt löschen.
3. Getrennte Auth-Dienste (z. B. Better Auth, je eigene Tabellen und bcrypt-Verifizierung) in einem sicheren Server-Hosting implementieren; für `feelings` und `pullrates` getrennte Signing Keys, Cookies und Identitäten.
4. Quelldaten sowie Bucket-Inhalte in abgetrennte Schemas/Buckets des Zielprojekts übertragen, FK- und Funktionskonflikte beseitigen, IDs beibehalten und Row-Level-Security mit robusten Rollenprüfungen validieren.
5. Auth-Hashes in jeweils eigenes, **nicht öffentliches** Auth-Schema importieren; Email-Duplikate über Schema-Grenzen sind zulässig. Pro Webseite den Login, Passwort-Reset und Admin-Freigaben testen.
6. Quellen und Ziele anhand Tabellenanzahl/Zeilenzahl/Checksummen, Objektanzahl und repräsentativen Regressionstests vergleichen. Erst danach jede Webseite einzeln umstellen.
7. Alte Quellen als Rückfalloption pausiert behalten. Vor der Abschaltung alle offenen Registrierungen, Chat-Daten, Server-Funktionen und Live-Zugriffe testen.

## Bereits durchgeführte Änderungen
- Zielprojekt `pokemon-hit-tracker` besitzt die readonly-RLS-Katalogtabelle `public.master_site_apps` (genau 3 Apps).
- Zielprojekt besitzt die gesperrten **leeren** Schemas `mastersite_feelings` und `mastersite_pullrates`.
- MasterSite-GitHub-Actions-Build bindet drei Original-Repositories nur lesend ein.
- Das Zielprojekt wurde zum Freimachen eines der zwei Free-Slots vorübergehend pausiert; Feelings-Turnier wurde zum Prüfen zur Wiederherstellung angemeldet. Keine Daten gelöscht.

## Quellen der Auth-Migrationsverfahren
- https://better-auth.com/docs/guides/supabase-migration-guide
- https://better-auth.com/docs/adapters/postgresql
- https://supabase.com/docs/guides/auth/third-party/overview
- https://supabase.com/kb/troubleshooting/migrating-auth-users-between-projects

**WICHTIG:** Dieses Dokument enthält keine personenbezogenen Daten, Schlüssel oder Passworthashes. Alle Produktivmigrationen müssen mit einem getesteten Backup- und Rollbackplan erfolgen.
