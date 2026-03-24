import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Biometrie-Entsperrung (Fingerabdruck / FaceID).
///
/// Der Mitarbeiter kann in der App einstellen ob er Biometrie nutzen will.
/// Wenn aktiviert UND eine gueltige Session besteht, wird beim App-Start
/// erst Fingerabdruck/FaceID abgefragt bevor der WebView geladen wird.
///
/// Ist Biometrie nicht aktiviert oder nicht verfuegbar, geht es direkt
/// zum WebView (Keycloak-Login falls Session abgelaufen).
class BiometricLock {
  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  // Schluessel im sicheren Speicher
  static const _keyEnabled = 'biometric_enabled';
  static const _keyWasLoggedIn = 'was_logged_in';

  /// Prueft ob Biometrie auf dem Geraet verfuegbar ist
  Future<bool> isDeviceSupported() async {
    final canAuth = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canAuth && isSupported;
  }

  /// Prueft ob der Nutzer Biometrie aktiviert hat UND schon eingeloggt war
  Future<bool> shouldAuthenticate() async {
    final enabled = await _storage.read(key: _keyEnabled);
    final wasLoggedIn = await _storage.read(key: _keyWasLoggedIn);
    final supported = await isDeviceSupported();

    // Nur Biometrie zeigen wenn: aktiviert + schon eingeloggt + Geraet kann es
    return enabled == 'true' && wasLoggedIn == 'true' && supported;
  }

  /// Fuehrt die Biometrie-Abfrage durch (Fingerabdruck / FaceID)
  /// Gibt true zurueck wenn erfolgreich
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Bitte entsperre die Perasi App',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      // Bei Fehler (z.B. zu viele Versuche): nicht blockieren
      return false;
    }
  }

  /// Speichert ob Biometrie aktiviert ist (Einstellung vom Nutzer)
  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _keyEnabled, value: enabled.toString());
  }

  /// Liest ob Biometrie aktiviert ist
  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _keyEnabled);
    return value == 'true';
  }

  /// Markiert dass der Nutzer sich mindestens einmal eingeloggt hat.
  /// Wird nach erfolgreichem Login im WebView aufgerufen (JS-Bridge).
  Future<void> markAsLoggedIn() async {
    await _storage.write(key: _keyWasLoggedIn, value: 'true');
  }
}
