import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'vango_button.dart';

enum EstadoTipo { vazio, erro, offline, proibido, info }

class EstadoView extends StatelessWidget {
  const EstadoView({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.tipo = EstadoTipo.vazio,
    this.acaoLabel,
    this.onAcao,
  });

  final String titulo;
  final String mensagem;
  final EstadoTipo tipo;
  final String? acaoLabel;
  final VoidCallback? onAcao;

  IconData get _icone {
    switch (tipo) {
      case EstadoTipo.vazio:
        return Icons.inbox_outlined;
      case EstadoTipo.erro:
        return Icons.error_outline_rounded;
      case EstadoTipo.offline:
        return Icons.wifi_off_rounded;
      case EstadoTipo.proibido:
        return Icons.lock_outline_rounded;
      case EstadoTipo.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get _cor {
    switch (tipo) {
      case EstadoTipo.erro:
        return AppColors.error;
      case EstadoTipo.offline:
        return AppColors.warning;
      case EstadoTipo.proibido:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _cor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icone, size: 30, color: _cor),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            if (acaoLabel != null && onAcao != null) ...[
              const SizedBox(height: AppSpacing.md),
              VangoButton(
                label: acaoLabel!,
                onPressed: onAcao,
                variant: VangoButtonVariant.outline,
                expand: false,
                height: 48,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CarregandoView extends StatelessWidget {
  const CarregandoView({super.key, this.mensagem = 'Carregando…'});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              mensagem,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
