import 'package:flutter_test/flutter_test.dart';

/// Tests fuer die Cookie-Formatierung.
/// Die CookieBridge nutzt intern den CookieManager von InAppWebView,
/// den wir in Unit-Tests nicht aufrufen koennen. Daher testen wir
/// die Formatierungslogik separat.

String formatCookieHeader(Map<String, String> cookies) {
  return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

void main() {
  group('Cookie-Header Formatierung', () {
    test('leere Cookies', () {
      expect(formatCookieHeader({}), '');
    });

    test('ein Cookie', () {
      expect(
        formatCookieHeader({'session_tracking': 'abc123'}),
        'session_tracking=abc123',
      );
    });

    test('mehrere Cookies', () {
      final header = formatCookieHeader({
        'session_tracking': 'abc123',
        'csrftoken': 'xyz789',
        'gw_session': 'def456',
      });
      expect(header, contains('session_tracking=abc123'));
      expect(header, contains('csrftoken=xyz789'));
      expect(header, contains('gw_session=def456'));
      // Cookies durch "; " getrennt
      expect(header.split('; ').length, 3);
    });
  });
}
