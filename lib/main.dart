// Archivo: lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importamos las pantallas que acabamos de separar
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool hasProfile = prefs.getString('user_profile_v15') != null;
  
  runApp(MyApp(hasProfile: hasProfile));
}

class MyApp extends StatelessWidget {
  final bool hasProfile;
  const MyApp({super.key, required this.hasProfile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BioMacros',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1015), 
        cardColor: const Color(0xFF131B24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF131B24),
        ),
      ),
      home: hasProfile ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}