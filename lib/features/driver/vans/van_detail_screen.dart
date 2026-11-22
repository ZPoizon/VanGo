import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/grupo.dart';
import 'package:vango/models/usuario.dart';

class VanDetailScreen extends StatefulWidget {
  const VanDetailScreen({super.key, required this.grupoId});

  final String grupoId;

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  GrupoVan? _grupo;
  List<Usuario> _solicitacoes = <Usuario>[];
  bool _carregando = true;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final store = StoreScope.read(context);
    final grupo = await store.buscarGrupoPorId(widget.grupoId);
    if (grupo == null) {
      if (mounted) {
        setState(() => _carregando = false);
        mostrarToast(context, 'Van não encontrada.', erro: true);
        context.pop();
      }
      return;
    }
    final selecao = await store.selecionarGrupo(widget.grupoId);
    final solicitacoes = selecao.sucesso
        ? await store.carregarSolicitacoes(widget.grupoId)
        : <Usuario>[];
    if (!mounted) return;
    setState(() {
      _grupo = grupo;
      _solicitacoes = solicitacoes;
      _carregando = false;
    });
  }

  Future<void> _gerarNovoCodigo() async {
    final confirmar = await confirmarAcao(
      context,
      titulo: 'Gerar novo código?',
      mensagem:
          'O código atual será invalidado. Alunos que tentarem entrar com '
          'o código antigo não conseguirão.',
      confirmarLabel: 'Gerar novo',
      destrutivo: true,
      icone: Icons.refresh_rounded,
    );
    if (!confirmar || !mounted) return;

    setState(() => _processando = true);
    final resultado = await StoreScope.read(context)
        .gerarNovoCodigoGrupo(widget.grupoId);
    if (!mounted) return;
    setState(() => _processando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso) await _carregar();
  }

  Future<void> _copiarCodigo(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    mostrarToast(context, 'Código copiado para a área de transferência.');
  }

  void _compartilharCodigo(GrupoVan grupo) {
    final texto =
        'Entre na van ${grupo.nome} no VanGo com o código ${grupo.codigo}.';
    mostrarToast(context, 'Compartilhe este texto: $texto');
  }

  Future<void> _decidir(Usuario aluno, bool aprovar) async {
    setState(() => _processando = true);
    final store = StoreScope.read(context);
    final resultado = aprovar
        ? await store.aprovarAluno(aluno.id)
        : await store.recusarAluno(aluno.id);
    if (!mounted) return;
    setState(() => _processando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final grupo = _grupo;
    return Scaffold(
      appBar: VangoAppBar(
        title: grupo?.nome ?? 'Detalhes da van',
        onBack: () => context.go('/driver/vans'),
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : grupo == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _CartaoResumo(grupo: grupo),
                  const SizedBox(height: AppSpacing.lg),
                  _CartaoCodigo(
                    grupo: grupo,
                    processando: _processando,
                    onCopiar: _copiarCodigo,
                    onCompartilhar: _compartilharCodigo,
                    onGerarNovo: _gerarNovoCodigo,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SecaoSolicitacoes(
                    solicitacoes: _solicitacoes,
                    processando: _processando,
                    onAprovar: (aluno) => _decidir(aluno, true),
                    onRecusar: (aluno) => _decidir(aluno, false),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  VangoButton(
                    label: 'Abrir painel desta van',
                    icon: Icons.dashboard_outlined,
                    onPressed: () => context.go('/driver/home'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({required this.grupo});

  final GrupoVan grupo;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  grupo.nome,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (grupo.trajeto.isNotEmpty) Text('Trajeto: ${grupo.trajeto}'),
          Text('Período: ${grupo.periodoOuPadrao}'),
          if (grupo.horarioSaida != null) Text('Saída: ${grupo.horarioSaida}'),
          if (grupo.observacoes != null) Text('Obs.: ${grupo.observacoes}'),
        ],
      ),
    );
  }
}

class _CartaoCodigo extends StatelessWidget {
  const _CartaoCodigo({
    required this.grupo,
    required this.processando,
    required this.onCopiar,
    required this.onCompartilhar,
    required this.onGerarNovo,
  });

  final GrupoVan grupo;
  final bool processando;
  final Future<void> Function(String codigo) onCopiar;
  final void Function(GrupoVan grupo) onCompartilhar;
  final Future<void> Function() onGerarNovo;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      color: AppColors.primarySoft,
      borderColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Código de entrada',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: SelectableText(
              grupo.codigo,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: VangoButton(
                  label: 'Copiar',
                  icon: Icons.copy_rounded,
                  height: 44,
                  onPressed: () => onCopiar(grupo.codigo),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: VangoButton(
                  label: 'Compartilhar',
                  icon: Icons.share_rounded,
                  height: 44,
                  variant: VangoButtonVariant.outline,
                  onPressed: () => onCompartilhar(grupo),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          VangoButton(
            label: 'Gerar novo código',
            icon: Icons.refresh_rounded,
            height: 44,
            variant: VangoButtonVariant.ghost,
            loading: processando,
            onPressed: onGerarNovo,
          ),
        ],
      ),
    );
  }
}

class _SecaoSolicitacoes extends StatelessWidget {
  const _SecaoSolicitacoes({
    required this.solicitacoes,
    required this.processando,
    required this.onAprovar,
    required this.onRecusar,
  });

  final List<Usuario> solicitacoes;
  final bool processando;
  final Future<void> Function(Usuario aluno) onAprovar;
  final Future<void> Function(Usuario aluno) onRecusar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SecaoRotulo('Solicitações pendentes'),
        const SizedBox(height: AppSpacing.sm),
        if (solicitacoes.isEmpty)
          const VangoCard(
            child: Text(
              'Nenhuma solicitação pendente nesta van.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          )
        else
          for (final aluno in solicitacoes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: VangoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aluno.nome,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: aluno.status.label,
                          tone: VangoTone.warning,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(aluno.email),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: VangoButton(
                            label: 'Aprovar',
                            icon: Icons.check_rounded,
                            variant: VangoButtonVariant.success,
                            height: 44,
                            loading: processando,
                            onPressed: () => onAprovar(aluno),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: VangoButton(
                            label: 'Recusar',
                            icon: Icons.close_rounded,
                            variant: VangoButtonVariant.danger,
                            height: 44,
                            loading: processando,
                            onPressed: () => onRecusar(aluno),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
