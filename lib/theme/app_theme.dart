import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de cores oficial baseada na identidade visual VanGo
  static const Color primaryDark = Color(0xFF001941); // Azul-marinho oficial
  static const Color primaryYellow = Color(0xFFFD5C3C); // Coral/Laranja oficial
  static const Color background = Color(0xFFF9F5F2); // Creme oficial
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF001941);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE7DFD8);

  // Cores de Status / Badges
  static const Color badgeIdaEVoltaBg = Color(0xFFDCFCE7);
  static const Color badgeIdaEVoltaText = Color(0xFF166534);

  static const Color badgeSoIdaBg = Color(0xFFE0F2FE);
  static const Color badgeSoIdaText = Color(0xFF0369A1);

  static const Color badgeSoVoltaBg = Color(0xFFF3E8FF);
  static const Color badgeSoVoltaText = Color(0xFF6B21A8);

  static const Color badgeNaoVaiBg = Color(0xFFFEE2E2);
  static const Color badgeNaoVaiText = Color(0xFF991B1B);

  static const Color badgeSemRespostaBg = Color(0xFFFFF0EC);
  static const Color badgeSemRespostaText = Color(0xFFFD5C3C);

  static const Color badgeAvisadoBg = Color(0xFFE0F2FE);
  static const Color badgeAvisadoText = Color(0xFF0284C7);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primaryDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        primary: primaryDark,
        secondary: primaryYellow,
        surface: cardBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
    );
  }
}
