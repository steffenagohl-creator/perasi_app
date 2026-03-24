import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';
import '../core/auth/biometric_lock.dart';

/// Biometrie-Entsperr-Screen.
/// Zeigt einen Fingerabdruck-Button und fragt Biometrie ab.
/// Bei Erfolg → onSuccess (WebView laden)
/// Bei Abbruch/Fehler → onSkip (trotzdem zum WebView, Keycloak-Login)
class BiometricScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;

  const BiometricScreen({
    super.key,
    required this.onSuccess,
    required this.onSkip,
  });

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  final BiometricLock _biometricLock = BiometricLock();
  bool _isAuthenticating = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    // Automatisch Biometrie starten beim Oeffnen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'Biometrie-Entsperrung. Bitte Fingerabdruck oder Gesicht scannen.',
        TextDirection.ltr,
      );
      _authenticate();
    });
  }

  /// Fuehrt die Biometrie-Abfrage durch
  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _statusText = 'Bitte entsperren...';
    });

    final success = await _biometricLock.authenticate();

    if (!mounted) return;

    if (success) {
      SemanticsService.announce('Entsperrt', TextDirection.ltr);
      widget.onSuccess();
    } else {
      setState(() {
        _isAuthenticating = false;
        _statusText = 'Entsperrung fehlgeschlagen';
      });
      SemanticsService.announce(
        'Entsperrung fehlgeschlagen. Erneut versuchen oder ueberspringen.',
        TextDirection.ltr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KlaraColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fingerabdruck-Icon
              Semantics(
                label: 'Biometrie-Entsperrung',
                child: Icon(
                  Icons.fingerprint,
                  size: 100,
                  color: _isAuthenticating
                      ? KlaraColors.accent
                      : KlaraColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: const Text(
                  'App entsperren',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: KlaraColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusText.isEmpty
                    ? 'Nutze deinen Fingerabdruck oder dein Gesicht'
                    : _statusText,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Erneut versuchen (nur wenn nicht gerade laeuft)
              if (!_isAuthenticating) ...[
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Erneut versuchen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KlaraColors.primary,
                      foregroundColor: KlaraColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Ueberspringen — geht direkt zum WebView (Keycloak-Login)
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    child: const Text(
                      'Ueberspringen',
                      style: TextStyle(
                        fontSize: 16,
                        color: KlaraColors.textDark,
                      ),
                    ),
                  ),
                ),
              ],
              // Ladeindikator waehrend der Abfrage
              if (_isAuthenticating)
                Semantics(
                  label: 'Biometrie wird geprueft',
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: KlaraColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
