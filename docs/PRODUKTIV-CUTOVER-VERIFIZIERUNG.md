# MasterSite – letzte Freigabeschritte für produktiven Cutover

**Ziel:** Alle drei Anwendungen aus einem aktiven Supabase-Projekt betreiben, mit separaten Feelings- und Pullrates-Konten. Original-Repositories und Sicherungsarchive bleiben unangetastet.

## Sicher umgesetzt und verifiziert (15.11.2026)

- Ziel `pokemon-hit-tracker` ist `ACTIVE_HEALTHY`, das Pullrates-Original ebenfalls. Feelings-Original bleibt pausiert.
- Zwei getrennte Better-Auth-Issuer mit OIDC-/RLS-Anbindung. Bisherige Anmeldungen für Feelings (Ersteller-/Admin) und Pullrates (Pulls und Benutzerbereich) vom Kontoinhaber erfolgreich getestet.
- Die Frontends werden ausschließlich in temporären Build-Klonen geändert; Original-Repositories unverändert.
- Gespeicherte persönliche Pullrates-Daten aus **23 von 25 Tabellen** exakt identisch (MD5 der geordneten JSONB-Zeilen); Ausnahmen sind die automatisch durch Worker aktualisierten `cardmarket_prices` und `market_worker_state`. Beide haben weiterhin dieselben Zeilenzahlen. **781 Anwendungstabellen-Zeilen** in Original und Ziel. 5 Listen, 2 Chatnachrichten und 9 Bilder behalten.
- Frischer Quell-Snapshot in `mastersite_preservation.archives`: 28 Objekte, 798 Zeilen; frischer Ziel-Snapshot: 67 Objekte, 1560 Zeilen. Archive sind append-only, dürfen nicht gelöscht werden.
- Pullrates-Preisworker direkt auf das Zielschema umgestellt, unter `mastersite-cardmarket-refresh` deployed, neuer zufällig generierter Token **nur verschlüsselt in Supabase Vault**, Cron alle 30 Min., unmittelbar getestet mit HTTP 200 und 176 verarbeiteten Produktpreisen.
- Chat-Ablaufkontrolle als Cron jede Minute eingerichtet; sie löscht nur per Originalregel abgelaufene Nachrichten/Entwürfe. Vor Einrichtung waren 0 Nachrichten bzw. Entwürfe abgelaufen; die 2 Chatnachrichten wurden erhalten.
- Supabase-Realtime-Publikation für card_details, card_images, pull_rates im Zielschema.
- Für neue Benutzer je Anwendung **INSERT-only**-Registrierungs-Trigger, die ausschließlich **pending**-Profile mit `approved=false`, `is_creator=false` und nicht-Admin-Rollen anlegen. Durch Rollback-Tests geprüft, kein QA-Konto verblieben.
- Neue Bestätigungs- und Passwort-Reset-API sowie Frontend-Integration auf **auth-cutover-staging** vorbereitet; 13 MasterSite-Tests, 4 Hit-Tracker-Tests und 32 Pullrates-Tests bestanden, React/Vite-Preview erfolgreich gebaut.
- Datenschutz: Original-Benutzer-UUIDs, Passwort-Hashes, Admin- und Listenzuordnungen wurden erhalten. Keine produktiven Benutzerpasswörter oder Projektservice-Schlüssel in GitHub.

## Noch erforderlich: E-Mail-Absender im Ziel-Supabase

Derzeit melden beide Auth-Services HTTP 200 mit `login_enabled=true`, aber `signup_enabled=false` und `password_reset_enabled=false`. Das ist **Absicht**, nicht ein Fehler: Es existiert noch kein Mailversand für Bestätigungen/Passwort-Reset.

Mögliche freie Option: [Resend](https://resend.com/), Free-Tier laut Preisübersicht bis 3000 E-Mails/Monat und 100/Tag. Damit neue Registranten *beliebiger* E-Mail-Adressen E-Mails erhalten, muss die eigene Absenderdomain bei Resend verifiziert werden. Die `resend.dev`-Testdomain ist kein Ersatz für einen öffentlichen Versanddienst.

**Kontoinhaber richtet ein:**

1. Bei Resend Absenderdomain verifizieren und einen auf E-Mail-Versand beschränkten API-Key erstellen.
2. Im [Supabase-Projekt](https://supabase.com/dashboard/project/entbtqtyxhbozjdbdvns/functions) unter **Edge Functions → Secrets** diese beiden Secrets setzen:
   - `MASTERSITE_RESEND_API_KEY` = der geheime Resend-API-Key (beginnt mit `re_`)
   - `MASTERSITE_MAIL_FROM` = verifizierte Absenderadresse, z. B. `MasterSite <anmeldung@eigene-domain.de>`
3. **Keinen API-Key in den Chat oder GitHub kopieren.** Die Secrets werden ausschließlich im Supabase-Dashboard gespeichert.
4. Nach dem Speichern mitteilen, dass der Versand konfiguriert ist. Die beiden Edge Functions anschließend erneut deployen, Health-Checks und tatsächlichen Empfang der Mails prüfen. Erst dann `signup_enabled`/ `password_reset_enabled` als bereit bewerten.

Die Implementierung nutzt Better Auth 1.7.21 und die Resend REST API über HTTPS. E-Mails enthalten zeitlich begrenzte Links; neue Benutzer müssen ihre E-Mail bestätigen, bevor sie sich anmelden können. Passwortzurücksetzungen entziehen bei Erfolg alte Sitzungen. Selbständige Registrierung kann niemals eine Adminrolle vergeben. Ohne diese zwei Supabase-Secrets bleiben Registrierung und Reset gesperrt, **bestehende Logins bleiben aktiv**.

## Zusätzliche Freigabekriterien

- Neuen Benutzer registrieren und Verifizierungs-E-Mail empfangen, die Verifizierung und anschließende Anmeldung testen; gleiche E-Mail mit **unterschiedlichen Passwörtern** in beiden Apps testen. Keine bestehenden Benutzerdaten überschreiben.
- Passwort zurücksetzen testen, alte Sitzungen widerrufen und den alten Zugang kontrolliert als ungültig prüfen. Der Kontoinhaber muss keine Passwörter im Chat senden.
- Änderungsrechte, Profilfreigabe, Adminrechte, Turnieraufnahme, Bilder und Pullraten-Listen prüfen; Fehlermeldungen für ungültige Tokens dürfen keine vertraulichen Daten preisgeben.
- Beim endgültigen Cutover die Pullrates-Quelle für neue Schreibvorgänge kontrolliert stoppen; **danach** einen vollständigen letzten Delta-Abgleich durchführen. Aktuell unterscheiden sich nur Preis- und Workerstatus, und die Zieldaten sind **neuer**; ältere Quellenwerte nicht überschreiben.
- Vercel **Production** `MASTERSITE_ENABLE_NEW_AUTH=1` setzen, geprüften Staging-Branch nach `main` übernehmen und Vercel-Deployment/Benutzer-Login erneut testen. Erst danach alte Pullrates-Quelle pausieren. Keine Original-GitHub-Repositories löschen oder verändern.
- Staging- und Live-URLs: [geschützte Staging-Version](https://mastersite-git-auth-cutover-staging-michaeloeichhorst-8656.vercel.app/), [bisheriger Live-Betrieb](https://mastersite-eta.vercel.app/).

**Keine finale Freigabe, solange die E-Mail-Identitätsprüfung fehlt.** Sonst würden öffentlich erreichbare Registrierung und Passwortzurücksetzung bei der Umstellung schlechter funktionieren als vorher. Dieser Stopp schützt bestehende Benutzerkonten.
