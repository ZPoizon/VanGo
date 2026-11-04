import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de cores baseada no design Figma do VanGo
  static const Color primaryDark = Color(0xFF1B2A4E); // Azul escuro dos cabeçalhos e botões
  static const Color primaryYellow = Color(0xFFFBBF24); // Amarelo vibrante do ícone VanGo
  static const Color background = Color(0xFFF6F8FA); // Fundo claro das telas
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Cores de Status / Badges (Image 3 do Figma)
  static const Color badgeIdaEVoltaBg = Color(0xFFDCFCE7);
  static const Color badgeIdaEVoltaText = Color(0xFF166534);

  static const Color badgeSoIdaBg = Color(0xFFE0F2FE);
  static const Color badgeSoIdaText = Color(0xFF0369A1);

  static const Color badgeSoVoltaBg = Color(0xFFF3E8FF);
  static const Color badgeSoVoltaText = Color(0xFF6B21A8);

  static const Color badgeNaoVaiBg = Color(0xFFFEE2E2);
  static const Color badgeNaoVaiText = Color(0xFF991B1B);

  static const Color badgeSemRespostaBg = Color(0xFFFFEDD5);
  static const Color badgeSemRespostaText = Color(0xFFC2410C);

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
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
