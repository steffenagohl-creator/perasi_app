# Perasi App — Build & Deploy Anleitung

Letzte Aktualisierung: 2026-05-03 (About-Modul integriert)

## Zwei Wege, Versionen zu pflegen

Seit dem About-Modul (Stand 2026-05-03) gibt es zwei getrennte Stufen:

| Was geaendert wird | Container-Restart? | Warum |
|---|---|---|
| **Nur `android_version.json`** (Versions-Anzeige) | NEIN | Wird von `api_about` per `Path.open()` direkt aus dem Dateisystem gelesen, geht nicht durch WhiteNoise |
| **APK selbst** (`perasi.apk`) | JA | WhiteNoise cached ungehashte Statics im Speicher → Restart noetig, sonst Parsing-Fehler |

**Faustregel:** Wenn du nur ein Versions-Bump im Modal sichtbar machen willst (z.B. weil der Build extern erfolgte), reicht JSON aktualisieren + push. Wenn du eine neue APK ausspielst, brauchst du den Restart.

---

## Stufe A — Nur Versions-JSON aktualisieren (kein Restart)

```bash
# /home/admin/klara/vps/module_gateway/static/downloads/android_version.json
{
  "version": "1.2.2",
  "pub_date": "2026-05-03",
  "notes": "Bugfix Shared-Tablet-Logout",
  "download_url": "/gateway/static/downloads/perasi.apk",
  "min_version": "1.2.0"
}
```

```bash
cd /home/admin/klara
git add vps/module_gateway/static/downloads/android_version.json
git commit -m "android: Version 1.2.2 im About-Modal freigeben"
git push
```

Beim naechsten Aufruf von `/api/about/` zeigt das Modal die neue Version. Schema-Doku: `/home/admin/klara/vps/module_gateway/static/downloads/README.md`.

---

## Stufe B — Neue APK bauen und ausliefern

### 1. Version in pubspec.yaml hochziehen

```yaml
# /home/admin/perasi_app/pubspec.yaml
version: 1.2.2+6   # Format: major.minor.patch+buildnummer
```

- **Major** (1.x.x): Grundlegende Aenderungen, inkompatibel
- **Minor** (x.2.x): Neues Feature
- **Patch** (x.x.1): Bugfixes
- **Build-Nummer** (+6): MUSS bei jedem Release um 1 steigen, sonst lehnt Android das Update ab

### 2. APK bauen

```bash
cd /home/admin/perasi_app
export ANDROID_HOME=/home/admin/android-sdk
flutter analyze       # MUSS fehlerfrei sein
flutter build apk --release
```

Die fertige APK liegt unter: `build/app/outputs/flutter-apk/app-release.apk`

### 3. APK + JSON ins Gateway-Static-Verzeichnis legen

```bash
# APK kopieren
cp build/app/outputs/flutter-apk/app-release.apk \
   /home/admin/klara/vps/module_gateway/static/downloads/perasi.apk

# android_version.json daneben aktualisieren (Stufe A)
# {"version": "1.2.2", "pub_date": "2026-05-03", "notes": "..."}
```

### 4. WhiteNoise-Cache invalidieren (PFLICHT)

```bash
docker exec gateway python3 /app/manage.py collectstatic --noinput
docker restart gateway
```

**Beide Schritte sind Pflicht.** Ohne `docker restart gateway` liefert
der Server die alte APK aus dem Speicher-Cache aus.

### 5. Im klara-Repo committen + pushen

```bash
cd /home/admin/klara
git add vps/module_gateway/static/downloads/perasi.apk \
        vps/module_gateway/static/downloads/android_version.json
git commit -m "android: APK 1.2.2 ausgeliefert"
git push
```

### 6. Im perasi_app-Repo committen + pushen

```bash
cd /home/admin/perasi_app
git add pubspec.yaml lib/
git commit -m "release: Version 1.2.2"
git push
```

---

## Verifikation nach dem Deploy

