import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BotaoPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final IconData? icone;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final double borderRadius;

  const BotaoPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
    this.backgroundColor = AppTheme.primaryDark,
    this.textColor = Colors.white,
    this.height = 54,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icone != null) ...[
              Icon(icone, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              texto,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
