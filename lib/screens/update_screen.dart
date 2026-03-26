import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/config.dart';
import '../core/version/app_updater.dart';

/// Wird angezeigt wenn die App-Version zu alt ist.
/// Der Nutzer kann das Update direkt herunterladen und installieren.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final AppUpdater _updater = AppUpdater();

  @override
  void initState() {
    super.initState();
    // Screenreader informieren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        'App-Update verfuegbar. Tippe auf Jetzt aktualisieren um das Update herunterzuladen.',
        TextDirection.ltr,
      );
    });
  }

  @override
  void dispose() {
    _updater.dispose();
    super.dispose();
  }

  /// Startet den Download und die Installation
  Future<void> _startUpdate() async {
    SemanticsService.announce(
      'Download wird gestartet',
      TextDirection.ltr,
    );

    final success = await _updater.downloadAndInstall();

    if (success) {
      SemanticsService.announce(
        'Installation wird gestartet. Bitte bestaetigen.',
        TextDirection.ltr,
      );
    } else {
      SemanticsService.announce(
        'Update fehlgeschlagen. Bitte erneut versuchen.',
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
              // Icon
              Semantics(
                label: 'Update verfuegbar',
                child: const Icon(
                  Icons.system_update,
                  size: 80,
                  color: KlaraColors.accent,
                ),
              ),
              const SizedBox(height: 24),

              // Ueberschrift
              Semantics(
                header: true,
                child: const Text(
                  'Update verfuegbar',
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
                'Eine neue Version der Perasi App ist verfuegbar. '
                'Bitte aktualisiere um alle Funktionen nutzen zu koennen.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Fortschrittsanzeige (nur sichtbar waehrend Download)
              ValueListenableBuilder<bool>(
                valueListenable: _updater.isDownloading,
                builder: (context, isDownloading, _) {
                  if (!isDownloading) return const SizedBox.shrink();

                  return Column(
                    children: [
                      // Fortschrittsbalken
                      ValueListenableBuilder<double>(
                        valueListenable: _updater.progress,
                        builder: (context, progress, _) {
                          return Semantics(
                            label:
                                'Download-Fortschritt: ${(progress * 100).toInt()} Prozent',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                color: KlaraColors.primary,
                                backgroundColor:
                                    KlaraColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Status-Text (z.B. "5.2 / 22.0 MB")
                      ValueListenableBuilder<String>(
                        valueListenable: _updater.status,
                        builder: (context, status, _) {
                          return Semantics(
                            liveRegion: true,
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // Download-Button (nur wenn NICHT gerade heruntergeladen wird)
              ValueListenableBuilder<bool>(
                valueListenable: _updater.isDownloading,
                builder: (context, isDownloading, _) {
                  return SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isDownloading ? null : _startUpdate,
                      icon: Icon(
                        isDownloading ? Icons.hourglass_top : Icons.download,
                      ),
                      label: Text(
                        isDownloading
                            ? 'Wird heruntergeladen...'
                            : 'Jetzt aktualisieren',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KlaraColors.primary,
                        foregroundColor: KlaraColors.white,
                        disabledBackgroundColor:
                            KlaraColors.primary.withValues(alpha: 0.5),
                        disabledForegroundColor:
                            KlaraColors.white.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Fehler-Status anzeigen (wenn Download fehlgeschlagen)
              ValueListenableBuilder<bool>(
                valueListenable: _updater.isDownloading,
                builder: (context, isDownloading, _) {
                  if (isDownloading) return const SizedBox.shrink();

                  return ValueListenableBuilder<String>(
                    valueListenable: _updater.status,
                    builder: (context, status, _) {
                      // Nur Fehlermeldungen anzeigen, nicht den Anfangsstatus
                      if (status == 'Bereit zum Herunterladen') {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 14,
                            color: status.contains('Fehler') ||
                                    status.contains('fehlgeschlagen')
                                ? KlaraColors.danger
                                : KlaraColors.success,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
