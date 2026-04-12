# Perasi App — Build & Deploy Anleitung

## APK bauen

```bash
cd /home/admin/perasi_app
export ANDROID_HOME=/home/admin/android-sdk
flutter build apk --release
```

Die fertige APK liegt dann unter:
`build/app/outputs/flutter-apk/app-release.apk`

## APK auf den Gateway deployen

```bash
# 1. APK ins Gateway-Static-Verzeichnis kopieren
cp build/app/outputs/flutter-apk/app-release.apk \
   /home/admin/klara/vps/module_gateway/static/downloads/perasi.apk

# 2. collectstatic im Container ausfuehren (erzeugt gehashte Kopie)
docker exec gateway python3 /app/manage.py collectstatic --noinput

# 3. Gateway Container neu starten (WICHTIG — siehe WhiteNoise-Problem unten)
docker restart gateway
```

**Alle drei Schritte sind Pflicht.** Ohne Schritt 3 liefert der Server
die alte APK aus dem Speicher-Cache aus.

## WhiteNoise-Cache-Problem (entdeckt am 11.04.2026)

### Was passiert ist

Nach dem Kopieren einer neuen APK und `collectstatic` kam auf dem Tablet
die Fehlermeldung **"Beim Parsen des Pakets ist ein Problem aufgetreten"**.
Die App liess sich nicht installieren.

### Ursache

Der Gateway-Container nutzt **WhiteNoise** mit `CompressedManifestStaticFilesStorage`
fuer statische Dateien. WhiteNoise laedt beim Container-Start **alle statischen
Dateien in den Speicher** und liefert sie von dort aus. Wenn danach eine neue
Datei per `collectstatic` auf die Festplatte geschrieben wird, **merkt WhiteNoise
das nicht** — es liefert weiterhin die alte Version aus dem Speicher-Cache.

### Zeitablauf des Fehlers

```
15:48  — Alte APK wird per collectstatic geschrieben (22.957.107 Bytes)
15:49  — Gateway-Container startet → WhiteNoise cached die ALTE APK
15:57  — Neue APK wird per collectstatic geschrieben (22.957.219 Bytes)
         → Datei auf Festplatte ist NEU, aber WhiteNoise liefert ALT
```

Das Tablet lud also eine APK herunter, die **mit einem anderen Keystore
signiert war** als erwartet (weil es die alte Version war). Android zeigt
das als "Parsing-Fehler" an — eine irrefuehrende Meldung fuer ein
Signatur-Problem.

### Die Loesung

**Nach JEDEM `collectstatic` den Gateway-Container neu starten:**

```bash
docker restart gateway
```

Das zwingt WhiteNoise, alle Dateien neu einzulesen. Danach liefert der
Server die aktuelle APK. Kein Container-Rebuild noetig, nur ein Restart.

### Wie man das Problem erkennt

```bash
# Dateigroesse auf dem Server pruefen:
curl -sI https://klara.services/gateway/static/downloads/perasi.apk | grep content-length

# Lokale Dateigroesse vergleichen:
ls -la build/app/outputs/flutter-apk/app-release.apk

# Wenn die Groessen NICHT uebereinstimmen → docker restart gateway
```

### Warum das nur bei der APK auffaellt

CSS, JS und andere statische Dateien werden von WhiteNoise mit einem
Content-Hash im Dateinamen versioniert (z.B. `perasi.a8e407f8235a.apk`).
Browser fordern die gehashte URL an und bekommen immer die richtige Version.
Die APK wird aber unter dem **ungehashten Namen** `perasi.apk` heruntergeladen
(direkter Download-Link) — und genau dieser ungehashte Pfad wird von
WhiteNoise aus dem Speicher-Cache bedient, ohne die Festplatte zu pruefen.

## Versions-Pflege

Vor jedem Release die Version in `pubspec.yaml` hochziehen:

```yaml
version: 1.2.0+4   # Format: major.minor.patch+buildnumber
```

- **Major** (1.x.x): Grundlegende Aenderungen, inkompatibel
- **Minor** (x.2.x): Neues Feature (z.B. Shared-Tablet-Modus)
- **Patch** (x.x.1): Bugfixes
- **Build-Nummer** (+4): Muss bei jedem Release um 1 steigen, sonst
  lehnt Android das Update ab

## Checkliste vor dem Release

- [ ] `flutter analyze` fehlerfrei
- [ ] Version in `pubspec.yaml` hochgezogen
- [ ] `flutter build apk --release` erfolgreich
- [ ] APK kopiert nach Gateway static/downloads/
- [ ] `docker exec gateway python3 /app/manage.py collectstatic --noinput`
- [ ] `docker restart gateway`
- [ ] `curl -sI` Groesse auf Server = lokale Groesse
- [ ] Auf Tablet installieren und Grundfunktion pruefen
- [ ] Commit + Push im perasi_app Repo
