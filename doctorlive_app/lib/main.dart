import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'screens/welcome/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DoctorLiveApp());
}

/// DoctorLive application root widget.
class DoctorLiveApp extends StatelessWidget {
  const DoctorLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoctorLive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
