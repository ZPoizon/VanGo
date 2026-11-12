import 'package:flutter/material.dart';

/// Tokens de cor observados no protótipo (handoff/design_tokens.json).
abstract final class AppColors {
  static const Color primary = Color(0xFF1B2A49);
  static const Color primarySoft = Color(0xFFE8EDF7);
  static const Color accent = Color(0xFFFFC107);
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFEF6C00);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF182033);
  static const Color muted = Color(0xFF687386);
  static const Color divider = Color(0xFFDCE2EA);

  // Fundos suaves derivados dos papéis semânticos.
  static const Color successSoft = Color(0xFFE7F4E8);
  static const Color errorSoft = Color(0xFFFBEAEA);
  static const Color warningSoft = Color(0xFFFDF0E5);
  static const Color accentSoft = Color(0xFFFFF7DC);
  static const Color info = Color(0xFF0369A1);
  static const Color infoSoft = Color(0xFFE0F2FE);

  static const Color cardShadow = Color(0x171B2A49);
}
