# Perasi App — Technische Architektur

Letzte Aktualisierung: 2026-04-12, Version 1.2.0

## Ueberblick

Die Perasi-App ist eine **native WebView-Huelle** um die Klara-Pflegeplattform.
Die gesamte Plattform-UI laeuft im WebView — die App ergaenzt nur native
Faehigkeiten, die ein Browser nicht bieten kann. Es gibt bewusst **keine**
doppelte UI: Screens wie Dienstplan, Zeitkonto oder Wiki existieren nur
einmal im Django-Backend und werden per WebView angezeigt.

### Was die App tut (und was nicht)

| Tut die App | Tut das Backend (Django Gateway) |
|---|---|
| WebView anzeigen, Cookies verwalten | Alle UI-Seiten rendern, Login, Berechtigungen |
| Push-Empfang (ntfy.sh via WebSocket) | Push-Versand (ntfy Topics befuellen) |
| NFC-Chip lesen (fuer Time-Tracking) | RFID-Checkin-Endpoint, TimeLog-Speicherung |
| Biometrie-Entsperrung (Fingerabdruck) | Session-Verwaltung, Cookie-Lebensdauer |
| Offline-Erkennung, Versionscheck | App-Version-Endpoint, APK-Hosting |
| Shared-Tablet-Cookie persistent halten | SharedTabletMiddleware, Auto-Login |

---

## Infrastruktur-Kontext

Die App laeuft auf Android-Tablets und Handys der Mitarbeiter. Sie
kommuniziert ausschliesslich mit `https://klara.services` — dahinter steht:

```
Tablet/Handy (Perasi-App)
    |
    | HTTPS
    v
VPS (Strato, 87.106.160.84)
    ├── nginx_strato (SSL, Routing)
    ├── gateway (Django, Port 8000) ← WebView-Einstieg
    ├── ntfy (Push-Broker) ← WebSocket-Verbindung der App
    └── klara-voice (Whisper) ← Sprachbefehle
         |
         | WireGuard VPN (10.8.0.0/24)
         v
    Pi 5 (10.8.0.2)
    ├── 18 Django-Module (roster, time-tracking, wiki, ...)
    ├── keycloak (SSO, Port 8080)
    └── database (PostgreSQL)
```

Die App kennt nur den VPS — alle Pi-Module sind hinter dem VPS-Nginx
verborgen. Wenn die App z.B. `/roster/` laedt, routet nginx das ueber
den WireGuard-Tunnel an den Pi.

---

## Cookie-Architektur (kritisch fuer das Verstaendnis)

Die App ist im Kern ein **Cookie-Container**. Der WebView von
`flutter_inappwebview` hat einen **persistenten Cookie-Store**, der
App-Neustarts und Geraete-Reboots ueberlebt. Das Backend setzt Cookies,
der WebView haelt sie, und bei jedem Request werden sie automatisch
mitgeschickt.

### Plattform-Cookies die die App kennen muss

| Cookie | Gesetzt von | Zweck | Persistenz |
|---|---|---|---|
| `gw_session` | Gateway (Django) | Keycloak-basierte User-Session | 48h, erneuert sich bei Nutzung |
| `klara_shared_tablet` | Gateway `/api/shared-tablet/` | Shared-Tablet-Token fuer Auto-Login | 1 Jahr |
| `klara_trusted_device` | Gateway `/api/trust-device/` | Persoenliches Tablet Auto-Login | 90+ Tage |
| `klara_perspective_ts` | Gateway bei Team-Wechsel | Signal fuer Perspektiv-Refresh | Session |

### Wichtig: Cookies NICHT loeschen

Die App darf beim Start **niemals** `clearCache()` oder
`clearSessionCache()` aufrufen, weil das die Shared-Tablet- und
TrustedDevice-Cookies zerstoeren wuerde. Diese Cookies sind die Basis
fuer den passwortlosen Auto-Login.

---

## Shared-Tablet-Modus (seit Version 1.2.0)

### Konzept

Ein Gemeinschafts-Tablet im Pausenraum wird einmalig vom Admin als
"Shared Tablet" registriert. Danach loggt die Plattform automatisch
den Mitarbeiter ein, der gerade am Pi Zero per RFID-Chip eingestempelt
ist — ohne Passwort-Eingabe.

### Wie der Auto-Login funktioniert

