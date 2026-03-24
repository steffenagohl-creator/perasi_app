import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Ueberwacht die Internetverbindung und prueft ob klara.services erreichbar ist
class ConnectionMonitor {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Stream-Controller fuer Online/Offline Status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Startet die Ueberwachung
  void start() {
    // Beim Start einmal pruefen
    checkConnection();

    // Auf Netzwerk-Aenderungen reagieren
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // Bei Netzwerk-Aenderung: tatsaechliche Erreichbarkeit pruefen
      checkConnection();
    });
  }

  /// Prueft ob klara.services tatsaechlich erreichbar ist
  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.baseUrl))
          .timeout(const Duration(seconds: 5));
      _updateStatus(response.statusCode < 500);
      return _isOnline;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void _updateStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _statusController.add(online);
    }
  }

  /// Stoppt die Ueberwachung
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
