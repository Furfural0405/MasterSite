# Migration zu EINEM Supabase-Projekt – sichere Reihenfolge

Zielprojekt: pokemon-hit-tracker / entbtqtyxhbozjdbdvns.

## Ist-Zustand
MasterSite veröffentlicht Kopien der drei Original-Webseiten. Ihre bestehenden Anmeldungen bleiben derzeit an den ursprünglichen Supabase-Projekten. Der Portal-Katalog ist bereits im Zielprojekt angelegt. Dies ist eine **funktionsfähige Portal-/Build-Integration**, jedoch **noch keine abgeschlossene Datenbank-/Auth-Migration**.

## Datenschutz und eigenständige Logins
Supabase Auth im selben Supabase-Projekt erlaubt nicht für mehrere Webseiten dieselbe E-Mail-Adresse mit unterschiedlichen Passwörtern als unabhängig verwaltete Konten. Deshalb: **keine gemeinsame Supabase-Auth-Instanz erzwingen**.

Vor produktiver Umstellung sind separate Auth-Instanzen (etwa Better Auth pro Anwendung mit eigenen Auth-Tabellen und Cookie-Grenzen) erforderlich. Alternativ können unabhängige externe Auth-Dienste angebunden werden. Bestehende Admin-/User-Rechte, RLS, Storage und Edge Functions müssen hierzu überprüft und angepasst werden. Passwörter lassen sich nicht einfach unverändert aus Supabase Auth in jedes beliebige Auth-System übertragen. Passwort-Reset/Migration und Zustimmungskonzept planen.

## Schritte
1. Exporte und Backups für jedes vorhandene Projekt, inklusive Auth-Metadaten, Tabellen, Storage und Funktionscode. Originale nicht löschen.
2. In der Zieldatenbank die bereits vorhandenen Hit-Tracker-Tabellen unverändert beibehalten. Die leeren Namensräume `mastersite_feelings` und `mastersite_pullrates` sind vorbereitet.
3. SQL-Objekte aus Feelings und Pullrates auf namensgetrennte Schemas adaptieren (einschließlich Views, Trigger, Funktionen, Zugriffsrechte). Bestehende public- und auth.users-Referenzen keinesfalls blind kopieren.
4. Getrennte Auth-Instanzen mit eigener Benutzer-, Session- und Passwortverwaltung pro Webseite aufbauen. Auth-Funktionalität und Administratorfreigaben übernehmen.
5. Rollen / Row Level Security / SQL-GRANTs / Storage / Realtime / Edge Functions Ende-zu-Ende testen. Niemals Secret-/Service-Role-Schlüssel in statische Frontends einbauen.
6. Die jeweiligen Frontends und Backend-APIs einzeln auf das Zielprojekt umstellen. Regressionstests für mehrere Konten mit gleicher E-Mail und unterschiedlichen Passwörtern sowie getrennte Sitzungen.
7. Nach vollständiger Prüfung der Backups und erfolgreichem Betrieb kann über das Pausieren alter Supabase-Projekte entschieden werden.

**Keine Datenmigration allein durch GitHub Pages möglich:** Für Better Auth bzw. andere sichere unabhängige Auth-Dienste werden geeignete Server-Endpunkte/Hosting benötigt. GitHub Pages ist nur für statische Frontends.
