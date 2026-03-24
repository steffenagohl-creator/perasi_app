import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';

/// Wird angezeigt wenn keine Internetverbindung besteht
class OfflineScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const OfflineScreen({super.key, required this.onRetry});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  @override
  void initState() {
    super.initState();
    // Screenreader informieren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'Keine Internetverbindung. Bitte Verbindung pruefen.',
        TextDirection.ltr,
      );
    });
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
              // Icon — dekorativ, Text darunter reicht fuer Screenreader
              Semantics(
                label: 'Kein Internet',
                child: const Icon(
                  Icons.wifi_off,
                  size: 80,
                  color: KlaraColors.danger,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: const Text(
                  'Keine Internetverbindung',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: KlaraColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bitte pruefe deine Verbindung und versuche es erneut.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Button: Mindestens 48x48dp Touch-Target
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KlaraColors.primary,
                    foregroundColor: KlaraColors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
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
