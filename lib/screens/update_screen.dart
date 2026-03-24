import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';

/// Wird angezeigt wenn die App-Version zu alt ist
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    // Screenreader informieren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'App-Update erforderlich. Bitte aktualisiere die App.',
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
                label: 'Update verfuegbar',
                child: const Icon(
                  Icons.system_update,
                  size: 80,
                  color: KlaraColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: const Text(
                  'Update erforderlich',
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
                'Bitte aktualisiere die App auf die neueste Version.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Button: Mindestens 48x48dp Touch-Target
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Link zum Play Store / App Store oeffnen
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Zum Store'),
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