```
Pi Zero: Mitarbeiter haelt Chip an den Reader
    |
    v
time-tracking: api_rfid_checkin()
    ├── TimeLog wird gespeichert (Ein-/Ausstempeln)
    ├── Keycloak-Perspektive wird aktualisiert
    └── ntfy-Event wird auf Topic shared-tablet-<client_username> gepublisht
         |
         v
Tablet (Perasi-App): WebView macht naechsten Request
    |
    v
Gateway: SharedTabletMiddleware prueft Cookie klara_shared_tablet
    ├── Ruft team-tools /shared-tablet/api/lookup/?token=<token> auf
    ├── Bekommt zurueck: Tablet-Info + aktive Worker-Liste
    └── Entscheidet:
        ├── 0 Worker  → logout + Redirect auf /shared-tablet/idle/
        ├── 1 Worker  → login(request, user) + session['active_team'] setzen
        └── 2+ Worker → logout + Redirect auf /shared-tablet/handover/
```

### Was die App dafuer tut

Sehr wenig — die Hauptlogik laeuft komplett im Gateway:

1. **Cookie persistent halten:** Der WebView-Cookie-Store haelt den
   `klara_shared_tablet`-Token ueber App-Neustarts hinweg.
2. **NFC deaktivieren:** Wenn der Cookie existiert, meldet `NfcService.isAvailable()`
   `false` zurueck. Der Pi Zero uebernimmt das Scannen.
3. **Debug-Log:** Beim Start loggt die App `[SHARED-TABLET] Modus aktiv`.

### Was die App NICHT tut (das macht das Backend)

- Kein eigener Auto-Login-Code in der App
- Kein Session-Switching in Dart
- Kein eigenes Polling auf Worker-Status
- Die Idle- und Handover-Screens sind HTML-Seiten im Gateway
  (`/shared-tablet/idle/`, `/shared-tablet/handover/`), die der WebView
  einfach anzeigt — mit eingebautem 5-Sekunden-JS-Polling

### Tablet als Shared-Tablet registrieren

1. Admin oeffnet Perasi-App auf dem Tablet
2. Loggt sich mit Keycloak-Passwort ein
3. Geht ins Admin-Cockpit → Verknuepfte Geraete
4. Klickt **"Dieses Geraet als Shared Tablet registrieren"**
5. Backend setzt den Cookie `klara_shared_tablet` in der Response
6. Admin meldet sich ab
7. Ab jetzt uebernimmt die SharedTabletMiddleware

### Voraussetzungen fuer Auto-Login

- Mitarbeiter muss **mindestens einmal per Keycloak-Passwort** eingeloggt
  gewesen sein (damit sein Django-User + Gruppen existieren)
- Mitarbeiter muss einen **RFID-Chip zugewiesen** haben (in master-data)
- Das Tablet muss als Shared-Tablet **registriert** sein (Cookie vorhanden)

### Sicherheit

- Admins (`is_staff` oder `is_superuser`) werden **nie** per Auto-Login
  eingeloggt — sie muessen immer per Passwort rein
- Die `session['active_team']` wird zwingend auf den Arbeitgeber des
  Tablets gesetzt (Berechtigungs-Isolation)
- Der Arbeitgeber selbst stempelt nicht ein (nur Pflegekraefte), er kann
  also die Auto-Login-Zaehlung nicht stoeren

---

## Push-Benachrichtigungen (ntfy.sh)

### Architektur

```
Backend publisht auf ntfy Topic
    |
    v
ntfy-Server (VPS, Container "ntfy", Port 80)
    |
    | WebSocket (wss://klara.services/ntfy/<topic>/ws)
    v
Perasi-App: NtfyService
    └── Zeigt lokale Android-Benachrichtigung an
```

### Topics

| Topic-Muster | Wer publisht | Wer lauscht |
|---|---|---|
| `user_<username>` | Chat-Modul, Kalender | Perasi-App des jeweiligen Users |
| `shared-tablet-<client_username>` | time-tracking bei RFID-Stempel | Shared-Tablets dieses Arbeitgebers (Follow-up, noch nicht implementiert in App) |

### Follow-up: ntfy fuer Shared-Tablets

Noch nicht umgesetzt: Die App soll zusaetzlich das Topic
`shared-tablet-<client_username>` abonnieren und bei Events
`_webViewController?.reload()` aufrufen. Damit wuerde das Tablet
**ohne User-Interaktion** sofort auf Ein-/Ausstempeln reagieren, statt
erst beim naechsten Tap (wo die Middleware dann greift).

