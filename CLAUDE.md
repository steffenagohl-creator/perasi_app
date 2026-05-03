# Perasi App — Flutter WebView App fuer klara.services

## Kontext

Die App-Spezifikation liegt in `/home/admin/klara/FLUTTER_APP_PLAN.md`.
Die Gesamtplattform ist dokumentiert in `/home/admin/klara/CLAUDE.md`.

**Steffen ist Anfaenger in der Softwareentwicklung, kann seine Haende nicht bewegen und nutzt Sprachsteuerung.** Erklaerungen muessen verstaendlich sein. Code nicht ueber-abstrahieren. Immer auf Deutsch antworten.

## Was ist das?

Native App-Huelle (Android + iOS) um die bestehende Klara-Plattform. Die gesamte UI laeuft im WebView — die App ergaenzt native Features: Push (ntfy.sh), NFC-Einstempeln, Biometrie-Entsperrung.

- **App-Name:** Perasi
- **Package:** `services.klara.app`
- **API-URL:** `https://klara.services`
- **Backend-Code:** liegt in `/home/admin/klara/` — dort NICHTS aendern

## Barrierefreiheit (PFLICHT)

Die App MUSS vollstaendig fuer blinde Nutzer mit Screenreader (TalkBack/VoiceOver) bedienbar sein. Das gilt fuer ALLE nativen Screens (Splash, Offline, Update, NFC). Der WebView-Inhalt wird separat im Backend barrierefrei gemacht.

### Regeln fuer jeden nativen Screen

- **Semantics-Widget nutzen:** Jedes interaktive Element braucht ein `Semantics`-Widget mit `label` (was es ist) und `hint` (was passiert bei Tap). Oder mindestens `tooltip` bei Buttons.
- **Fokus-Reihenfolge:** Elemente muessen in logischer Lesereihenfolge angeordnet sein (oben nach unten, links nach rechts).
- **Keine Information nur ueber Farbe:** Fehler/Erfolg immer auch als Text oder Icon kommunizieren, nicht nur rot/gruen.
- **Touch-Targets:** Mindestens 48x48dp fuer alle tippbaren Elemente.
- **Keine reinen Icon-Buttons:** Jeder Button braucht einen lesbaren Text oder `semanticLabel`.
- **Status-Aenderungen ansagen:** Bei Ladevorgang, Erfolg, Fehler immer `SemanticsService.announce()` aufrufen, damit der Screenreader es vorliest.
- **ExcludeSemantics:** Dekorative Elemente (Hintergrundbilder, Platzhalter-Grafiken) mit `ExcludeSemantics` oder `Semantics(excludeSemantics: true)` ausblenden.

### Testen

Vor jedem Release: TalkBack (Android) oder VoiceOver (iOS) einschalten und JEDEN Screen einmal komplett durchgehen. Jedes Element muss vorgelesen werden und jede Aktion muss ausfuehrbar sein.

## Sprachsteuerung

Die App soll per Sprache fernsteuerbar sein. Das bedeutet:

- **Android Voice Access / iOS Voice Control:** Die nativen Screenreader-Labels sind gleichzeitig die Sprach-Targets. Wenn ein Button `semanticLabel: 'Erneut versuchen'` hat, kann der Nutzer "Tippe auf Erneut versuchen" sagen.
- **Klare, eindeutige Labels:** Keine generischen Namen wie "Button 1". Jedes Element braucht einen sprechenden Namen: "NFC scannen", "Zurueck zur Startseite", "Erneut versuchen".
- **WebView-Inhalte:** Werden ueber die bestehende Klara Voice Integration gesteuert (Whisper + Ollama auf dem VPS). Die App muss dafuer nur das Mikrofon freigeben.

## API-Schnittstellen: Natuerliche Sprache

Wenn die App eigene API-Endpoints bekommt (z.B. fuer Einstellungen oder Aktionen), muessen diese so gestaltet sein, dass ein Sprach-Dispatcher sie mit natuerlicher Sprache ansprechen kann:

