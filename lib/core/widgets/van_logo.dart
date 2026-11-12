import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class VanLogo extends StatelessWidget {
  const VanLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Icon(
        Icons.directions_bus_rounded,
        size: size * 0.56,
        color: AppColors.primary,
      ),
    );
  }
}