Der Backend-Teil ist fertig (`api_rfid_checkin` publisht bereits auf
das Topic seit Commit `c29c6a3`). Nur der App-Teil fehlt.

---

## NFC-Einstempeln

### Zwei verschiedene NFC-Szenarien

| Szenario | Wer scannt | Wo laeuft der Code |
|---|---|---|
| **Pi Zero Terminal** | Stationaerer Reader (ACR122U) am Pi Zero | `pi_zero/checkin.py` auf dem Pi Zero selbst |
| **Persoenliches Handy** | Das Handy des Mitarbeiters | `lib/core/nfc/nfc_service.dart` in der Perasi-App |

Auf **Shared-Tablets** ist NFC deaktiviert (`NfcService.isAvailable()` →
false), weil der Pi Zero das Scannen uebernimmt.

### Chip-UID → Mitarbeiter-Zuordnung

Die App liest die Chip-UID und schickt sie per POST an
`/time-tracking/api/rfid-checkin/`. Das Backend macht den Lookup in
`master-data` (`RFIDChip`-Tabelle) und entscheidet: Einstempeln oder
Ausstempeln (Toggle-Logik basierend auf offenem TimeLog).

### Sicherheitsregel (PFLICHT)

**RFID-Chips werden NIE als Login verwendet**, nur fuer Time-Tracking.
Chip-UIDs sind trivial klonbar (NFC-Kopierer ca. 20 EUR). Ein geklonter
Chip kann maximal eine falsche Stempelung verursachen, aber keinen
Account-Zugriff.

---

## Versions-Check und In-App-Update

### Ablauf beim App-Start

```
Splash Screen → GET /gateway/api/app-version/
    ├── Antwort: {"current_version": "1.2.0", "min_version": "1.1.0", "download_url": "..."}
    ├── App-Version >= min_version → WebView laden
    └── App-Version < min_version → Update-Screen anzeigen
```

### APK-Download

Die APK wird direkt vom Gateway-Static-Verzeichnis ausgeliefert:
`https://klara.services/gateway/static/downloads/perasi.apk`

**WICHTIG:** Nach jedem APK-Deploy muss `docker restart gateway` folgen
(WhiteNoise-Cache-Problem, dokumentiert in `BUILD.md`).

### Versions-Endpoint (Gateway)

`GET /api/app-version/` liefert:
```json
{"min_version": "1.2.0", "latest_version": "1.2.1"}
```

- App < `min_version` → **Update-Screen erzwungen** (User muss aktualisieren)
- App < `latest_version` → Update empfohlen
- Die Werte stehen in `vps/module_gateway/config/views.py` → `api_app_version()`

### PFLICHT bei jedem Release: Versionen an DREI Stellen anpassen

| Stelle | Datei | Was aendern |
|---|---|---|
| **1. App-Version** | `perasi_app/pubspec.yaml` | `version: X.Y.Z+N` (Build-Nr muss steigen) |
| **2. latest_version** | `klara/vps/module_gateway/config/views.py` | In `api_app_version()` anpassen |
| **3. min_version** | Gleiche Datei | Hochziehen wenn Update Pflicht sein soll |

Danach: APK bauen → deployen → `docker restart gateway` (2x: fuer APK + fuer Versions-Endpoint).

---

## Bekannte Stolperfallen fuer Claude-Instanzen

### 1. WhiteNoise-Cache (Build-Deploy)

Nach `collectstatic` MUSS `docker restart gateway` folgen, sonst liefert
der Server die alte APK aus dem Speicher-Cache. Details in `BUILD.md`.

### 2. klara_common ist pip-installiert, nicht bind-mounted

Der Gateway-Container hat `klara_common` per `pip install` im
`site-packages`. Aenderungen an `klara_common/klara_common/middleware.py`
im Repo-Root erfordern einen **Container-Rebuild** (`docker compose build
gateway`), nicht nur einen Restart. Workflow:

```bash
cd ~/klara
bash scripts/prepare_build.sh
docker compose -f vps/docker-compose.yml build gateway
docker compose -f vps/docker-compose.yml up -d gateway
bash scripts/prepare_build.sh --clean
```

### 3. Zwei Repos, zwei Hosts

