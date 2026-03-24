import 'package:flutter_test/flutter_test.dart';

/// Tests fuer die NFC-UID-Extraktion.
/// Der echte NFC-Manager braucht ein Geraet, aber die UID-Extraktion
/// aus den Tag-Daten koennen wir testen.

/// Simuliert die UID-Extraktion aus NFC-Tag-Daten
String? extractUid(Map<String, dynamic> tagData) {
  // NfcA (Android) — die meisten RFID-Schluesselanhaenger
  final nfcA = tagData['nfca'] as Map<String, dynamic>?;
  if (nfcA != null) {
    final identifier = nfcA['identifier'] as List<dynamic>?;
    if (identifier != null) {
      return identifier
          .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
    }
  }

  // MiFare (iOS)
  final miFare = tagData['mifare'] as Map<String, dynamic>?;
  if (miFare != null) {
    final identifier = miFare['identifier'] as List<dynamic>?;
    if (identifier != null) {
      return identifier
          .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
    }
  }

  return null;
}

void main() {
  group('NFC UID-Extraktion', () {
    test('NfcA Tag (Android)', () {
      final tagData = {
        'nfca': {
          'identifier': [0x04, 0xA3, 0x2B, 0x1C, 0x7D, 0x00, 0x80],
        },
      };
      expect(extractUid(tagData), '04A32B1C7D0080');
    });

    test('MiFare Tag (iOS)', () {
      final tagData = {
        'mifare': {
          'identifier': [0xAB, 0xCD, 0xEF, 0x12],
        },
      };
      expect(extractUid(tagData), 'ABCDEF12');
    });

    test('Tag ohne erkennbare UID', () {
      final tagData = {'ndef': {}};
      expect(extractUid(tagData), isNull);
    });

    test('leere Tag-Daten', () {
      expect(extractUid({}), isNull);
    });

    test('UID mit fuehrenden Nullen wird korrekt formatiert', () {
      final tagData = {
        'nfca': {
          'identifier': [0x00, 0x01, 0x0A, 0xFF],
        },
      };
      expect(extractUid(tagData), '00010AFF');
    });
  });
}
