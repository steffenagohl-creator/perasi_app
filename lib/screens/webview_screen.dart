import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/config.dart';
import '../core/connectivity/connection_monitor.dart';
import 'offline_screen.dart';

/// Haupt-Screen: Zeigt die Klara-Plattform im WebView
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  bool _isOffline = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectionMonitor.start();

    // Auf Verbindungsaenderungen reagieren
    _connectionMonitor.onStatusChange.listen((isOnline) {
      setState(() => _isOffline = !isOnline);
      // Bei Wiederverbindung: WebView neu laden
      if (isOnline && _webViewController != null) {
        _webViewController!.reload();
      }
    });
  }

  @override
  void dispose() {
    _connectionMonitor.dispose();
    super.dispose();
  }

  /// Back-Button: Erst im WebView zurueck, dann App schliessen
  Future<bool> _onWillPop() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      if (canGoBack) {
        _webViewController!.goBack();
        return false; // App NICHT schliessen
      }
    }
    return true; // App schliessen (keine WebView-History mehr)
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

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(AppConfig.gatewayUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  // Cookies persistent speichern (Session bleibt bei App-Neustart)
                  thirdPartyCookiesEnabled: true,
                  // Kamera-Zugriff erlauben (fuer Vision-Modul)
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  supportZoom: false,
                  // User-Agent: App identifizierbar machen
                  userAgent: AppConfig.userAgent,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() => _isLoading = true);
                },
                onLoadStop: (controller, url) {
                  setState(() => _isLoading = false);
                },
                // Kamera/Mikrofon Berechtigung automatisch erteilen
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
              ),
              // Ladebalken oben im WebView
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    color: KlaraColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