- **Endpoint-Namen beschreibend:** `/api/nfc/scan-starten/` statt `/api/nfc/s/`
- **Antworten menschenlesbar:** JSON-Responses mit einem `message`-Feld in natuerlicher Sprache, z.B. `{"success": true, "message": "Frank wurde um 08:30 eingestempelt"}`
- **Fehlermeldungen klar:** `{"success": false, "message": "Chip nicht erkannt. Bitte erneut scannen."}` — keine kryptischen Error-Codes
- **Kompatibel mit Service Dispatcher:** Neue Endpoints muessen zum bestehenden Klara-Voice-System passen (siehe `pi/module_agents/brain/service_dispatcher.py` im Klara-Repo)

## Technologie-Stack

- **Framework:** Flutter (Dart)
- **WebView:** `flutter_inappwebview`
- **Push:** ntfy.sh (Self-Hosted, KEIN Firebase/FCM)
- **NFC:** `nfc_manager` (nur fuer Time-Tracking, NICHT Login)
- **Sichere Speicherung:** `flutter_secure_storage`
- **Biometrie:** `local_auth` (optional)
- **HTTP:** `http` Paket

## Wichtige URLs

- **Produktion:** `https://klara.services`
- **Gateway (WebView-Start):** `https://klara.services/gateway/`
- **ntfy Push-Server:** `https://klara.services/ntfy`
- **Versions-Check:** `GET /gateway/api/app-version/`
- **NFC-Checkin:** `POST /time-tracking/api/rfid-checkin/`
- **GitHub Repo:** `https://github.com/steffenagohl-creator/perasi_app`

## Projektstruktur

```
lib/
├── main.dart                          # App-Einstiegspunkt
├── app.dart                           # MaterialApp + Start-Ablauf
├── core/
│   ├── config.dart                    # URLs, Farben, Konstanten
│   ├── push/ntfy_service.dart         # ntfy.sh WebSocket-Verbindung
│   ├── nfc/nfc_service.dart           # NFC-Chip lesen
│   ├── auth/
│   │   ├── biometric_lock.dart        # Fingerabdruck/FaceID
│   │   └── cookie_bridge.dart         # Session-Cookies fuer native Calls
│   ├── version/version_check.dart     # App-Version pruefen
│   └── connectivity/connection_monitor.dart  # Online/Offline
├── screens/
│   ├── splash_screen.dart             # Ladebildschirm
│   ├── webview_screen.dart            # HAUPT-SCREEN: WebView
│   ├── offline_screen.dart            # Kein Internet
│   ├── update_screen.dart             # App veraltet
│   ├── nfc_screen.dart                # NFC-Einstempeln (nativ)
│   └── biometric_screen.dart          # Biometrie-Entsperrung
└── widgets/
    └── nfc_floating_button.dart       # NFC-Button ueber WebView
```

## Befehle

```bash
flutter pub get          # Abhaengigkeiten installieren
flutter analyze          # Statische Analyse (muss fehlerfrei sein!)
flutter test             # Tests ausfuehren
flutter build apk --release  # Android APK bauen
```

## Regeln

### NICHT verwenden
- **Kein Firebase** — wir nutzen ntfy.sh statt FCM
- **Kein `google-services.json`** — wird nicht gebraucht
- **Keine US-Cloud-Dienste** — alles Self-Hosted (DSGVO)
- **RFID NICHT als Login** — nur fuer Time-Tracking (Chip-UIDs sind klonbar)
- **Keine native UI fuer Module** — alles laeuft im WebView

### Code-Stil
- Kommentare im Code auf Deutsch
- Verstaendlich und nachvollziehbar (Steffen ist Anfaenger)
- Nicht ueber-abstrahieren
- `flutter analyze` muss immer fehlerfrei sein

### Backend-Aenderungen
- Backend-Code liegt in `/home/admin/klara/` — NICHT in diesem Repo
- Backend laeuft auf dem VPS (Django Gateway) — aendert Steffen separat
- Die App macht nur API-Calls gegen bestehende Endpoints

## Implementierungs-Phasen

- **Phase 1:** App-Grundgeruest (WebView, Splash, Offline, Versions-Check) ✅
- **Phase 2:** Push via ntfy.sh (WebSocket, Benachrichtigungen) ✅
- **Phase 3:** NFC-Einstempeln + Cookie-Bridge + JavaScript-Bridge ✅
- **Phase 4:** Biometrie-Entsperrung ✅
- **Phase 5:** Polishing + Release ✅

