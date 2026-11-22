import 'package:flutter/material.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/store.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/student_list_tile.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/presenca.dart';
import 'package:vango/models/viagem.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final viagem = store.viagemPorId(tripId);

    if (viagem == null) {
      return const Scaffold(
        appBar: VangoAppBar(title: 'Detalhe da viagem'),
        body: EstadoView(
          titulo: 'Viagem não encontrada',
          mensagem: 'Esta viagem ainda não está disponível no histórico.',
          tipo: EstadoTipo.erro,
        ),
      );
    }

    return Scaffold(
      appBar: VangoAppBar(
        title: 'Viagem de ${viagem.sentido.label.toLowerCase()}',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            VangoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(
                        label: viagem.sentido.label,
                        tone: viagem.sentido == SentidoViagem.ida
                            ? VangoTone.info
                            : VangoTone.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      StatusChip.viagem(viagem.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    formatarDataLonga(viagem.dataViagem),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatarIntervalo(viagem.iniciadaEm, viagem.encerradaEm),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viagem.totalConfirmados} aluno(s) confirmado(s) · '
                    '${viagem.totalEstouIndo} "Estou indo"',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  if (viagem.motivoCancelamento != null &&
                      viagem.motivoCancelamento!.isNotEmpty) ...[
                    const Divider(height: AppSpacing.lg),
                    Text(
                      'Motivo do cancelamento: ${viagem.motivoCancelamento}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SecaoRotulo('Alunos'),
            const SizedBox(height: AppSpacing.xs),
            if (viagem.confirmacoes.isEmpty)
              const VangoCard(
                child: Text(
                  'Nenhum aluno confirmado nesta viagem.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              )
            else
              VangoCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < viagem.confirmacoes.length; i++) ...[
                      _LinhaConfirmacao(
                        store: store,
                        confirmacao: viagem.confirmacoes[i],
                      ),
                      if (i < viagem.confirmacoes.length - 1)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinhaConfirmacao extends StatelessWidget {
  const _LinhaConfirmacao({required this.store, required this.confirmacao});

  final VanGoStore store;
  final ConfirmacaoViagem confirmacao;

  @override
  Widget build(BuildContext context) {
    final aluno = store.alunoPorId(confirmacao.alunoId);
    if (aluno == null) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];
    if (confirmacao.estouIndo) {
      chips.add(
        StatusChip(
          label: confirmacao.estouIndoEm == null
              ? 'Estou indo'
              : 'Estou indo ${formatarHora(confirmacao.estouIndoEm!)}',
          tone: VangoTone.success,
          compact: true,
          icon: Icons.directions_walk_rounded,
        ),
      );
    }
    if (confirmacao.liberadoEm != null) {
      chips.add(
        StatusChip(
          label: 'Liberado ${formatarHora(confirmacao.liberadoEm!)}',
          tone: VangoTone.info,
          compact: true,
          icon: Icons.school_outlined,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentListTile(
            aluno: aluno,
            subtitle: aluno.instituicao,
            trailing: StatusChip(
              label: confirmacao.status == RespostaSentido.vai
                  ? 'Confirmado'
                  : confirmacao.status.label,
              tone: confirmacao.status == RespostaSentido.vai
                  ? VangoTone.success
                  : VangoTone.neutral,
              compact: true,
            ),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 72,
                right: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Wrap(spacing: 4, runSpacing: 4, children: chips),
            ),
        ],
      ),
    );
  }
}
