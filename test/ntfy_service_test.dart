import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

/// Tests fuer die ntfy-Nachrichten-Verarbeitung.
/// Die WebSocket-Verbindung koennen wir in Unit-Tests nicht aufbauen,
/// aber die Nachrichten-Verarbeitung laesst sich testen.

/// Simuliert die Verarbeitung einer ntfy-Nachricht
Map<String, String>? parseNtfyMessage(String rawMessage) {
  try {
    final data = jsonDecode(rawMessage) as Map<String, dynamic>;
    if (data['event'] != 'message') return null;

    return {
      'title': data['title'] as String? ?? 'Klara',
      'body': data['message'] as String? ?? '',
      if (data['click'] != null) 'click': data['click'] as String,
    };
  } catch (_) {
    return null;
  }
}

void main() {
  group('ntfy Nachrichten-Verarbeitung', () {
    test('normale Nachricht wird korrekt geparst', () {
      final msg = jsonEncode({
        'event': 'message',
        'title': 'Eingestempelt',
        'message': 'Frank wurde um 08:30 eingestempelt',
      });

      final result = parseNtfyMessage(msg);
      expect(result, isNotNull);
      expect(result!['title'], 'Eingestempelt');
      expect(result['body'], 'Frank wurde um 08:30 eingestempelt');
    });

    test('Nachricht mit Deep Link', () {
      final msg = jsonEncode({
        'event': 'message',
        'title': 'Neuer Dienstplan',
        'message': 'Der Dienstplan fuer April ist da',
        'click': '/roster/',
      });

      final result = parseNtfyMessage(msg);
      expect(result, isNotNull);
      expect(result!['click'], '/roster/');
    });

    test('keepalive Event wird ignoriert', () {
      final msg = jsonEncode({'event': 'keepalive'});
      expect(parseNtfyMessage(msg), isNull);
    });

    test('open Event wird ignoriert', () {
      final msg = jsonEncode({'event': 'open'});
      expect(parseNtfyMessage(msg), isNull);
    });

    test('Nachricht ohne Titel bekommt Standard-Titel', () {
      final msg = jsonEncode({
        'event': 'message',
        'message': 'Testbenachrichtigung',
      });

      final result = parseNtfyMessage(msg);
      expect(result, isNotNull);
      expect(result!['title'], 'Klara');
    });

    test('ungueltiges JSON gibt null zurueck', () {
      expect(parseNtfyMessage('kein json'), isNull);
      expect(parseNtfyMessage(''), isNull);
    });
  });
}
