import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum VangoButtonVariant { primary, outline, accent, success, danger, ghost }

class VangoButton extends StatelessWidget {
  const VangoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = VangoButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VangoButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final colors = _VangoButtonColors.from(variant);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          // Mantém o nó semântico como botão enquanto o spinner aparece.
          // Sem isso, o engine Web troca button por loadingSpinner e o foco
          // sai da view durante o pop da rota (flutter/flutter#194056).
          Semantics(
            label: label,
            excludeSemantics: true,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.foreground,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    final minimumSize = Size(expand ? double.infinity : 0, height);

    if (variant == VangoButtonVariant.outline ||
        variant == VangoButtonVariant.ghost) {
      return SizedBox(
        width: expand ? double.infinity : null,
        height: height,
        child: OutlinedButton(
          onPressed: _disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.foreground,
            backgroundColor: colors.background,
            disabledForegroundColor: AppColors.muted,
            minimumSize: minimumSize,
            side: variant == VangoButtonVariant.outline
                ? BorderSide(color: colors.border, width: 1.5)
                : BorderSide.none,
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: AppColors.primarySoft,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          minimumSize: minimumSize,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: child,
      ),
    );
  }
}

class _VangoButtonColors {
  const _VangoButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  factory _VangoButtonColors.from(VangoButtonVariant variant) {
    switch (variant) {
      case VangoButtonVariant.primary:
        return const _VangoButtonColors(
          background: AppColors.primary,
          foreground: Colors.white,
          border: AppColors.primary,
        );
      case VangoButtonVariant.outline:
        return const _VangoButtonColors(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: AppColors.primary,
        );
      case VangoButtonVariant.accent:
        return const _VangoButtonColors(
          background: AppColors.accent,
          foreground: AppColors.primary,
          border: AppColors.accent,
        );
      case VangoButtonVariant.success:
        return const _VangoButtonColors(
          background: AppColors.success,
          foreground: Colors.white,
          border: AppColors.success,
        );
      case VangoButtonVariant.danger:
        return const _VangoButtonColors(
          background: AppColors.error,
          foreground: Colors.white,
          border: AppColors.error,
        );
      case VangoButtonVariant.ghost:
        return const _VangoButtonColors(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: Colors.transparent,
        );
    }
  }

  final Color background;
  final Color foreground;
  final Color border;
}
