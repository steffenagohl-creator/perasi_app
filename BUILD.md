# Perasi App — Build & Deploy

Letzte Aktualisierung: 2026-05-03 (About-Modul integriert)

> **Schnelluebersicht steht in [CLAUDE.md](CLAUDE.md) ganz oben.** Hier sind nur die Details und der Hintergrund.

## Zwei Stufen

| Was geaendert wird | Container-Restart? |
|---|---|
| Nur `android_version.json` (Versions-Anzeige im About) | NEIN |
| APK selbst (`perasi.apk`) | JA |

Begruendung: `api_about` liest die JSON per `Path.open()` direkt aus dem
Dateisystem und umgeht damit WhiteNoise. Die APK liegt aber unter dem
ungehashten Pfad `/gateway/static/downloads/perasi.apk` und wird von
WhiteNoise aus dem Speicher-Cache ausgeliefert — ohne Restart kommt
auf dem Tablet die alte APK an, was als "Parsing-Fehler" erscheint
(weil der Keystore nicht passt).

## Stufe A — Nur Versions-JSON aktualisieren

Datei: `/home/admin/klara/vps/module_gateway/static/downloads/android_version.json`

```json
{
  "version": "1.2.2",
  "pub_date": "2026-05-03",
  "notes": "Optional",
  "download_url": "/gateway/static/downloads/perasi.apk",
  "min_version": "1.2.0"
}
```

```bash
cd /home/admin/klara
git add vps/module_gateway/static/downloads/android_version.json
git commit -m "android: Version X.Y.Z im About freigeben"
git push
```

Schema-Doku: `/home/admin/klara/vps/module_gateway/static/downloads/README.md`.

## Stufe B — Neue APK bauen und ausliefern

```bash
# 1. Version hochziehen in /home/admin/perasi_app/pubspec.yaml
#    version: 1.2.2+6   (Build-Nummer +N MUSS steigen)

# 2. Bauen
cd /home/admin/perasi_app
export ANDROID_HOME=/home/admin/android-sdk
flutter analyze
flutter build apk --release

# 3. APK + JSON ablegen
cp build/app/outputs/flutter-apk/app-release.apk \
   /home/admin/klara/vps/module_gateway/static/downloads/perasi.apk
# android_version.json daneben aktualisieren (Stufe A)

# 4. WhiteNoise-Cache invalidieren — PFLICHT
docker exec gateway python3 /app/manage.py collectstatic --noinput
docker restart gateway

# 5. Verifizieren
curl -sI https://klara.services/gateway/static/downloads/perasi.apk | grep content-length
curl -s https://klara.services/api/about/ | python3 -m json.tool | grep -A 2 perasi-android

# 6. Commits in beiden Repos
cd /home/admin/klara && git add vps/module_gateway/static/downloads/perasi.apk \
   vps/module_gateway/static/downloads/android_version.json && \
   git commit -m "android: APK X.Y.Z ausgeliefert" && git push
cd /home/admin/perasi_app && git add pubspec.yaml lib/ && \
   git commit -m "release: Version X.Y.Z" && git push
```

## Versionierung in pubspec.yaml

```yaml
version: 1.2.2+6   # major.minor.patch+buildnummer
```

- Major (1.x.x): Inkompatible Aenderung
- Minor (x.2.x): Neues Feature
- Patch (x.x.1): Bugfix
- Build-Nummer (+N): MUSS bei jedem Release steigen, sonst lehnt Android das Update ab

## Sonderfall: Zwangs-Update erzwingen

`vps/module_gateway/config/views.py` → `api_app_version()` anpassen
(`min_version` hochziehen). Das ist Code, kein Static — Restart
ohnehin Pflicht.

## Verwandte Dateien

- [CLAUDE.md](CLAUDE.md) — Schnellanleitung oben
- [ANDROID_APP_ARCHITEKTUR.md](ANDROID_APP_ARCHITEKTUR.md) — Architektur
- `/home/admin/klara/vps/module_gateway/static/downloads/README.md` — Schema fuer `*_version.json`
- `/home/admin/klara/vps/module_gateway/config/about.json` — App-Liste fuer About-Modal
