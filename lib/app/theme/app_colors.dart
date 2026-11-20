import 'package:flutter/material.dart';

/// Paleta de cores oficial do VanGo.
/// Identidade: Azul-marinho #001941, Coral/Laranja #FD5C3C e Creme #F9F5F2.
abstract final class AppColors {
  static const Color primary = Color(0xFF001941);     // Azul-marinho oficial
  static const Color primarySoft = Color(0xFFE5EAEE); // Azul-marinho suave
  static const Color accent = Color(0xFFFD5C3C);      // Coral/Laranja oficial
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFEF6C00);
  static const Color background = Color(0xFFF9F5F2);   // Creme oficial
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF001941);        // Texto azul-marinho
  static const Color muted = Color(0xFF687386);
  static const Color divider = Color(0xFFE7DFD8);     // Divisor no tom creme

  // Fundos suaves derivados dos papéis semânticos.
  static const Color successSoft = Color(0xFFE7F4E8);
  static const Color errorSoft = Color(0xFFFBEAEA);
  static const Color warningSoft = Color(0xFFFDF0E5);
  static const Color accentSoft = Color(0xFFFFF0EC);   // Coral/Laranja suave
  static const Color info = Color(0xFF0369A1);
  static const Color infoSoft = Color(0xFFE0F2FE);

  static const Color cardShadow = Color(0x17001941);
}
