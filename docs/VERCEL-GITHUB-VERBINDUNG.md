# Vercel – notwendige einmalige GitHub-Verknüpfung

## Status am 15.11.2026
- Vercel Team `michaeloeichhorst-8656` wurde für ChatGPT erfolgreich freigegeben.
- Das Team hat aktuell keine Projekte.
- Die Erstellung des Git-verknüpften Vercel-Projekts `mastersite` für `Furfural0405/MasterSite` wurde von Vercel abgelehnt, weil **kein GitHub Login Connection** im Vercel-Account hinterlegt ist.
- **Es wurde deshalb noch kein Vercel-Projekt erstellt und noch nichts über Vercel veröffentlicht.**

## Einmalige Kontoaktion
1. Öffne https://vercel.com/account/settings (oder Avatar → Settings).
2. Wähle **Authentication** / **Login Connections**.
3. Verbinde dein GitHub-Konto **Furfural0405** mit Vercel und genehmige die nötigen Berechtigungen.
4. Sorge dafür, dass die Vercel GitHub App das Repository `Furfural0405/MasterSite` lesen darf. Vorzugsweise nur dieses Repository freigeben.
5. Danach ist die Git-basierte Projekterstellung mit Team `team_Mqlpu4RSNKzS4LsxukV9mJe7`, Name `mastersite`, Repo `Furfural0405/MasterSite`, Branch `main` möglich.

Offizielle Dokumentation: https://vercel.com/docs/accounts ; https://vercel.com/docs/git/vercel-for-github

## Anwendungssicherheit vor Produktivstart
Die aktuell eingecheckte Vercel-Konfiguration dient der Portal-Bereitstellung und der Vorbereitung der Auth-Proxy-Routen. **Nicht** als endgültig migrierte Anwendung freigeben:
- Die gebauten Feelings- und Pullrates-Frontends sprechen noch ihre ursprünglichen Supabase-Projekte an.
- Feelings-Turnier ist im Supabase Free-Tier derzeit pausiert.
- Die Better-Auth-Dienste sind absichtlich gesperrt. Die öffentlichen JWKS-Endpunkte sind erreichbar; Login-Funktionen sind weder freigeschaltet noch end-to-end getestet.
- Die bestehenden Geschäfts-RPCs, Datenbankrechte, Chat-/Realtime-Funktionen und Edge Functions müssen an das neue Auth-Modell angepasst werden.
- Die Cookie- und CORS-Einstellungen für die konkrete Vercel-Domain sind zu prüfen (bei Preview-Domains variabel).
- Vor dem Abschalten von `pokemon-pullrates` ist eine abschließende Delta-Synchronisierung und Benutzerprüfung notwendig.

Alle drei originalen GitHub-Repositories bleiben unverändert.

## Aktualisierung: Vercel-Vorschau erfolgreich bereitgestellt (15.11.2026)

- **Vercel-Teamzugriff:** erfolgreich freigegeben; Team `team_Mqlpu4RSNKzS4LsxukV9mJe7`.
- **GitHub-Kontoverbindung:** bestätigt, aber die Vercel-GitHub-App hat noch keinen Zugriff auf `Furfural0405/MasterSite`. Git-basierter Projektimport scheiterte mit `To link a GitHub repository, you need to install the GitHub integration first.`
- **Alternative funktionsfähige Vorschau:** Projekt `mastersite-vorschau` (`prj_7ulWMBTsghWfnJFZQfmzG0a2pyA1`), Deployment `dpl_HNzMFhG9q5xb3CjUGF2eNrrw4dJG` mit Zustand `READY`, Build vollständig erfolgreich.
- **Getestete URL:** https://mastersite-vorschau-gq76g9o7y-michaeloeichhorst-8656.vercel.app/ (durch Vercel Authentication geschützt).
- **HTTP 200 geprüft:** `/`, `/apps/pokemon-hit-tracker/`, `/apps/pokemon-pullrates/`, `/apps/feelings-turnier/`.
- **Auth-Rewrite geprüft:** `/api/auth/feelings/health` und `/api/auth/pullrates/health` geben beide `{"ready":true,"login_enabled":false}` zurück.
- **Build:** 4 Pokémon-Hit-Tracker-Tests und 32 Pokémon-Pullrates-Tests erfolgreich; alle drei Einzel-Apps sind erfolgreich gebaut.
- **Wichtig:** Ohne Git-Integration sind spätere GitHub-Commits **nicht automatisch** mit dem Vorschauprojekt synchronisiert. Direktes Deployment wurde aus neun MasterSite-Dateien gestartet; der Build holt die drei Original-Repositories nur lesend per Git.
- **Nicht abgeschlossen:** Datenbank- und Auth-Cutover, RPC/Edge/Realtime/RLS-Anpassungen und letzte Delta-Synchronisierung. Feelings-Turnier-Originalbackend ist pausiert, daher ist die Vorschau **kein vollständiger Funktionstest aller Webseiten**.

### Noch benötigter GitHub-App-Zugriff
Öffne https://github.com/settings/installations und konfiguriere die **Vercel** GitHub App, damit sie `Furfural0405/MasterSite` sehen darf. Alternativ über https://vercel.com/new den GitHub-Anbieter hinzufügen bzw. Installation abschließen. Danach kann das endgültige Git-basierte Vercel-Projekt `mastersite` verbunden und automatisiert bereitgestellt werden.
