import 'package:flutter/material.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/student_list_tile.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/presenca.dart';

class DailyListScreen extends StatelessWidget {
  const DailyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final presencas = store.presencasChamada;
    final chamada = store.chamadaAmanha;
    final totalRespostas = store.totalRespostas;
    final total = presencas.length;

    return Scaffold(
      appBar: const VangoAppBar(title: 'Lista do dia'),
      body: SafeArea(
        child: chamada == null
            ? const EstadoView(
                titulo: 'Nenhuma chamada aberta',
                mensagem:
                    'Abra a chamada de amanhã na tela inicial para ver as '
                    'respostas dos alunos.',
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: VangoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatarDataLonga(chamada.dataServico),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              StatusChip(
                                label: chamada.status.label,
                                tone: chamada.aberta
                                    ? VangoTone.success
                                    : VangoTone.neutral,
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$totalRespostas de $total aluno(s) responderam',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: presencas.isEmpty
                        ? const EstadoView(
                            titulo: 'Sem alunos ativos',
                            mensagem: 'Cadastre ou aprove alunos para montar a lista do dia.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            itemCount: presencas.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, index) {
                              final presenca = presencas[index];
                              return _LinhaPresenca(presenca: presenca);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LinhaPresenca extends StatelessWidget {
  const _LinhaPresenca({required this.presenca});

  final PresencaAluno presenca;

  @override
  Widget build(BuildContext context) {
    final resposta = presenca.resposta;
    final status = presenca.status;

    final detalhes = <Widget>[StatusChip.presenca(status, compact: true)];
    if (resposta.estouIndo) {
      detalhes.add(const SizedBox(width: 4));
      detalhes.add(
        StatusChip(
          label: resposta.estouIndoEm == null
              ? 'Estou indo'
              : 'Estou indo ${formatarHora(resposta.estouIndoEm!)}',
          tone: VangoTone.success,
          icon: Icons.directions_walk_rounded,
          compact: true,
        ),
      );
    }
    if (resposta.liberadoEm != null) {
      detalhes.add(const SizedBox(width: 4));
      detalhes.add(
        StatusChip(
          label: 'Liberado ${formatarHora(resposta.liberadoEm!)}',
          tone: VangoTone.info,
          icon: Icons.school_outlined,
          compact: true,
        ),
      );
    }
    if (resposta.avisadoEm != null) {
      detalhes.add(const SizedBox(width: 4));
      detalhes.add(
        const StatusChip(
          label: 'Avisado',
          tone: VangoTone.accent,
          icon: Icons.notifications_active_outlined,
          compact: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentListTile(
            aluno: presenca.aluno,
            subtitle: presenca.aluno.instituicao,
            trailing: status == StatusPresenca.semResposta
                ? null
                : StatusChip.presenca(status, compact: true),
          ),
          if (resposta.estouIndo ||
              resposta.liberadoEm != null ||
              resposta.avisadoEm != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 72,
                right: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: detalhes.skip(1).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
