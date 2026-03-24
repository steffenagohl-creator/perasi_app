import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config.dart';

/// Verbindet sich per WebSocket mit dem ntfy-Server und zeigt
/// eingehende Push-Nachrichten als lokale Benachrichtigungen an.
///
/// Jeder User bekommt ein eigenes Topic: user_{username}
/// Der ntfy-Server laeuft Self-Hosted auf klara.services (kein Firebase).
class NtfyService {
  WebSocket? _ws;
  Timer? _reconnectTimer;
  String? _currentTopic;
  bool _shouldReconnect = true;

  // Lokale Benachrichtigungen
  final _notifications = FlutterLocalNotificationsPlugin();

  // Callback wenn eine Benachrichtigung angetippt wird (Deep Link)
  final void Function(String? payload)? onNotificationTap;

  NtfyService({this.onNotificationTap});

  /// Initialisiert die lokalen Benachrichtigungen (einmal beim App-Start)
  Future<void> init() async {
    // Android-Kanal fuer Benachrichtigungen
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        // Benachrichtigung angetippt → Deep Link verarbeiten
        onNotificationTap?.call(response.payload);
      },
    );
  }

  /// Verbindet sich mit dem ntfy-Topic fuer einen bestimmten User
  Future<void> connect(String username) async {
    _currentTopic = 'user_$username';
    _shouldReconnect = true;
    await _connectWebSocket();
  }

  /// Stellt die WebSocket-Verbindung her
  Future<void> _connectWebSocket() async {
    if (_currentTopic == null) return;

    try {
      // ntfy WebSocket URL: wss://klara.services/ntfy/user_xxx/ws
      final wsUrl = AppConfig.ntfyBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final url = '$wsUrl/$_currentTopic/ws';

      _ws = await WebSocket.connect(url);

      _ws!.listen(
        (message) => _handleMessage(message),
        onDone: () => _handleDisconnect(),
        onError: (_) => _handleDisconnect(),
      );

      // Reconnect-Timer zuruecksetzen bei erfolgreicher Verbindung
      _reconnectTimer?.cancel();
    } catch (_) {
      _handleDisconnect();
    }
  }

  /// Verarbeitet eine eingehende ntfy-Nachricht
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // ntfy sendet verschiedene Event-Typen, nur "message" ist relevant
      if (data['event'] != 'message') return;

      final title = data['title'] as String? ?? 'Klara';
      final body = data['message'] as String? ?? '';
      // Optional: URL fuer Deep Link (z.B. /time-tracking/)
      final url = data['click'] as String?;

      _showNotification(title, body, url);
    } catch (_) {
      // Ungueltige Nachricht ignorieren
    }
  }

  /// Zeigt eine lokale Benachrichtigung an
  Future<void> _showNotification(
    String title,
    String body,
    String? deepLink,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'klara_push',
      'Klara Benachrichtigungen',
      channelDescription: 'Benachrichtigungen von der Klara-Plattform',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _notifications.show(
      // Eindeutige ID basierend auf Zeitstempel
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      // Deep Link als Payload mitgeben (z.B. "/time-tracking/")
      payload: deepLink,
    );
  }

  /// Bei Verbindungsabbruch: nach 5 Sekunden erneut verbinden
  void _handleDisconnect() {
    _ws = null;
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connectWebSocket();
    });
  }

  /// Trennt die Verbindung zum ntfy-Server
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
    _currentTopic = null;
  }
}
