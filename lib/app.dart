import 'package:flutter/material.dart';
import 'package:vango/theme/app_theme.dart';
import 'package:vango/telas/login_screen.dart';

class VanGoApp extends StatelessWidget {
  const VanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
