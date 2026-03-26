import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config.dart';

/// Laedt die neueste APK herunter und startet die Android-Installation.
///
/// Ablauf:
/// 1. APK vom Gateway herunterladen (mit Fortschrittsanzeige)
/// 2. Datei im Cache-Ordner speichern
/// 3. Android-Installer oeffnen
class AppUpdater {
  /// Fortschritt als Wert zwischen 0.0 und 1.0 (fuer Fortschrittsbalken)
  final ValueNotifier<double> progress = ValueNotifier(0.0);

  /// Status-Text fuer die Anzeige
  final ValueNotifier<String> status =
      ValueNotifier('Bereit zum Herunterladen');

  /// True solange der Download laeuft
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);

  /// Laedt die APK herunter und oeffnet sie zur Installation
  Future<bool> downloadAndInstall() async {
    isDownloading.value = true;
    progress.value = 0.0;
    status.value = 'Download wird gestartet...';

    try {
      // 1. Streaming-Download starten (damit wir den Fortschritt anzeigen koennen)
      final request = http.Request('GET', Uri.parse(AppConfig.apkDownloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        status.value = 'Download fehlgeschlagen (Fehler ${response.statusCode})';
        isDownloading.value = false;
        return false;
      }

      // 2. Dateigroesse fuer Fortschrittsberechnung
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      // 3. In Cache-Ordner speichern
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/perasi_update.apk');
      final sink = file.openWrite();

      status.value = 'Wird heruntergeladen...';

      // 4. Daten Stueck fuer Stueck schreiben und Fortschritt aktualisieren
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          progress.value = receivedBytes / totalBytes;
          final mb = (receivedBytes / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
          status.value = '$mb / $totalMb MB';
        }
      }

      await sink.close();
      status.value = 'Download abgeschlossen. Installation wird gestartet...';
      progress.value = 1.0;

      // 5. APK mit dem Android-Installer oeffnen
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        status.value = 'Installation konnte nicht gestartet werden: ${result.message}';
        isDownloading.value = false;
        return false;
      }

      isDownloading.value = false;
      return true;
    } catch (e) {
      status.value = 'Fehler beim Download. Bitte erneut versuchen.';
      isDownloading.value = false;
      return false;
    }
  }

  /// Aufraeumen
  void dispose() {
    progress.dispose();
    status.dispose();
    isDownloading.dispose();
  }
}
