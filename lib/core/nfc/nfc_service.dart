import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import '../auth/cookie_bridge.dart';
import '../config.dart';

/// Ergebnis eines NFC-Checkin-Vorgangs
class NfcCheckinResult {
  final bool success;
  final String message;

  NfcCheckinResult({required this.success, required this.message});
}

/// Liest NFC-Chips und sendet die UID an das Time-Tracking-Backend.
/// NFC wird NUR fuer Einstempeln verwendet, NICHT als Login.
class NfcService {
  final CookieBridge _cookieBridge = CookieBridge();

  /// Prueft ob NFC auf diesem Geraet verfuegbar ist.
  ///
  /// Auf Shared-Tablets (registrierten Gemeinschafts-Geraeten) wird NFC
  /// bewusst ausgeschaltet — dort uebernimmt der Pi Zero das Scannen, das
  /// Tablet ist nur Anzeige. Andernfalls koennte das Tablet versehentlich
  /// selbst versuchen zu scannen.
  Future<bool> isAvailable() async {
    if (await _cookieBridge.hasSharedTabletCookie()) {
      return false;
    }
    return await NfcManager.instance.isAvailable();
  }

  /// Startet den NFC-Scan und gibt die gelesene Chip-UID zurueck.
  /// Der Callback wird aufgerufen sobald ein Chip erkannt wird.
  Future<void> startScan({
    required void Function(String chipUid) onChipRead,
    required void Function(String error) onError,
  }) async {
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'Halte dein iPhone an den NFC-Chip',
        onDiscovered: (NfcTag tag) async {
          try {
            final uid = _extractUid(tag);
            if (uid != null) {
              onChipRead(uid);
            } else {
              onError('Chip konnte nicht gelesen werden');
            }
          } catch (e) {
            onError('Fehler beim Lesen: $e');
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      onError('NFC nicht verfuegbar: $e');
    }
  }

  /// Stoppt einen laufenden NFC-Scan
  Future<void> stopScan() async {
    await NfcManager.instance.stopSession();
  }

  /// Sendet die gescannte Chip-UID an das Time-Tracking-Backend
  Future<NfcCheckinResult> checkin({
    required String chipUid,
    required String clientUsername,
  }) async {
    try {
      // Session-Cookies aus dem WebView holen
      final cookieHeader = await _cookieBridge.getCookieHeader();
      final csrfToken = await _cookieBridge.getCookie('csrftoken');

      final response = await http
          .post(
            Uri.parse(AppConfig.nfcCheckinUrl),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': cookieHeader,
              if (csrfToken != null) 'X-CSRFToken': csrfToken,
            },
            body: jsonEncode({
              'chip_uid': chipUid,
              'client_username': clientUsername,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NfcCheckinResult(
          success: true,
          message: data['message'] ?? 'Erfolgreich eingestempelt',
        );
      } else {
        try {
          final data = jsonDecode(response.body);
          return NfcCheckinResult(
            success: false,
            message: data['message'] ?? 'Fehler beim Einstempeln',
          );
        } catch (_) {
          return NfcCheckinResult(
            success: false,
            message: 'Server-Fehler (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return NfcCheckinResult(
        success: false,
        message: 'Verbindungsfehler. Bitte erneut versuchen.',
      );
    }
  }

  /// Extrahiert die UID aus verschiedenen NFC-Tag-Typen.
  /// Android: NfcTagAndroid.id liefert die UID
  /// iOS: MiFareIos.identifier liefert die UID
  String? _extractUid(NfcTag tag) {
    if (Platform.isAndroid) {
      return _extractUidAndroid(tag);
    } else if (Platform.isIOS) {
      return _extractUidIos(tag);
    }
    return null;
  }

  /// Android: Tag-ID direkt aus NfcTagAndroid auslesen
  String? _extractUidAndroid(NfcTag tag) {
    final androidTag = NfcTagAndroid.from(tag);
    if (androidTag != null && androidTag.id.isNotEmpty) {
      return androidTag.id
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
    }
    return null;
  }

  /// iOS: UID aus MiFare oder ISO 15693 Tag auslesen
  String? _extractUidIos(NfcTag tag) {
    // MiFare (die meisten NFC-Schluesselanhaenger)
    final miFare = MiFareIos.from(tag);
    if (miFare != null && miFare.identifier.isNotEmpty) {
      return miFare.identifier
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
    }

    // ISO 15693
    final iso15693 = Iso15693Ios.from(tag);
    if (iso15693 != null && iso15693.identifier.isNotEmpty) {
      return iso15693.identifier
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
    }

    return null;
  }
}
