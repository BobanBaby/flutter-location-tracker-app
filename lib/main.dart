import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/tracking_provider.dart';
import 'screens/splash_screen.dart';
import 'services/foreground_task_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase app from google-services.json
  try {
    await Firebase.initializeApp();
    print('Firebase Core initialized successfully.');
  } catch (e) {
    print('Firebase Core initialization note: $e');
  }

  // Initialize Android Foreground Service configuration
  try {
    await ForegroundServiceManager.instance.initService();
  } catch (e) {
    print('Error initializing Foreground Service manager: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ],
      child: const LocationTrackingApp(),
    ),
  );
}

class LocationTrackingApp extends StatelessWidget {
  const LocationTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
