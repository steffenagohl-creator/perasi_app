import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klara_app/screens/splash_screen.dart';
import 'package:klara_app/screens/offline_screen.dart';
import 'package:klara_app/screens/update_screen.dart';

void main() {
  group('Splash-Screen', () {
    testWidgets('zeigt Perasi-Text und Ladebalken', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );

      expect(find.text('Perasi'), findsOneWidget);
      expect(find.text('Wird geladen...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('zeigt benutzerdefinierten Status-Text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(statusText: 'Verbindung wird geprueft...'),
        ),
      );

      expect(find.text('Verbindung wird geprueft...'), findsOneWidget);
    });
  });

  group('Offline-Screen', () {
    testWidgets('zeigt Fehlermeldung und Erneut-Button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineScreen(onRetry: () {}),
        ),
      );

      expect(find.text('Keine Internetverbindung'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('Erneut-Button ruft onRetry auf', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineScreen(onRetry: () => retryCalled = true),
        ),
      );

      await tester.tap(find.text('Erneut versuchen'));
      expect(retryCalled, isTrue);
    });
  });

  group('Update-Screen', () {
    testWidgets('zeigt Update-Meldung und Store-Button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UpdateScreen()),
      );

      expect(find.text('Update erforderlich'), findsOneWidget);
      expect(find.text('Zum Store'), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });
  });
}
