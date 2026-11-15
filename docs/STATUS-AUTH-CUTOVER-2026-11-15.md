# MasterSite – Stand der sicheren Auth-Umstellung (15.11.2026)

**Branch:** `auth-cutover-staging` – separate, geschützte Vercel-Preview.
**Test-Deployment:** https://mastersite-nqfxz37rq-michaeloeichhorst-8656.vercel.app/

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

## Aktueller harter Blocker: Exposed schemas

**Vom eigenen Vercel-Backend aus über die tatsächliche Supabase Data API getestet:**

| Schema | HTTP | Code | Ergebnis |
|---|---:|---|---|
| `mastersite_feelings` | 406 | `PGRST106` | Nicht in PostgREST Exposed schemas |
| `mastersite_pullrates` | 406 | `PGRST106` | Nicht in PostgREST Exposed schemas |

Selbstprüf-URL (Preview-Zugriff ggf. nur mit Vercel-Login):
https://mastersite-nqfxz37rq-michaeloeichhorst-8656.vercel.app/api/mastersite-schema-check

**Nötige Aktion im Supabase-Dashboard:**
https://supabase.com/dashboard/project/entbtqtyxhbozjdbdvns/settings/api

Unter **Exposed schemas** die Namen `mastersite_feelings` und `mastersite_pullrates` zu `public` hinzufügen, **Save** klicken und anschließend erneut prüfen. Nur diese zwei Schemas, nicht die privaten Auth-, Sicherungs- und Helper-Schemas hinzufügen.

## Weitere fehlende End-to-End-Validierung

1. Prüfen, ob die beiden **Third-Party Auth → Custom OIDC** Issuer tatsächlich beim Zielprojekt eingetragen sind. Die beiden Issuer selbst antworten auf Discovery/JWKS; ob das Dashboard die Trust-Konfiguration gespeichert hat, ist mit den verfügbaren Connector-Tools nicht direkt lesbar.
2. Neue Better-Auth-Login-Dienste stehen bewusst auf `login_enabled=false`. Vor Freigabe echte Sign-in-/JWT-/RLS-Tests auf der geschützten Preview durchführen.
3. Vor allem bei neuem Signup und Passwort-Reset sind E-Mail-Zustellung/Verifikation und Moderationsrechte noch nicht produktionsreif. Es wird kein angeblicher Erfolg gezeigt, wenn die Funktion nicht bereitsteht.
4. Pullrates-Realtime beim Zielprojekt auf die neuen Tabellen umstellen oder den getesteten 30-Sekunden-Polling-Fallback beibehalten.
5. Kompletten E2E-Test von User-Login, Datenbearbeitung, Listen, Chat, Admin, Turnierstand und Storage-Upload machen.
6. **Letzter Live-Delta-Abgleich** der Pullrates-Quelle vor Cutover; keine Pauschal-Überschreibung, keine Löschung. Erst danach produktive Frontends umstellen und alte Quellen pausieren.

**Keine Quell-Benutzerkonten, Fotos, persönlichen Daten oder Backups wurden gelöscht.**