```bash
# APK-Groesse auf Server pruefen (muss zur lokalen passen):
curl -sI https://klara.services/gateway/static/downloads/perasi.apk | grep content-length
ls -la build/app/outputs/flutter-apk/app-release.apk

# About-Endpoint pruefen (muss neue Version zeigen):
curl -s https://klara.services/api/about/ | python3 -m json.tool | grep -A 2 "perasi-android"
```

---

## WhiteNoise-Cache-Problem (entdeckt 2026-04-11, weiterhin relevant)

### Was passiert ist

Nach Kopieren einer neuen APK + `collectstatic` zeigte das Tablet
**"Beim Parsen des Pakets ist ein Problem aufgetreten"**.

### Ursache

Der Gateway-Container nutzt **WhiteNoise** mit `CompressedManifestStaticFilesStorage`
(siehe `vps/module_gateway/config/settings.py:193`). WhiteNoise laedt
beim Container-Start **alle statischen Dateien in den Speicher** und
liefert sie von dort aus. Eine neue Datei auf der Festplatte wird **nicht
bemerkt** — alter Speicher-Cache wird weiter ausgeliefert.

Bei CSS/JS faellt das nicht auf, weil WhiteNoise sie mit Content-Hash
versioniert (`perasi.a8e407f8235a.apk`). Die APK wird aber unter dem
**ungehashten Namen** `perasi.apk` heruntergeladen und genau dieser
Pfad wird aus dem Speicher-Cache bedient, ohne die Festplatte zu pruefen.

### Loesung

`docker restart gateway` zwingt WhiteNoise, alle Dateien neu einzulesen.
Kein Container-Rebuild noetig, nur ein Restart.

### Warum die JSON-Dateien KEINEN Restart brauchen

Die `*_version.json`-Dateien werden von der Django-View `api_about` per
`Path.open()` direkt aus dem Dateisystem gelesen, NICHT als Static-Asset
ausgeliefert. Damit umgehen sie WhiteNoise komplett. Pruefe selbst in
`vps/module_gateway/config/views.py:771-835` und `_read_json_file()`
darunter.

### Vergleich: Wie der Desktop-Agent das automatisiert

Der Desktop-Build-Agent (Tauri) macht den Restart per GitHub Actions
automatisch per SSH (siehe `perasi_desktop/.github/workflows/build-windows.yml:132-135`):

```bash
ssh admin@VPS 'docker exec gateway python manage.py collectstatic --noinput \
               && docker restart gateway && echo "Deploy abgeschlossen"'
```

Fuer die Android-App machen wir das aktuell **manuell auf dem VPS**.

---

## Checkliste vor dem Release

- [ ] `pubspec.yaml`: Version + Build-Nummer hochgezogen
- [ ] `flutter analyze` fehlerfrei
- [ ] `flutter build apk --release` erfolgreich
- [ ] APK kopiert nach `klara/vps/module_gateway/static/downloads/perasi.apk`
- [ ] `android_version.json` aktualisiert (`version`, `pub_date`, optional `notes`)
- [ ] `docker exec gateway python3 /app/manage.py collectstatic --noinput`
- [ ] `docker restart gateway`
- [ ] `curl -sI` Groesse auf Server = lokale Groesse
- [ ] `curl -s /api/about/` zeigt neue Version unter `perasi-android`
- [ ] Auf Tablet installiert, Grundfunktion geprueft (TalkBack-Test bei UI-Aenderungen)
- [ ] Commit + Push in beiden Repos (`klara` UND `perasi_app`)

## Verwandte Dateien

- `CLAUDE.md` — Projektregeln, Release-Workflow zusammengefasst
- `ANDROID_APP_ARCHITEKTUR.md` — Architektur-Doku, enthaelt Release-Architektur
- `/home/admin/klara/vps/module_gateway/static/downloads/README.md` — Schema fuer `*_version.json`
- `/home/admin/klara/vps/module_gateway/config/about.json` — App-Liste fuer About-Modal
