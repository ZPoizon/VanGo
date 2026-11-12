import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/padrao_semanal.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  late Map<int, PadraoSemanalDia> _dias;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _dias = Map<int, PadraoSemanalDia>.from(
      StoreScope.read(context).padraoSemanal,
    );
  }

  PadraoSemanalDia _dia(int diaSemana) =>
      _dias[diaSemana] ?? PadraoSemanalDia(diaSemana: diaSemana);

  void _atualizar(int diaSemana, PadraoSemanalDia novo) {
    setState(() => _dias[diaSemana] = novo);
  }

  Future<void> _escolherHorario(int diaSemana, {required bool entrada}) async {
    final dia = _dia(diaSemana);
    final atual =
        _parseHora(entrada ? dia.entraAs : dia.saiAs) ??
        (entrada
            ? const TimeOfDay(hour: 6, minute: 30)
            : const TimeOfDay(hour: 22, minute: 10));

    final escolhido = await showTimePicker(
      context: context,
      initialTime: atual,
      helpText: entrada ? 'Horário de entrada' : 'Horário de saída',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    // Cancelar não altera o valor exibido.
    if (escolhido == null || !mounted) return;

    final texto =
        '${doisDigitos(escolhido.hour)}:${doisDigitos(escolhido.minute)}';
    _atualizar(
      diaSemana,
      entrada ? dia.copyWith(entraAs: texto) : dia.copyWith(saiAs: texto),
    );
  }

  static TimeOfDay? _parseHora(String? valor) {
    if (valor == null || !valor.contains(':')) return null;
    final partes = valor.split(':');
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return null;
    return TimeOfDay(hour: hora, minute: minuto);
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final resultado = await StoreScope.read(context).salvarPadraoSemanal(_dias);
    if (!mounted) return;
    setState(() => _salvando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VangoAppBar(title: 'Padrão semanal'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                    'Defina os dias e horários fixos em que você usa a van. '
                    'O padrão só preenche chamadas futuras e não altera o '
                    'histórico.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (
                    var dia = DateTime.monday;
                    dia <= DateTime.sunday;
                    dia++
                  ) ...[
                    _CartaoDia(
                      dia: _dia(dia),
                      onIdaChanged: (valor) =>
                          _atualizar(dia, _dia(dia).copyWith(vaiIda: valor)),
                      onVoltaChanged: (valor) =>
                          _atualizar(dia, _dia(dia).copyWith(vaiVolta: valor)),
                      onEntradaTap: () => _escolherHorario(dia, entrada: true),
                      onSaidaTap: () => _escolherHorario(dia, entrada: false),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Se você já respondeu manualmente à chamada de amanhã, '
                    'sua resposta prevalece sobre o padrão.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: VangoButton(
                label: 'Salvar padrão semanal',
                icon: Icons.save_outlined,
                loading: _salvando,
                onPressed: _salvar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoDia extends StatelessWidget {
  const _CartaoDia({
    required this.dia,
    required this.onIdaChanged,
    required this.onVoltaChanged,
    required this.onEntradaTap,
    required this.onSaidaTap,
  });

  final PadraoSemanalDia dia;
  final ValueChanged<bool> onIdaChanged;
  final ValueChanged<bool> onVoltaChanged;
  final VoidCallback onEntradaTap;
  final VoidCallback onSaidaTap;

  @override
  Widget build(BuildContext context) {
    final semVan = !dia.vaiIda && !dia.vaiVolta;
    return VangoCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nomeDiaSemana(dia.diaSemana),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              StatusChip(
                label: semVan ? 'Sem van' : 'Ativo',
                tone: semVan ? VangoTone.neutral : VangoTone.success,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _LinhaDirecao(
            label: 'Ida',
            ativo: dia.vaiIda,
            horario: dia.entraAs,
            onChanged: onIdaChanged,
            onHorarioTap: onEntradaTap,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _LinhaDirecao(
            label: 'Volta',
            ativo: dia.vaiVolta,
            horario: dia.saiAs,
            onChanged: onVoltaChanged,
            onHorarioTap: onSaidaTap,
          ),
        ],
      ),
    );
  }
}

class _LinhaDirecao extends StatelessWidget {
  const _LinhaDirecao({
    required this.label,
    required this.ativo,
    required this.horario,
    required this.onChanged,
    required this.onHorarioTap,
  });

  final String label;
  final bool ativo;
  final String? horario;
  final ValueChanged<bool> onChanged;
  final VoidCallback onHorarioTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Row(
            children: [Switch(value: ativo, onChanged: onChanged)],
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: ativo ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !ativo,
              child: InkWell(
                onTap: onHorarioTap,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label == 'Ida' ? 'Entro às' : 'Saio às',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatarHoraTexto(horario),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ativo ? AppColors.text : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
