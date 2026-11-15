# MasterSite: sichere OIDC-/Data-API-Freigabe für das gemeinsame Supabase-Projekt

**Vorbereitung – noch kein produktiver Login-Cutover.**
Zielprojekt: `pokemon-hit-tracker`, Referenz `entbtqtyxhbozjdbdvns`.
Beide Originalprojekte `Feelings-Turnier` und `pokemon-pullrates` bleiben als geschützte Quellen/Backups erhalten.

## 1. Zwei unabhängige OIDC-Aussteller beim ZIEL-Supabase registrieren

Dashboard: https://supabase.com/dashboard/project/entbtqtyxhbozjdbdvns/auth/providers

- Supabase → **Authentication → Sign In / Providers → Third-Party Auth → Add provider → Custom OIDC**.
- Für **Feelings-Turnier** als **Issuer URL**:
  `https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-feelings-auth`
- Für **Pokémon Pullrates** als separate **Issuer URL**:
  `https://entbtqtyxhbozjdbdvns.supabase.co/functions/v1/mastersite-pullrates-auth`
- Beide getrennt registrieren. Den natürlichen Auth-Namensraum von Pokémon Hit Tracker nicht ersetzen.
- Zur Kontrolle öffnet der Dienst jeweils `<Issuer>/.well-known/openid-configuration` und `<Issuer>/jwks`.
- Beide URLs antworteten beim aktuellen Test HTTP 200, JWKS hatte jeweils einen öffentlichen Prüfschlüssel.
- Die neuen Auth-Dienste haben weiterhin `login_enabled=false`; registrieren bedeutet **noch nicht freischalten**.

Offizielle Dokumentation: https://supabase.com/docs/guides/auth/third-party/custom-oidc

## 2. Data API: nur die beiden Anwendungs-Schemas exponieren

Dashboard: Supabase → Project Settings / Integrations → Data API → **Exposed schemas**.

Vorhandenes `public` beibehalten. Zusätzlich exakt diese zwei hinzufügen:
- `mastersite_feelings`
- `mastersite_pullrates`

**Auf keinen Fall** exponieren:
- `mastersite_feelings_auth`, `mastersite_pullrates_auth`
- `mastersite_migration`, `mastersite_preservation`
- `mastersite_feelings_private`, `mastersite_pullrates_private`

RLS ist auf den Tabellen aktiv. Die erforderlichen eingeschränkten GRANTs und Staging-Policies sind vorbereitet.
Öffentliche Leserechte gibt es nur für die ursprünglich öffentlichen Einstellungen, Karten und Statistiken.
Privatdaten und Passworthashes sind nicht für anonyme oder andere App-Benutzer zugänglich.

## 3. Vor produktiver Umstellung noch zu erledigen

1. Feelings-Turnier-Frontend mit Better-Auth-Login, eigener JWT-Tokenbeschaffung und Schema `mastersite_feelings` verbinden.
2. Pullrates-Frontend analog mit seinem *anderen* Auth-Issuer, Schema `mastersite_pullrates` und eigenem JWT verbinden.
3. Login mit gleicher E-Mail und unterschiedlichen Passwörtern für beide Apps **end-to-end** prüfen.
4. Bestehende Berechtigungen und Funktionen testen: Admin, RLS, Registrierungen, Teilnehmer, Turnierbackup, Pullrates-Liste, Kartenbestand, verschlüsselter Chat, Realtime, Speicher-Uploads, Passwort-Reset.
5. Die beiden Feelings-Edge-Functions für neue Registrierung/Entfernen abgelehnter Nutzer auf den neuen Auth-Dienst umstellen.
6. Live-Änderungen der ursprünglichen Pullrates-Datenbank seit dem letzten Snapshot vor dem Abschalten **erneut differenziell abgleichen**. Keine Tabellen `TRUNCATE`, `DROP` oder pauschal ersetzen.
7. Erst bei vollständigem Nachweis beide Quellen pausieren und ausschließlich `pokemon-hit-tracker` aktiv lassen.

Ohne OIDC-Konfiguration **dürfen die neuen Login-Dienste nicht aktiviert** oder Frontends umgeschaltet werden.

## Sicherungen und Nachweise

- Original **Feelings**: privates `mastersite_preservation.archives` mit 7 Datenbeständen und 10 Zeilen. Auth 2 Benutzer und 2 Identitäten; ein zusätzlicher Eintrag in `private.registration_rate_limits`.
- Original **Pullrates**: privates `mastersite_preservation.archives` mit 28 Datenbeständen und 798 Zeilen. Anwendung 25 Tabellen und 781 Zeilen, Auth 4 Benutzer und 4 Identitäten; 9 Storage-Metadaten.
- **Ziel**: eigenes `mastersite_preservation.archives` mit 53 Tabellen/Objekten und 1558 Zeilen **vor** der portierten Business-Logik und einer nachträglichen Migration. Quell-/Zielarchive sind geschützt, Updates/Deletes im Ziel und der Pullrates-Quelle per Trigger untersagt.
- 9/9 Pullrates-Storage-Objekte kopiert, Dateinamen und Größen identisch, gesamt 524120 Bytes.
- Zwei seit Erstkopie abweichende Pullrates-Tabellen wurden nach Ziel-Snapshot ohne Zeilenlöschung abgeglichen; zwei numerische Werte unterscheiden sich danach nur in der JSONB-Textdarstellung `1.00`/`1` und `1.60`/`1.6`.
- 9 Feelings- und 40 Pullrates-Businessfunktionen in getrennten Schemas migriert; Trigger, interne Constraints und Indizes aus den Originalschemata ergänzt.
- 7 OAuth-Provider-Tabellen je unabhängigen Login-Bereich mit RLS; Daten-/Passworthashes beibehalten.
- Smoke-Tests: öffentliche Turnier-/Rarity-/Community-RPCs liefern Objekte. Synthetische Claims: Feelings-Profilzugriff auf eigenes Profil erlaubt, Pullrates eigene Listen-RPC erlaubt, Feelings-JWT für Pullrates verweigert und natives Hit-JWT für Feelings-Profile verweigert.
- **Kein echter Login mit bestehendem Passwort getestet** und kein produktiver Frontend-Cutover erfolgt.

Diese Datei enthält ausschließlich öffentliche technische Angaben, keine Benutzer-E-Mails, Passwort-Hashes, JWTs oder Datenbank-Secrets.
