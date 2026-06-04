import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/info_screen.dart';
import 'screens/settings_screen.dart';
import 'services/detection_service.dart';
import 'services/safety_engine.dart';
import 'services/alert_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DetectionService()),
        ChangeNotifierProvider(create: (_) => SafetyEngine()),
        ChangeNotifierProvider(create: (_) => AlertService()),
      ],
      child: const TrafficSafetyApp(),
    ),
  );
}

class TrafficSafetyApp extends StatelessWidget {
  const TrafficSafetyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pedestrian Road Crossing Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/info': (context) => const InfoScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
