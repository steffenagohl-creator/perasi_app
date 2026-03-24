import 'package:flutter/material.dart';
import '../core/config.dart';

/// Schwebender NFC-Button der ueber dem WebView angezeigt wird.
/// Tippt der User darauf, oeffnet sich der NFC-Screen zum Einstempeln.
class NfcFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NfcFloatingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Mindestens 48x48dp Touch-Target (hier 56dp — Standard-FAB-Groesse)
    return Semantics(
      label: 'NFC scannen',
      hint: 'Oeffnet den NFC-Scanner zum Einstempeln',
      button: true,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: KlaraColors.primary,
        foregroundColor: KlaraColors.white,
        tooltip: 'NFC scannen',
        child: const Icon(Icons.nfc, size: 28),
      ),
    );
  }
}
