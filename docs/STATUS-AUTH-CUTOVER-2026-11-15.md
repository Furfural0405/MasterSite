# MasterSite – Stand der sicheren Auth-Umstellung (15.11.2026)

**Branch:** `auth-cutover-staging` – separate, geschützte Vercel-Preview.
**Test-Deployment:** https://mastersite-git-auth-cutover-staging-michaeloeichhorst-8656.vercel.app/

## Was bereits bereitsteht
- `MASTERSITE_ENABLE_NEW_AUTH=1` ist **ausschließlich** für die Vercel-Preview dieses Branches konfiguriert. Die produktive MasterSite und die drei Original-Repositories bleiben unverändert.
- Der Build kopiert die Originale in temporäre Verzeichnisse und passt nur diese Kopien für die Preview an.
- Feelings-Turnier nutzt in der Preview `mastersite_feelings`, Pullrates `mastersite_pullrates`. Beide nutzen dasselbe Supabase-Projekt `entbtqtyxhbozjdbdvns`, aber **zwei voneinander getrennte Better-Auth-Sitzungen** und OIDC-Issuer.
- Browser-Logindaten werden nicht in `localStorage` geschrieben; ein kurzlebiges JWT wird nur im Arbeitsspeicher gehalten.
- Signup, Passwort-Reset und Feelings-Kontenlöschung bleiben absichtlich gesperrt, solange ihre sichere Umsetzung noch nicht getestet wurde.
- 12 MasterSite-Tests, 4 Hit-Tracker-Tests und 32 Pullrates-Tests bestanden. Alle drei Webseiten geben HTTP 200 zurück.
- Die kompilierten Staging-JavaScript-Dateien wurden geprüft: Sie enthalten die Zielprojektadresse, die neuen Schemas und **keine** alten Feelings-/Pullrates-Projektadressen.
- Ziel enthält 2 Feelings- und 4 Pullrates-Benutzerkonten mit 2+4 unabhängigen Credential-Hashes.
- User-Datenvergleich: Quell-/Ziel-Pullrates **781 Zeilen in 25 Tabellen**; exakt gleiche Prüfsummen bei **23 der 25 Tabellen**. Die verbleibenden zwei Tabellen sind laufend aktualisierte Marktpreis- und Preisworker-Daten. Keinen persönlichen Listendatensatz gelöscht.
- Card-images: 9 gesicherte Bilddateien, gleicher Name und gleiche Größe. Neue `site-assets`-Bucket und eng begrenzte Administrator-Upload-Regeln für Feelings; bisher keine gespeicherte Hintergrundbildreferenz im kopierten Settings-Datensatz.
- Staging-Policies für öffentliche Turnieranmeldung, Pullrates-Editor und Storage-Uploads per JWT-App-Issuer sind erstellt und mit synthetischen Rollentests geprüft; Einfügen von Test-Turnierteilnehmern erfolgte **nur in einer zurückgerollten Transaktion**.

## Exposed schemas – Fehler `PGRST106` behoben und nachgemessen

Die ursprüngliche HTTP-Prüfung lieferte 406 / `PGRST106`. Ein reines `NOTIFY pgrst` hat nicht geholfen.

Supabase dokumentiert für diesen Fall einen PostgREST-Rollen-Override:
https://supabase.com/kb/troubleshooting/pgrst106-the-schema-must-be-one-of-the-following-error-when-querying-an-exposed-schema

Daher wurden mit unveränderter Datenbankstruktur folgende Exposed schemas **explizit** eingetragen:

```sql
alter role authenticator set pgrst.db_schemas =
  'public, graphql_public, mastersite_feelings, mastersite_pullrates';
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
```

**Direkt nach der Änderung über HTTPS getestet:**
- `mastersite_feelings`: HTTP **200**, öffentlich lesbare `site_settings`-Zeilen
- `mastersite_pullrates`: HTTP **200**, öffentlich lesbare `pull_rates`-Zeilen

Die Einstellung ist reversibel: `supabase/staging/rollback_pgrst_exposed_schemas.sql`. **Achtung:** Solange der Rollen-Override existiert, überlagert er die `Exposed schemas`-Verwaltung im Supabase-Dashboard. Diese beiden Änderungen nicht gegeneinander ausspielen.

Selbstprüf-Link:
https://mastersite-git-auth-cutover-staging-michaeloeichhorst-8656.vercel.app/api/mastersite-schema-check

## Aktueller Login-Testbetrieb

