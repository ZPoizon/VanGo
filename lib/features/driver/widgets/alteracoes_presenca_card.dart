import 'package:flutter/material.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/notificacao_resposta.dart';
import 'package:vango/models/viagem.dart';

/// Lista compacta de alterações de presença recebidas em tempo real.
///
/// Exibida no painel e na lista do dia do motorista. Não cria um segundo
/// registro de confirmação: apenas apresenta o que mudou em `respostas`.
class AlteracoesPresencaCard extends StatelessWidget {
  const AlteracoesPresencaCard({
    super.key,
    required this.notificacoes,
    this.maximo = 3,
  });

  final List<NotificacaoResposta> notificacoes;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    if (notificacoes.isEmpty) return const SizedBox.shrink();

    final visiveis = notificacoes.take(maximo).toList();
    final restantes = notificacoes.length - visiveis.length;

    return VangoCard(
      color: AppColors.accentSoft,
      borderColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Alterações de presença',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              StatusChip(
                label: '${notificacoes.length}',
                tone: VangoTone.accent,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < visiveis.length; i++) ...[
            if (i > 0)
              const Divider(height: AppSpacing.sm, color: AppColors.divider),
            _LinhaAlteracao(notificacao: visiveis[i]),
          ],
          if (restantes > 0) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '+ $restantes alteração(ões) anterior(es)',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaAlteracao extends StatelessWidget {
  const _LinhaAlteracao({required this.notificacao});

  final NotificacaoResposta notificacao;

  @override
  Widget build(BuildContext context) {
    final ida = notificacao.sentido == SentidoViagem.ida;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ida ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notificacao.alunoNome,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                notificacao.mudanca,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          formatarHora(notificacao.criadoEm),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
