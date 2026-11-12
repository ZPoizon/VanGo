import 'package:flutter/material.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/student_list_tile.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/presenca.dart';
import 'package:vango/models/viagem.dart';

enum _FiltroHoje { todos, ida, volta }

class TodayStudentsScreen extends StatefulWidget {
  const TodayStudentsScreen({super.key});

  @override
  State<TodayStudentsScreen> createState() => _TodayStudentsScreenState();
}

class _TodayStudentsScreenState extends State<TodayStudentsScreen> {
  _FiltroHoje _filtro = _FiltroHoje.todos;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    final ida = store.confirmadosNoSentido(SentidoViagem.ida);
    final volta = store.confirmadosNoSentido(SentidoViagem.volta);

    final Map<String, PresencaAluno> mapa = {};
    switch (_filtro) {
      case _FiltroHoje.todos:
        for (final presenca in [...ida, ...volta]) {
          mapa[presenca.aluno.id] = presenca;
        }
      case _FiltroHoje.ida:
        for (final presenca in ida) {
          mapa[presenca.aluno.id] = presenca;
        }
      case _FiltroHoje.volta:
        for (final presenca in volta) {
          mapa[presenca.aluno.id] = presenca;
        }
    }
    final lista = mapa.values.toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return Scaffold(
      appBar: const VangoAppBar(title: 'Quem vai hoje'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: VangoCard(
                color: AppColors.primarySoft,
                borderColor: AppColors.primarySoft,
                child: Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Esta lista mostra apenas nome, instituição e status. '
                        'Telefone e endereço não são exibidos entre alunos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  _FiltroChip(
                    label: 'Todos (${ida.length + volta.length})',
                    selecionado: _filtro == _FiltroHoje.todos,
                    onTap: () => setState(() => _filtro = _FiltroHoje.todos),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _FiltroChip(
                    label: 'Só ida (${ida.length})',
                    selecionado: _filtro == _FiltroHoje.ida,
                    onTap: () => setState(() => _filtro = _FiltroHoje.ida),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _FiltroChip(
                    label: 'Só volta (${volta.length})',
                    selecionado: _filtro == _FiltroHoje.volta,
                    onTap: () => setState(() => _filtro = _FiltroHoje.volta),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: lista.isEmpty
                  ? const EstadoView(
                      titulo: 'Ninguém confirmado ainda',
                      mensagem:
                          'Quando os alunos responderem à chamada, eles '
                          'aparecem aqui.',
                      tipo: EstadoTipo.vazio,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: lista.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final presenca = lista[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxs,
                          ),
                          child: StudentListTile(
                            aluno: presenca.aluno,
                            subtitle: presenca.aluno.instituicao,
                            trailing: StatusChip.presenca(
                              presenca.status,
                              compact: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selecionado ? Colors.white : AppColors.text,
      ),
      showCheckmark: false,
      side: BorderSide(
        color: selecionado ? AppColors.primary : AppColors.divider,
      ),
    );
  }
}
