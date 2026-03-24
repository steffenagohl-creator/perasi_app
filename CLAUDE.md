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
- **Phase 2:** Push via ntfy.sh (WebSocket, Benachrichtigungen)
- **Phase 3:** NFC-Einstempeln + Cookie-Bridge + JavaScript-Bridge
- **Phase 4:** Biometrie-Entsperrung (optional)
- **Phase 5:** Polishing + Release

## Vollstaendiger Plan

Der detaillierte Plan mit allen Spezifikationen liegt in `/home/admin/klara/FLUTTER_APP_PLAN.md`.