- Better-Auth-Dienste `mastersite-feelings-auth` und `mastersite-pullrates-auth`: `ready=true, login_enabled=true`; HTTP 200 für `/get-session` ohne Cookie.
- Nur der **Vercel-Testbranch** verwendet im Frontend die neue Auth-Bridge. Die Produktivseite und die drei Original-Repositories sind noch nicht umgestellt.
- Die feste Preview-URL wurde zur `trustedOrigins`-Liste beider Edge Functions hinzugefügt.
- Die bisher importierten Nutzerkonten sind vorhanden: **2 Feelings + 4 Pullrates**. Kein QA-Benutzer ist hinzugefügt worden.
- **Echte E-Mail-/Passwort-Anmeldung und JWT-/RLS-Übertragung sind noch nicht als End-to-End-Test bestätigt.** Zur Bestätigung ist die Anmeldung des Kontoinhabers selbst auf der Preview nötig. Der Kontoinhaber muss **kein Passwort an ChatGPT schicken**.
- **Wichtig:** In der Vorschau derzeit keine neuen Benutzerdaten speichern oder bestehende Einträge ändern. Das Original-Pullrates-Projekt wird noch verwendet, und vor dem produktiven Cutover muss eine letzte Delta-Synchronisierung stattfinden.
- Funktionen zur Registrierung, Passwortzurücksetzung und zum Löschen von Alt-Konten sind bis zu ihrer gesicherten Umsetzung explizit deaktiviert.

## Vom Kontoinhaber bestätigte App-Tests

- **Feelings-Turnier:** Der ursprüngliche Ersteller-/Admin-Login über die neue Better-Auth-Instanz funktioniert. Die bisherigen Turnierdaten und Adminfunktionen werden angezeigt.
- **Pokémon Pullrates:** Der neue, unabhängige Login funktioniert. Die bestehenden Pulls/Kartenlisten werden korrekt angezeigt.
- **Pullrates-Schreibweg:** Im Ziel eine neue Testliste per authentifizierter `pull_lists('create')` angelegt und per `pull_lists('save')` gespeichert, aber beide Schritte in **derselben Transaktion vollständig zurückgerollt**. Danach unverändert 5 Listen; kein QA-Datensatz zurückgeblieben.
- **Feelings-Admin-Schreibweg:** Mit synthetischem, app-spezifischem Admin-JWT wurde `set_tournament_registration_enabled(false)` innerhalb einer Transaktion erfolgreich ausgeführt; nach `ROLLBACK` unverändert 1 Settings-Zeile, 1 Teilnehmer und 1 Turnierzustand.
- Beide Tests nutzen echte RLS- und RPC-Berechtigungen mit synthetischen Claims. Sie sind keine Aufforderung, auf der Preview produktiv zu speichern.
- Es wurden **keine vorhandenen persönlichen Listen, Passwörter oder Turnierdaten verändert**.

## Weitere fehlende End-to-End-Validierung

1. Mit echten, selbst eingegebenen Login-Daten in der Preview prüfen, ob die beiden **Third-Party Auth → Custom OIDC** Issuer für die Supabase Data API wirklich akzeptiert werden. Die beiden Issuer selbst antworten auf Discovery/JWKS; ob das Dashboard die Trust-Konfiguration gespeichert hat, ist mit den verfügbaren Connector-Tools nicht direkt lesbar.
2. Beide Better-Auth-Login-Dienste sind für den geschützten Test eingeschaltet. Vor Produktivfreigabe echte Sign-in-/JWT-/RLS-Tests auf der geschützten Preview durchführen.
3. Vor allem bei neuem Signup und Passwort-Reset sind E-Mail-Zustellung/Verifikation und Moderationsrechte noch nicht produktionsreif. Es wird kein angeblicher Erfolg gezeigt, wenn die Funktion nicht bereitsteht.
4. Pullrates-Realtime beim Zielprojekt auf die neuen Tabellen umstellen oder den getesteten 30-Sekunden-Polling-Fallback beibehalten.
5. Kompletten E2E-Test von User-Login, Datenbearbeitung, Listen, Chat, Admin, Turnierstand und Storage-Upload machen.
6. **Letzter Live-Delta-Abgleich** der Pullrates-Quelle vor Cutover; keine Pauschal-Überschreibung, keine Löschung. Erst danach produktive Frontends umstellen und alte Quellen pausieren.

**Keine Quell-Benutzerkonten, Fotos, persönlichen Daten oder Backups wurden gelöscht.**
