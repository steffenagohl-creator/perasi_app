import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';
import '../core/nfc/nfc_service.dart';

/// Nativer NFC-Screen zum Einstempeln per Handy-NFC.
/// Ablauf: Chip scannen → UID an Backend senden → Ergebnis zeigen → zurueck
class NfcScreen extends StatefulWidget {
  final String clientUsername;

  const NfcScreen({super.key, required this.clientUsername});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

enum _NfcState { ready, scanning, success, error }

class _NfcScreenState extends State<NfcScreen> {
  final NfcService _nfcService = NfcService();
  _NfcState _state = _NfcState.ready;
  String _message = '';
  bool _nfcAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  /// Prueft ob NFC verfuegbar ist
  Future<void> _checkNfc() async {
    final available = await _nfcService.isAvailable();
    if (!available && mounted) {
      setState(() {
        _nfcAvailable = false;
        _state = _NfcState.error;
        _message = 'NFC ist auf diesem Geraet nicht verfuegbar.';
      });
      SemanticsService.announce(_message, TextDirection.ltr);
    }
  }

  /// Startet den NFC-Scan
  Future<void> _startScan() async {
    setState(() {
      _state = _NfcState.scanning;
      _message = 'Halte dein Handy an den NFC-Chip...';
    });
    SemanticsService.announce(_message, TextDirection.ltr);

    await _nfcService.startScan(
      onChipRead: (chipUid) async {
        // Chip erkannt → an Backend senden
        setState(() => _message = 'Chip erkannt. Wird verarbeitet...');
        SemanticsService.announce('Chip erkannt', TextDirection.ltr);

        final result = await _nfcService.checkin(
          chipUid: chipUid,
          clientUsername: widget.clientUsername,
        );

        if (!mounted) return;

        setState(() {
          _state = result.success ? _NfcState.success : _NfcState.error;
          _message = result.message;
        });
        SemanticsService.announce(result.message, TextDirection.ltr);

        // Nach 3 Sekunden automatisch zurueck zum WebView
        if (result.success) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _state = _NfcState.error;
          _message = error;
        });
        SemanticsService.announce(error, TextDirection.ltr);
      },
    );
  }

  @override
  void dispose() {
    _nfcService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KlaraColors.white,
      appBar: AppBar(
        backgroundColor: KlaraColors.primary,
        foregroundColor: KlaraColors.white,
        title: Semantics(
          header: true,
          child: const Text('NFC Einstempeln'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurueck zur Startseite',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status-Icon
              _buildStatusIcon(),
              const SizedBox(height: 32),
              // Status-Text
              Text(
                _message.isEmpty ? 'Bereit zum Scannen' : _message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _state == _NfcState.success
                      ? KlaraColors.success
                      : _state == _NfcState.error
                          ? KlaraColors.danger
                          : KlaraColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Scan-Button oder Erneut-Button
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Zeigt das passende Icon je nach Status
  Widget _buildStatusIcon() {
    IconData icon;
    Color color;
    String label;

    switch (_state) {
      case _NfcState.ready:
        icon = Icons.nfc;
        color = KlaraColors.primary;
        label = 'NFC bereit';
      case _NfcState.scanning:
        icon = Icons.contactless;
        color = KlaraColors.accent;
        label = 'NFC wird gescannt';
      case _NfcState.success:
        icon = Icons.check_circle;
        color = KlaraColors.success;
        label = 'Erfolgreich eingestempelt';
      case _NfcState.error:
        icon = Icons.error;
        color = KlaraColors.danger;
        label = 'Fehler beim Scannen';
    }

    return Semantics(
      label: label,
      child: Icon(icon, size: 100, color: color),
    );
  }

  /// Zeigt den passenden Button je nach Status
  Widget _buildActionButton() {
    // Beim Scannen: kein Button (warten auf Chip)
    if (_state == _NfcState.scanning) {
      return Semantics(
        label: 'Scanne. Bitte warten.',
        child: const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(color: KlaraColors.primary),
        ),
      );
    }

    // Nach Erfolg: zurueck-Button
    if (_state == _NfcState.success) {
      return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Zurueck'),
          style: ElevatedButton.styleFrom(
            backgroundColor: KlaraColors.primary,
            foregroundColor: KlaraColors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      );
    }

    // Bereit oder Fehler: Scan-Button (falls NFC verfuegbar)
    if (!_nfcAvailable) {
      return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Zurueck'),
          style: ElevatedButton.styleFrom(
            backgroundColor: KlaraColors.primary,
            foregroundColor: KlaraColors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      width: 200,
      child: ElevatedButton.icon(
        onPressed: _startScan,
        icon: const Icon(Icons.nfc, size: 28),
        label: const Text(
          'Chip scannen',
          style: TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: KlaraColors.primary,
          foregroundColor: KlaraColors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}
