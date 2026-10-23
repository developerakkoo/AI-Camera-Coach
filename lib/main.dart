import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_ai_camera_guide/screens/portrait_camera_screen.dart';
import 'package:my_ai_camera_guide/theme/jarvis_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF020817),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'J.A.R.V.I.S Vision',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.themeData,
      home: const PortraitCameraScreen(),
    );
  }
}
