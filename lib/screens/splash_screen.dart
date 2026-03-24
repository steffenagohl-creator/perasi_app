import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';

/// Ladebildschirm beim App-Start — zeigt Perasi-Logo und Ladebalken
class SplashScreen extends StatefulWidget {
  final String statusText;

  const SplashScreen({
    super.key,
    this.statusText = 'Wird geladen...',
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Screenreader informieren, dass die App laedt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'Perasi wird geladen. Bitte warten.',
        TextDirection.ltr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KlaraColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Platzhalter-Logo (wird spaeter durch echtes Perasi-Logo ersetzt)
            // Dekorativ — fuer Screenreader ausblenden
            ExcludeSemantics(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: KlaraColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: KlaraColors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // App-Name — Screenreader liest "Perasi App"
            Semantics(
              header: true,
              label: 'Perasi App',
              child: const Text(
                'Perasi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: KlaraColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Ladebalken
            Semantics(
              label: 'Ladevorgang',
              value: widget.statusText,
              child: const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  color: KlaraColors.primary,
                  backgroundColor: Color(0xFFE0E0E0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Status-Text (z.B. "Wird geladen...")
            ExcludeSemantics(
              // Wird schon oben im Semantics-Label des Ladebalkens vorgelesen
              child: Text(
                widget.statusText,
                style: const TextStyle(
                  color: KlaraColors.textDark,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
