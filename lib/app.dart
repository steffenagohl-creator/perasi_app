import 'package:flutter/material.dart';
import 'core/auth/biometric_lock.dart';
import 'core/config.dart';
import 'core/connectivity/connection_monitor.dart';
import 'core/version/version_check.dart';
import 'screens/biometric_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/offline_screen.dart';
import 'screens/update_screen.dart';
import 'screens/webview_screen.dart';

/// Haupt-App mit dem Start-Ablauf:
/// Splash → Internet pruefen → Version pruefen → Biometrie → WebView laden
class KlaraApp extends StatefulWidget {
  const KlaraApp({super.key});

  @override
  State<KlaraApp> createState() => _KlaraAppState();
}

class _KlaraAppState extends State<KlaraApp> {
  // Welcher Screen wird gerade angezeigt?
  _AppState _state = _AppState.splash;
  final BiometricLock _biometricLock = BiometricLock();

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  /// Start-Ablauf gemaess Plan:
  /// 1. Splash anzeigen
  /// 2. Internet pruefen → Offline-Screen wenn noetig
  /// 3. Versions-Check → Update-Screen wenn veraltet
  /// 4. Biometrie-Check (wenn aktiviert + Session gueltig)
  /// 5. WebView laden
  Future<void> _startApp() async {
    setState(() => _state = _AppState.splash);

    // Schritt 2: Internet pruefen
    final monitor = ConnectionMonitor();
    final isOnline = await monitor.checkConnection();
    monitor.dispose();

    if (!isOnline) {
      setState(() => _state = _AppState.offline);
      return;
    }

    // Schritt 3: Versions-Check
    final isUpToDate = await VersionCheck.isUpToDate();
    if (!isUpToDate) {
      setState(() => _state = _AppState.updateRequired);
      return;
    }

    // Schritt 4: Biometrie (wenn aktiviert + schon eingeloggt)
    final shouldAuth = await _biometricLock.shouldAuthenticate();
    if (shouldAuth) {
      setState(() => _state = _AppState.biometric);
      return;
    }

    // Schritt 5: Alles OK → WebView laden
    setState(() => _state = _AppState.webview);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perasi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: KlaraColors.primary,
          primary: KlaraColors.primary,
        ),
        useMaterial3: true,
      ),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_state) {
      case _AppState.splash:
        return const SplashScreen();
      case _AppState.offline:
        return OfflineScreen(onRetry: _startApp);
      case _AppState.updateRequired:
        return const UpdateScreen();
      case _AppState.biometric:
        return BiometricScreen(
          // Erfolg → WebView laden
          onSuccess: () => setState(() => _state = _AppState.webview),
          // Ueberspringen → trotzdem zum WebView (Login im Browser)
          onSkip: () => setState(() => _state = _AppState.webview),
        );
      case _AppState.webview:
        return const WebViewScreen();
    }
  }
}

enum _AppState {
  splash,
  offline,
  updateRequired,
  biometric,
  webview,
}
