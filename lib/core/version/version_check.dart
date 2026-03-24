import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

/// Prueft ob die installierte App-Version noch aktuell genug ist
class VersionCheck {
  /// Gibt true zurueck wenn die App aktuell genug ist
  static Future<bool> isUpToDate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final installedVersion = info.version;

      final response = await http
          .get(Uri.parse(AppConfig.versionCheckUrl))
          .timeout(const Duration(seconds: 5));

      // Im Zweifel durchlassen (Server nicht erreichbar = kein Blocker)
      if (response.statusCode != 200) return true;

      final data = jsonDecode(response.body);
      final minVersion = data['min_version'] as String?;

      if (minVersion == null) return true;

      return _compareVersions(installedVersion, minVersion) >= 0;
    } catch (_) {
      // Bei Fehler: App durchlassen, nicht blockieren
      return true;
    }
  }

  /// Vergleicht zwei Versionen (z.B. "1.2.3" vs "1.1.0")
  /// Gibt positiv zurueck wenn a > b, 0 wenn gleich, negativ wenn a < b
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }
}
