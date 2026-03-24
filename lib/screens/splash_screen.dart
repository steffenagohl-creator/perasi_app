import 'package:flutter/material.dart';
import '../core/config.dart';

/// Ladebildschirm beim App-Start — zeigt Perasi-Logo und Ladebalken
class SplashScreen extends StatelessWidget {
  final String statusText;

  const SplashScreen({
    super.key,
    this.statusText = 'Wird geladen...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KlaraColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Platzhalter-Logo (wird spaeter durch echtes Perasi-Logo ersetzt)
            Container(
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
            const SizedBox(height: 24),
            const Text(
              'Perasi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: KlaraColors.textDark,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                color: KlaraColors.primary,
                backgroundColor: Color(0xFFE0E0E0),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: const TextStyle(
                color: KlaraColors.textDark,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
