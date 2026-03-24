import 'package:flutter/material.dart';
import '../core/config.dart';

/// Wird angezeigt wenn die App-Version zu alt ist
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

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
              const Icon(
                Icons.system_update,
                size: 80,
                color: KlaraColors.accent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Update erforderlich',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: KlaraColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Bitte aktualisiere die App auf die neueste Version.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Link zum Play Store / App Store oeffnen
                },
                icon: const Icon(Icons.download),
                label: const Text('Zum Store'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KlaraColors.primary,
                  foregroundColor: KlaraColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
