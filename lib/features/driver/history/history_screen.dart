import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/viagem.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final viagens = List<Viagem>.from(store.historico)
      ..sort((a, b) => b.dataViagem.compareTo(a.dataViagem));

    final meses = <String, List<Viagem>>{};
    for (final viagem in viagens) {
      final chave =
          '${capitalizar(_meses[viagem.dataViagem.month - 1])} ${viagem.dataViagem.year}';
      meses.putIfAbsent(chave, () => <Viagem>[]).add(viagem);
    }

    return Scaffold(
      appBar: const VangoAppBar(title: 'Histórico'),
      body: SafeArea(
        child: viagens.isEmpty
            ? const EstadoView(
                titulo: 'Nenhuma viagem encerrada',
                mensagem: 'Quando as viagens forem encerradas, o histórico aparecerá aqui.',
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  for (final entrada in meses.entries) ...[
                    SecaoRotulo(entrada.key),
                    const SizedBox(height: AppSpacing.xs),
                    for (final viagem in entrada.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: VangoCard(
                          onTap: () =>
                              context.push('/driver/history/${viagem.id}'),
                          child: Row(
                            children: [
                              _BadgeSentido(sentido: viagem.sentido),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${formatarDataLonga(viagem.dataViagem)} · ${viagem.sentido.label}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatarIntervalo(
                                        viagem.iniciadaEm,
                                        viagem.encerradaEm,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    StatusChip(
                                      label:
                                          '${viagem.totalConfirmados} confirmado(s)',
                                      tone: VangoTone.success,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ),
    );
  }
}

const List<String> _meses = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class _BadgeSentido extends StatelessWidget {
  const _BadgeSentido({required this.sentido});

  final SentidoViagem sentido;

  @override
  Widget build(BuildContext context) {
    final ida = sentido == SentidoViagem.ida;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ida ? AppColors.infoSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(
        ida ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
        color: ida ? AppColors.info : AppColors.success,
      ),
    );
  }
}