| Repo | Host | Pfad | Fuer |
|---|---|---|---|
| `klara` | VPS + Pi 5 | `/home/admin/klara/` bzw. `/mnt/ssd/PflegePlattform/` | Backend (Gateway, Pi-Module, klara_common) |
| `perasi_app` | VPS | `/home/admin/perasi_app/` | Flutter-App (APK-Build) |

Beide Klara-Checkouts zeigen auf dasselbe GitHub-Repo. Der Pi 5 muss
nach Aenderungen am Backend separat `git pull` machen. Der VPS kann
den Pi 5 per SSH erreichen (`ssh 10.8.0.2`).

### 4. views/__init__.py in team_tools

`pi/module_team_tools/team_tools_app/views/` ist ein **Python-Package**
mit `__init__.py` als Re-Export-Shim. Jede neue View-Funktion in einer
Subdatei (z.B. `shared_tablet.py`) muss **zusaetzlich** in `__init__.py`
importiert UND in `__all__` gelistet werden, sonst gibt es einen
`ImportError` beim Container-Start.

### 5. Steffens Username

Der echte `client_username` des Arbeitgebers ist **`steffen.gohl`**
(mit Punkt, klein). In alten Docstrings, Tests und einer Migration
taucht `steffengohl` (zusammengeschrieben) auf — das ist der alte Stand
oder ein Dummy, NICHT der produktive Username.

### 6. Parallele Claude-Instanzen

Es arbeiten mehrere Claude-Instanzen gleichzeitig am Klara-Repo (z.B.
VPS-Claude und Pi-5-Claude). Beim Committen **immer namentlich stagen**
(`git add datei1 datei2`), **niemals** `git add -A` oder `git add .`.
Fremde Aenderungen im Working-Directory einfach in Ruhe lassen.

### 7. Backend-Aenderungen nur im Klara-Repo

Die Perasi-App macht **keine eigenen API-Endpoints** — sie ruft nur
bestehende auf. Wenn ein neuer Endpoint noetig ist, gehoert er ins
Klara-Repo (Gateway oder Pi-Modul), nicht in die Flutter-App.

### 8. Mobile-Scroll-Bugs kommen fast immer aus dem Klara-Repo

Wenn in der Perasi-App das Scrollen hakt (besonders "nur mit zwei
Fingern" Symptom), ist die Ursache fast immer im globalen CSS/JS der
Klara-Plattform, nicht in der App selbst. Die App ist nur ein WebView —
HTML/CSS/JS kommen live vom Server. Der theme-loader.js, base.html-
Templates und Keycloak-Theme sind die üblichen Fundstellen.

**Vollstaendige Liste der Mobile-Scroll-Killer-Patterns:** siehe
`ARCHITEKTUR.md` Abschnitt 9 "Mobile-Scroll-Patterns" im klara-Repo.
Enthält reproduzierbare Teststrategie via Playwright+Chromium Mobile-
Emulation und konkrete Fix-Commits.

**App-seitige Stellen die Mobile-Scroll beeinflussen (selten schuld,
aber wissen):**
- `lib/screens/webview_screen.dart`: WebView-Settings
  (`useHybridComposition`, `overScrollMode`, Pull-to-Refresh)
- Wenn Scroll nur in App aber nicht im mobilen Browser hakt: hier
  schauen. Sonst immer erst klara-Repo pruefen.

---

## Versionshistorie

| Version | Datum | Aenderungen |
|---|---|---|
| 1.0.0 | Maerz 2026 | Erster Release: WebView, Push, NFC, Biometrie, Offline-Screen |
| 1.1.0 | Maerz 2026 | In-App-Update, Scroll-Optimierung |
| 1.1.1 | Maerz 2026 | Fix 404-Fehlerscreen, Release-Signierung mit echtem Keystore |
| 1.2.0 | April 2026 | Shared-Tablet-Modus (Cookie-Check, NFC-Deaktivierung, Debug-Log) |

## Verwandte Dokumente

- `CLAUDE.md` — Regeln und Projektstruktur (Pflicht-Lektuere fuer jede Instanz)
- `BUILD.md` — Build- und Deploy-Anleitung mit WhiteNoise-Dokumentation
- `/home/admin/klara/ARCHITEKTUR.md` — Gesamtplattform-Architektur
- `/home/admin/klara/BERECHTIGUNGSKONZEPT.md` — Rollen, Permissions, Team-Isolation
- Obsidian-Vault auf Pi 5: `05 Gesammelte Plaene/2026-04-11 Shared-Tablet-Auto-Login.md`
