import 'package:flutter/material.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/notificacao_entrada.dart';

/// Avisos persistentes de novas solicitações de entrada. Cada linha identifica
/// a van e abre o detalhe correspondente, onde o motorista decide sobre a
/// solicitação do aluno.
class SolicitacoesEntradaCard extends StatelessWidget {
  const SolicitacoesEntradaCard({
    super.key,
    required this.notificacoes,
    required this.onAbrir,
    this.maximo = 5,
  });

  final List<NotificacaoEntrada> notificacoes;
  final ValueChanged<NotificacaoEntrada> onAbrir;
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
                Icons.how_to_reg_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Solicitações de entrada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                '${notificacoes.length} pendente(s)',
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < visiveis.length; i++) ...[
            if (i > 0)
              const Divider(height: AppSpacing.sm, color: AppColors.divider),
            _LinhaEntrada(notificacao: visiveis[i], onAbrir: onAbrir),
          ],
          if (restantes > 0) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '+ $restantes solicitação(ões) anterior(es)',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaEntrada extends StatelessWidget {
  const _LinhaEntrada({required this.notificacao, required this.onAbrir});

  final NotificacaoEntrada notificacao;
  final ValueChanged<NotificacaoEntrada> onAbrir;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      color: AppColors.surface,
      borderColor: AppColors.divider,
      onTap: () => onAbrir(notificacao),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificacao.mensagem,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Van: ${notificacao.grupoNome} · toque para analisar',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
      ),
    );
  }
}
