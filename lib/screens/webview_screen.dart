import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/auth/biometric_lock.dart';
import '../core/config.dart';
import '../core/connectivity/connection_monitor.dart';
import '../core/push/ntfy_service.dart';
import '../widgets/nfc_floating_button.dart';
import 'nfc_screen.dart';
import 'offline_screen.dart';

/// Haupt-Screen: Zeigt die Klara-Plattform im WebView.
/// Integriert: JS-Bridge, Push-Empfang via ntfy, NFC-Button,
/// Pull-to-Refresh, Datei-Upload, Fehlerseiten, Doppeltipp-Schliessen.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  final BiometricLock _biometricLock = BiometricLock();
  late final NtfyService _ntfyService;
  bool _isOffline = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Login-Daten aus der JS-Bridge
  String? _username;
  String? _clientUsername;

  // Doppeltipp zum Schliessen (Android Back-Button)
  DateTime? _lastBackPress;

  // Pull-to-Refresh Controller
  PullToRefreshController? _pullToRefreshController;

  @override
  void initState() {
    super.initState();

    // Pull-to-Refresh einrichten
    // distanceToTriggerSync hoeher setzen damit es nicht versehentlich
    // beim normalen Scrollen ausloest
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: KlaraColors.primary,
        distanceToTriggerSync: 150,
      ),
      onRefresh: () async {
        _webViewController?.reload();
      },
    );

    // Push-Service initialisieren
    _ntfyService = NtfyService(
      onNotificationTap: _handleNotificationTap,
    );
    _ntfyService.init();

    // Verbindungsueberwachung starten
    _connectionMonitor.start();
    _connectionMonitor.onStatusChange.listen((isOnline) {
      setState(() => _isOffline = !isOnline);
      if (isOnline && _webViewController != null) {
        _webViewController!.reload();
        SemanticsService.announce(
          'Verbindung wiederhergestellt. Seite wird neu geladen.',
          TextDirection.ltr,
        );
      }
      if (!isOnline) {
        SemanticsService.announce(
          'Verbindung verloren.',
          TextDirection.ltr,
        );
      }
    });
  }

  @override
  void dispose() {
    _connectionMonitor.dispose();
    _ntfyService.disconnect();
    super.dispose();
  }

  /// Wird aufgerufen wenn der User eine Push-Benachrichtigung antippt.
  /// payload kann eine URL sein (z.B. "/time-tracking/") die im WebView
  /// geoeffnet wird (Deep Link).
  void _handleNotificationTap(String? payload) {
    if (payload != null && _webViewController != null) {
      final url = payload.startsWith('http')
          ? payload
          : '${AppConfig.baseUrl}$payload';
      _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  /// Injiziert das window.KlaraApp Objekt in den WebView
  void _injectJsBridge() {
    _webViewController?.evaluateJavascript(source: '''
      window.KlaraApp = {
        isNativeApp: true,
        appVersion: "${AppConfig.appVersion}",
        username: "",
        clientUsername: "",
      };
    ''');
  }

  /// Registriert die JS-Handler die der WebView aufrufen kann
  void _registerJsHandlers(InAppWebViewController controller) {
    // Handler: Login-Daten vom WebView empfangen
    controller.addJavaScriptHandler(
      handlerName: 'onUserLogin',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = args[0] as Map;
          setState(() {
            _username = data['username'] as String?;
            _clientUsername = data['clientUsername'] as String?;
          });

          // Merken dass User eingeloggt war (fuer Biometrie beim naechsten Start)
          _biometricLock.markAsLoggedIn();

          // Push-Empfang starten sobald der Username bekannt ist
          if (_username != null) {
            _ntfyService.connect(_username!);
          }
        }
      },
    );

    // Handler: Web-Seite kann NFC-Screen oeffnen
    controller.addJavaScriptHandler(
      handlerName: 'requestNfcScan',
      callback: (args) {
        _openNfcScreen();
      },
    );
  }

  /// Oeffnet den nativen NFC-Screen
  void _openNfcScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NfcScreen(
          clientUsername: _clientUsername ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Offline? Dann Offline-Screen zeigen
    if (_isOffline) {
      return OfflineScreen(
        onRetry: () async {
          final online = await _connectionMonitor.checkConnection();
          if (online) {
            setState(() => _isOffline = false);
          }
        },
      );
    }

    // PopScope: Back-Button erst im WebView zurueck, dann Doppeltipp zum Schliessen
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Erst im WebView zurueck navigieren
        if (_webViewController != null) {
          final canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return;
          }
        }

        // Keine WebView-History mehr → Doppeltipp zum Schliessen
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          // Zweiter Tipp innerhalb 2 Sekunden → App schliessen
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nochmal druecken zum Schliessen'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Fehlerseite anzeigen (404, 500, etc.)
              if (_hasError)
                _buildErrorScreen()
              else
                // WebView — Screenreader-Inhalte kommen aus der Web-Seite
                Semantics(
                  label: 'Klara Plattform',
                  hint: 'Webansicht der Klara-Plattform',
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(AppConfig.gatewayUrl),
                    ),
                    pullToRefreshController: _pullToRefreshController,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      // Cookies persistent (Session bleibt bei Neustart)
                      thirdPartyCookiesEnabled: true,
                      // Kamera/Mikrofon erlauben (Vision + Voice)
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      // Datei-Upload erlauben (Fotos, Dokumente)
                      allowFileAccessFromFileURLs: true,
                      allowUniversalAccessFromFileURLs: true,
                      supportZoom: false,
                      // User-Agent: App identifizierbar machen
                      userAgent: AppConfig.userAgent,

                      // --- Scroll-Performance optimieren ---
                      // Texture-basiertes Rendering statt Hybrid Composition
                      // (deutlich fluessigeres Scrollen auf Android)
                      useHybridComposition: false,
                      // Hardware-Beschleunigung an (schnelleres Rendering)
                      hardwareAcceleration: true,
                      // Overscroll-Effekt deaktivieren (weniger Touch-Konflikte)
                      overScrollMode: OverScrollMode.NEVER,
                      // Algorithmus fuer schnelleres Touch-Scrolling
                      algorithmicDarkeningAllowed: false,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      // JS-Handler registrieren BEVOR die Seite laedt
                      _registerJsHandlers(controller);
                    },
                    onLoadStart: (controller, url) {
                      // Nur setState wenn sich der Zustand wirklich aendert
                      // (vermeidet unnoetige Rebuilds waehrend des Scrollens)
                      if (!_isLoading || _hasError) {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                      }
                    },
                    onLoadStop: (controller, url) {
                      if (_isLoading) {
                        setState(() => _isLoading = false);
                      }
                      _pullToRefreshController?.endRefreshing();
                      // JS-Bridge injizieren nachdem die Seite geladen ist
                      _injectJsBridge();
                      SemanticsService.announce(
                        'Seite geladen',
                        TextDirection.ltr,
                      );
                    },
                    onReceivedHttpError: (controller, request, response) {
                      // Nur Fehler der Hauptseite abfangen, nicht von
                      // Sub-Ressourcen (Bilder, API-Calls, Fonts etc.)
                      if (request.isForMainFrame != true) return;
                      final statusCode = response.statusCode ?? 0;
                      if (statusCode >= 400) {
                        setState(() {
                          _hasError = true;
                          _isLoading = false;
                          _errorMessage = statusCode >= 500
                              ? 'Server-Fehler ($statusCode). Bitte spaeter erneut versuchen.'
                              : 'Seite nicht gefunden ($statusCode).';
                        });
                        SemanticsService.announce(
                          _errorMessage,
                          TextDirection.ltr,
                        );
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      _pullToRefreshController?.endRefreshing();
                      setState(() {
                        _hasError = true;
                        _isLoading = false;
                        _errorMessage =
                            'Fehler beim Laden der Seite. Bitte erneut versuchen.';
                      });
                      SemanticsService.announce(
                        _errorMessage,
                        TextDirection.ltr,
                      );
                    },
                    // Kamera/Mikrofon Berechtigung automatisch erteilen
                    onPermissionRequest: (controller, request) async {
                      return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT,
                      );
                    },
                  ),
                ),
              // Ladebalken oben
              if (_isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Semantics(
                    label: 'Seite wird geladen',
                    child: const LinearProgressIndicator(
                      color: KlaraColors.primary,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // NFC-Button unten rechts (schwebt ueber dem WebView)
        floatingActionButton: NfcFloatingButton(
          onPressed: _openNfcScreen,
        ),
      ),
    );
  }

  /// Freundliche Fehlerseite statt nackter 404/500
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Fehler',
              child: const Icon(
                Icons.error_outline,
                size: 80,
                color: KlaraColors.danger,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: const Text(
                'Etwas ist schiefgelaufen',
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
              _errorMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _hasError = false);
                  _webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(AppConfig.gatewayUrl),
                    ),
                  );
                },
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
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () {
                  setState(() => _hasError = false);
                  _webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(AppConfig.gatewayUrl),
                    ),
                  );
                },
                child: const Text(
                  'Zurueck zur Startseite',
                  style: TextStyle(
                    fontSize: 16,
                    color: KlaraColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
