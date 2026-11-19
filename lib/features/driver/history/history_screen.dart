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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  SentidoViagem? _filtroSentido;
  DateTimeRange? _filtroData;

  void _limparFiltros() {
    setState(() {
      _filtroSentido = null;
      _filtroData = null;
    });
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(agora.year - 2),
      lastDate: agora,
      initialDateRange: _filtroData,
      helpText: 'Filtrar por período',
      cancelText: 'Limpar',
      confirmText: 'Aplicar',
    );
    if (!mounted) return;
    setState(() {
      _filtroData = intervalo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    var viagens = List<Viagem>.from(store.historico)
      ..sort((a, b) => b.dataViagem.compareTo(a.dataViagem));

    if (_filtroSentido != null) {
      viagens = viagens.where((v) => v.sentido == _filtroSentido).toList();
    }

    if (_filtroData != null) {
      viagens = viagens.where((v) {
        final data = DateTime(
          v.dataViagem.year,
          v.dataViagem.month,
          v.dataViagem.day,
        );
        final inicio = DateTime(
          _filtroData!.start.year,
          _filtroData!.start.month,
          _filtroData!.start.day,
        );
        final fim = DateTime(
          _filtroData!.end.year,
          _filtroData!.end.month,
          _filtroData!.end.day,
          23,
          59,
          59,
        );
        return data.isAfter(inicio.subtract(const Duration(seconds: 1))) &&
            data.isBefore(fim);
      }).toList();
    }

    final meses = <String, List<Viagem>>{};
    for (final viagem in viagens) {
      final chave =
          '${capitalizar(_meses[viagem.dataViagem.month - 1])} ${viagem.dataViagem.year}';
      meses.putIfAbsent(chave, () => <Viagem>[]).add(viagem);
    }

    final temFiltroAtivo = _filtroSentido != null || _filtroData != null;

    return Scaffold(
      appBar: const VangoAppBar(title: 'Histórico'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _filtroData == null
                            ? 'Período'
                            : '${formatarDataCurta(_filtroData!.start)} - ${formatarDataCurta(_filtroData!.end)}',
                      ),
                      selected: _filtroData != null,
                      onSelected: (_) => _selecionarData(),
                      avatar: const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filtroSentido == null,
                      onSelected: (_) => setState(() => _filtroSentido = null),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ChoiceChip(
                      label: const Text('Ida'),
                      selected: _filtroSentido == SentidoViagem.ida,
                      onSelected: (_) =>
                          setState(() => _filtroSentido = SentidoViagem.ida),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ChoiceChip(
                      label: const Text('Volta'),
                      selected: _filtroSentido == SentidoViagem.volta,
                      onSelected: (_) =>
                          setState(() => _filtroSentido = SentidoViagem.volta),
                    ),
                    if (temFiltroAtivo) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        tooltip: 'Limpar filtros',
                        icon: const Icon(
                          Icons.clear_all_rounded,
                          color: AppColors.muted,
                        ),
                        onPressed: _limparFiltros,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: viagens.isEmpty
                  ? EstadoView(
                      titulo: temFiltroAtivo
                          ? 'Nenhuma viagem encontrada'
                          : 'Nenhuma viagem encerrada',
                      mensagem: temFiltroAtivo
                          ? 'Tente ajustar os filtros selecionados acima.'
                          : 'Quando as viagens forem encerradas, o histórico aparecerá aqui.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (final entrada in meses.entries) ...[
                          SecaoRotulo(entrada.key),
                          const SizedBox(height: AppSpacing.xs),
                          for (final viagem in entrada.value)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: VangoCard(
                                onTap: () => context.push(
                                  '/driver/history/${viagem.id}',
                                ),
                                child: Row(
                                  children: [
                                    _BadgeSentido(sentido: viagem.sentido),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
