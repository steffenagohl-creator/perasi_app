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
            // Perasi-Logo — dekorativ, fuer Screenreader ausblenden
            ExcludeSemantics(
              child: Image.asset(
                'assets/splash/perasi_logo.png',
                width: 160,
                height: 160,
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
