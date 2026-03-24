import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/auth/biometric_lock.dart';
import '../core/config.dart';
import '../core/connectivity/connection_monitor.dart';
import '../core/push/ntfy_service.dart';
import '../widgets/nfc_floating_button.dart';
import 'nfc_screen.dart';
import 'offline_screen.dart';

/// Haupt-Screen: Zeigt die Klara-Plattform im WebView.
/// Integriert: JS-Bridge, Push-Empfang via ntfy, NFC-Button.
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

  // Login-Daten aus der JS-Bridge
  String? _username;
  String? _clientUsername;

  @override
  void initState() {
    super.initState();

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
      // Deep Link: URL im WebView oeffnen
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
    // Die Web-Seite ruft auf:
    //   window.flutter_inappwebview.callHandler('onUserLogin',
    //     {username: "steffen.gohl", clientUsername: "steffen.gohl"})
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

    // PopScope: Back-Button erst im WebView zurueck, dann App schliessen
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_webViewController != null) {
          final canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return;
          }
        }
        if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // WebView — Screenreader-Inhalte kommen aus der Web-Seite
              Semantics(
                label: 'Klara Plattform',
                hint: 'Webansicht der Klara-Plattform',
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(AppConfig.gatewayUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    // Cookies persistent (Session bleibt bei Neustart)
                    thirdPartyCookiesEnabled: true,
                    // Kamera/Mikrofon erlauben (Vision + Voice)
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    supportZoom: false,
                    // User-Agent: App identifizierbar machen
                    userAgent: AppConfig.userAgent,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    // JS-Handler registrieren BEVOR die Seite laedt
                    _registerJsHandlers(controller);
                  },
                  onLoadStart: (controller, url) {
                    setState(() => _isLoading = true);
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _isLoading = false);
                    // JS-Bridge injizieren nachdem die Seite geladen ist
                    _injectJsBridge();
                    SemanticsService.announce(
                      'Seite geladen',
                      TextDirection.ltr,
                    );
                  },
                  onReceivedError: (controller, request, error) {
                    SemanticsService.announce(
                      'Fehler beim Laden der Seite',
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
}
