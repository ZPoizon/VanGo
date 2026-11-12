import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/student_list_tile.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/usuario.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _busca = TextEditingController();
  Turno _turno = Turno.matutino;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final termo = _busca.text;
    final alunos = store.alunosDoTurno(_turno, busca: termo);
    final pendentes = store.alunosPendentes;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: VangoAppBar(
          title: 'Alunos',
          actions: [
            IconButton(
              tooltip: 'Convidar aluno',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => context.push('/driver/students/invite'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: TextField(
                  controller: _busca,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome ou instituição',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: SegmentedButton<Turno>(
                  segments: const [
                    ButtonSegment(
                      value: Turno.matutino,
                      label: Text('Matutino'),
                      icon: Icon(Icons.wb_sunny_outlined),
                    ),
                    ButtonSegment(
                      value: Turno.noturno,
                      label: Text('Noturno'),
                      icon: Icon(Icons.nights_stay_outlined),
                    ),
                  ],
                  selected: {_turno},
                  onSelectionChanged: (value) =>
                      setState(() => _turno = value.first),
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.muted,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(text: 'Ativos (${alunos.length})'),
                          Tab(text: 'Pendentes (${pendentes.length})'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _ListaAtivos(alunos: alunos),
                            _ListaPendentes(
                              pendentes: pendentes,
                              onAprovar: (id) async {
                                final r = await store.aprovarAluno(id);
                                if (!context.mounted) return;
                                mostrarResultado(context, r);
                              },
                              onRecusar: (id) async {
                                final r = await store.recusarAluno(id);
                                if (!context.mounted) return;
                                mostrarResultado(context, r);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.lg),
          child: VangoButton(
            label: 'Convidar aluno',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => context.push('/driver/students/invite'),
          ),
        ),
      ),
    );
  }
}

class _ListaAtivos extends StatelessWidget {
  const _ListaAtivos({required this.alunos});

  final List<Usuario> alunos;

  @override
  Widget build(BuildContext context) {
    if (alunos.isEmpty) {
      return const EstadoView(
        titulo: 'Nenhum aluno encontrado',
        mensagem:
            'Ajuste a busca ou o turno, ou aprove solicitações pendentes.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: alunos.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final aluno = alunos[index];
        return StudentListTile(
          aluno: aluno,
          subtitle: [
            if (aluno.instituicao != null) aluno.instituicao!,
            if (aluno.enderecoEmbarque != null) aluno.enderecoEmbarque!,
          ].join(' · '),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
          ),
          onTap: () => context.push('/driver/students/${aluno.id}'),
        );
      },
    );
  }
}

class _ListaPendentes extends StatelessWidget {
  const _ListaPendentes({
    required this.pendentes,
    required this.onAprovar,
    required this.onRecusar,
  });

  final List<Usuario> pendentes;
  final void Function(String id) onAprovar;
  final void Function(String id) onRecusar;

  @override
  Widget build(BuildContext context) {
    if (pendentes.isEmpty) {
      return const EstadoView(
        titulo: 'Sem solicitações pendentes',
        mensagem:
            'Quando um aluno enviar cadastro por convite, ele aparece aqui.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: pendentes.length,
      itemBuilder: (context, index) {
        final aluno = pendentes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: VangoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentListTile(
                  aluno: aluno,
                  subtitle: [
                    if (aluno.instituicao != null) aluno.instituicao!,
                    if (aluno.turno != null) aluno.turno!.label,
                  ].join(' · '),
                  trailing: const StatusChip(
                    label: 'Pendente',
                    tone: VangoTone.warning,
                    compact: true,
                  ),
                ),
                if (aluno.enderecoEmbarque != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 56,
                      right: AppSpacing.md,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text(
                      aluno.enderecoEmbarque!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: VangoButton(
                        label: 'Recusar',
                        variant: VangoButtonVariant.outline,
                        height: 44,
                        onPressed: () => onRecusar(aluno.id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: VangoButton(
                        label: 'Aprovar',
                        variant: VangoButtonVariant.success,
                        height: 44,
                        onPressed: () => onAprovar(aluno.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
