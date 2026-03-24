import 'package:flutter/material.dart';

/// Zentrale Konfiguration der App — URLs, Farben, Konstanten
class AppConfig {
  // Basis-URL der Klara-Plattform
  static const String baseUrl = 'https://klara.services';

  // Gateway-URL (Startseite im WebView)
  static const String gatewayUrl = '$baseUrl/gateway/';

  // Versions-Check Endpoint
  static const String versionCheckUrl = '$baseUrl/gateway/api/app-version/';

  // ntfy Push-Server
  static const String ntfyBaseUrl = '$baseUrl/ntfy';

  // NFC-Checkin Endpoint (Time-Tracking)
  static const String nfcCheckinUrl =
      '$baseUrl/time-tracking/api/rfid-checkin/';

  // App-Version (wird mit package_info_plus ausgelesen)
  static const String appVersion = '1.0.0';

  // User-Agent fuer den WebView
  static const String userAgent = 'KlaraApp/$appVersion (Flutter)';
}

/// Farben aus dem bestehenden Klara/Perasi Theme
class KlaraColors {
  static const Color primary = Color(0xFFB5734A); // Braun/Kupfer
  static const Color success = Color(0xFF28A745); // Gruen
  static const Color danger = Color(0xFFDC3545); // Rot
  static const Color accent = Color(0xFFD99F53); // Gold/Akzent
  static const Color background = Color(0xFFF5F5F5); // Heller Hintergrund
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF333333);
}
