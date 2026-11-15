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
