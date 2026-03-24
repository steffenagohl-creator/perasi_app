import 'package:flutter_test/flutter_test.dart';

/// Tests fuer den Versions-Vergleich.
/// Die _compareVersions Methode ist privat, daher testen wir die Logik
/// hier als eigenstaendige Funktion mit der gleichen Implementierung.
int compareVersions(String a, String b) {
  final partsA = a.split('.').map(int.parse).toList();
  final partsB = b.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

void main() {
  group('Versions-Vergleich', () {
    test('gleiche Versionen', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('2.3.4', '2.3.4'), 0);
    });

    test('installierte Version ist neuer', () {
      expect(compareVersions('1.1.0', '1.0.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    });

    test('installierte Version ist aelter', () {
      expect(compareVersions('1.0.0', '1.1.0'), lessThan(0));
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('Major-Version hat Vorrang', () {
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });
  });
}
