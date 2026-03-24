package services.klara.klara_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity statt FlutterActivity — wird von local_auth
// fuer die Biometrie-Abfrage (Fingerabdruck/Gesicht) benoetigt
class MainActivity : FlutterFragmentActivity()
