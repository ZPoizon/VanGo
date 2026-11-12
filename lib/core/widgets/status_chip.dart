import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/presenca.dart';

enum VangoTone { success, warning, error, info, accent, neutral, purple }

extension VangoToneColors on VangoTone {
  Color get foreground {
    switch (this) {
      case VangoTone.success:
        return AppColors.success;
      case VangoTone.warning:
        return AppColors.warning;
      case VangoTone.error:
        return AppColors.error;
      case VangoTone.info:
        return AppColors.info;
      case VangoTone.accent:
        return const Color(0xFF8A6100);
      case VangoTone.neutral:
        return AppColors.muted;
      case VangoTone.purple:
        return const Color(0xFF6B21A8);
    }
  }

  Color get background {
    switch (this) {
      case VangoTone.success:
        return AppColors.successSoft;
      case VangoTone.warning:
        return AppColors.warningSoft;
      case VangoTone.error:
        return AppColors.errorSoft;
      case VangoTone.info:
        return AppColors.infoSoft;
      case VangoTone.accent:
        return AppColors.accentSoft;
      case VangoTone.neutral:
        return AppColors.primarySoft;
      case VangoTone.purple:
        return const Color(0xFFF3E8FF);
    }
  }
}

VangoTone toneDaPresenca(StatusPresenca status) {
  switch (status) {
    case StatusPresenca.idaEVolta:
      return VangoTone.success;
    case StatusPresenca.soIda:
      return VangoTone.info;
    case StatusPresenca.soVolta:
      return VangoTone.purple;
    case StatusPresenca.naoVai:
      return VangoTone.error;
    case StatusPresenca.semResposta:
      return VangoTone.warning;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = VangoTone.neutral,
    this.icon,
    this.compact = false,
  });

  StatusChip.presenca(
    StatusPresenca status, {
    super.key,
    this.compact = false,
    this.icon,
  }) : label = status.label,
       tone = toneDaPresenca(status);

  final String label;
  final VangoTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
