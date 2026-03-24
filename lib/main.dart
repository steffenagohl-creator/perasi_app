import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Status-Bar und Navigation-Bar Farben anpassen
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: KlaraColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const KlaraApp());
}
