import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Liest Session-Cookies aus dem WebView aus, damit native API-Calls
/// (z.B. NFC-Einstempeln) die Keycloak-Session mitschicken koennen.
///
/// Problem: Wenn die App einen HTTP-Call direkt macht (nicht ueber WebView),
/// hat dieser Call keine Cookies. Die CookieBridge loest das.
class CookieBridge {
  final CookieManager _cookieManager = CookieManager.instance();

  /// Liest alle Cookies fuer klara.services aus dem WebView
  Future<Map<String, String>> getSessionCookies() async {
    final cookies = await _cookieManager.getCookies(
      url: WebUri('https://klara.services'),
    );
    return {for (var c in cookies) c.name: c.value};
  }

  /// Gibt den Cookie-Header-String fuer native HTTP-Calls zurueck
  /// Format: "session_tracking=abc123; csrftoken=xyz789"
  Future<String> getCookieHeader() async {
    final cookies = await getSessionCookies();
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Liest ein bestimmtes Cookie aus (z.B. "csrftoken")
  Future<String?> getCookie(String name) async {
    final cookies = await getSessionCookies();
    return cookies[name];
  }
}
