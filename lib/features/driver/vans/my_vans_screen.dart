import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/grupo.dart';

/// Painel inicial do motorista: lista de vans e criação de novos grupos.
class MyVansScreen extends StatefulWidget {
  const MyVansScreen({super.key});

  @override
  State<MyVansScreen> createState() => _MyVansScreenState();
}

class _MyVansScreenState extends State<MyVansScreen> {
  List<GrupoVan> _grupos = <GrupoVan>[];
  Map<String, int> _alunosPorGrupo = <String, int>{};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final store = StoreScope.read(context);
    final grupos = await store.carregarMeusGrupos();
    final contagem = <String, int>{};
    for (final grupo in grupos) {
      contagem[grupo.id] = await store.contarAlunosGrupo(grupo.id);
    }
    if (!mounted) return;
    setState(() {
      _grupos = grupos;
      _alunosPorGrupo = contagem;
      _carregando = false;
    });
  }

  Future<void> _abrirFormulario() async {
    final criado = await context.push<bool>('/driver/vans/new');
    if (criado == true && mounted) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: VangoAppBar(
        title: 'Minhas vans',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/driver/profile'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await StoreScope.read(context).sair();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const SecaoRotulo('Minhas vans'),
                    const SizedBox(height: AppSpacing.md),
                    if (_grupos.isEmpty)
                      VangoCard(
                        color: AppColors.primarySoft,
                        child: Column(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                size: 44,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Text(
                              'Você ainda não tem uma van',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Crie sua primeira van para gerar um código de '
                              'entrada e começar a gerenciar alunos e chamadas.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      for (final grupo in _grupos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: VangoCard(
                            onTap: () => context
                                .push('/driver/vans/${grupo.id}')
                                .then((_) => _carregar()),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_bus_rounded,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        grupo.nome,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (grupo.trajeto.isNotEmpty)
                                  InfoLinha(
                                    icon: Icons.route_outlined,
                                    texto: grupo.trajeto,
                                  ),
                                InfoLinha(
                                  icon: Icons.schedule_outlined,
                                  texto: grupo.periodoOuPadrao,
                                ),
                                InfoLinha(
                                  icon: Icons.people_outline_rounded,
                                  texto:
                                      '${_alunosPorGrupo[grupo.id] ?? 0} alunos',
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.md),
                    VangoButton(
                      label: _grupos.isEmpty
                          ? 'Criar minha primeira van'
                          : 'Criar nova van',
                      icon: Icons.add_rounded,
                      onPressed: _abrirFormulario,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_grupos.isNotEmpty)
                      VangoButton(
                        label: 'Abrir painel da van selecionada',
                        icon: Icons.dashboard_outlined,
                        variant: VangoButtonVariant.outline,
                        onPressed: () {
                          final selecionado = StoreScope.read(context)
                              .grupoSelecionado;
                          if (selecionado == null) {
                            mostrarToast(
                              context,
                              'Selecione uma van primeiro.',
                              erro: true,
                            );
                            return;
                          }
                          context.go('/driver/home');
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