## Release-Workflow (NEU ab 2026-05-03 — About-Modul)

Die Plattform hat jetzt ein **About-Modul** unter `/api/about/`, das die
Versionen aller Apps zur Laufzeit aus dem Dateisystem liest. Damit ist
der Release-Ablauf fuer die Android-App in zwei Stufen aufgeteilt:

### Stufe A — Versions-Anzeige im About-Modal (KEIN Restart noetig)

Die Datei `android_version.json` in
`/home/admin/klara/vps/module_gateway/static/downloads/` wird vom
Gateway **direkt per `Path.open()` aus dem Dateisystem** gelesen
(Endpoint `api_about` in `vps/module_gateway/config/views.py:771`). Sie
geht NICHT durch WhiteNoise. Beim naechsten Modal-Aufruf erscheint die
neue Version automatisch.

```bash
# android_version.json bearbeiten:
# {"version": "1.2.2", "pub_date": "2026-05-03", "notes": "..."}
cd /home/admin/klara
git add vps/module_gateway/static/downloads/android_version.json
git commit -m "android: Version 1.2.2 freigeben"
git push
# FERTIG. Kein collectstatic, kein docker restart.
```

### Stufe B — Neue APK ausliefern (RESTART weiterhin Pflicht)

Die APK selbst liegt unter dem **ungehashten Pfad**
`/gateway/static/downloads/perasi.apk` und wird von WhiteNoise mit
`CompressedManifestStaticFilesStorage` aus dem Speicher-Cache
ausgeliefert. Ohne Container-Restart wird die alte APK weitergegeben →
"Parsing-Fehler" auf dem Tablet (anderer Keystore).

```bash
# 1. APK bauen
cd /home/admin/perasi_app
export ANDROID_HOME=/home/admin/android-sdk
flutter build apk --release

# 2. APK + Versions-JSON ins Gateway-Static-Verzeichnis legen
cp build/app/outputs/flutter-apk/app-release.apk \
   /home/admin/klara/vps/module_gateway/static/downloads/perasi.apk
# android_version.json in DERSELBEN Stelle aktualisieren

# 3. WhiteNoise-Cache invalidieren
docker exec gateway python3 /app/manage.py collectstatic --noinput
docker restart gateway   # PFLICHT, sonst alte APK aus Speicher-Cache

# 4. Im klara-Repo committen + pushen
cd /home/admin/klara
git add vps/module_gateway/static/downloads/perasi.apk \
        vps/module_gateway/static/downloads/android_version.json
git commit -m "android: APK 1.2.2 ausgeliefert"
git push
```

### Schema von `android_version.json`

```json
{
  "version": "1.2.2",
  "pub_date": "2026-05-03",
  "notes": "Kurze Release-Notiz, optional",
  "download_url": "/gateway/static/downloads/perasi.apk",
  "min_version": "1.2.0"
}
```

Pflicht ist nur `version`. Schema-Doku liegt in
`/home/admin/klara/vps/module_gateway/static/downloads/README.md`.

### Reihenfolge (immer in dieser Folge!)

1. `pubspec.yaml` → Version + Build-Nummer hochziehen
2. `flutter analyze` muss fehlerfrei sein
3. `flutter build apk --release`
4. APK kopieren nach `klara/vps/module_gateway/static/downloads/perasi.apk`
5. `android_version.json` daneben aktualisieren (`version`, `pub_date`)
6. `docker exec gateway python3 /app/manage.py collectstatic --noinput`
7. `docker restart gateway`
8. Pruefen: `curl -sI https://klara.services/gateway/static/downloads/perasi.apk`
   muss neue Groesse zeigen
9. Pruefen: `curl -s https://klara.services/api/about/` muss neue
   Version unter `perasi-android` zeigen
10. Im `klara`-Repo committen + pushen
11. Im `perasi_app`-Repo committen + pushen (Source-Code)

## Vollstaendiger Plan

Der detaillierte Plan mit allen Spezifikationen liegt in `/home/admin/klara/FLUTTER_APP_PLAN.md`.
