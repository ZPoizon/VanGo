import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/store.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/features/driver/widgets/solicitacoes_entrada_card.dart';
import 'package:vango/models/grupo.dart';
import 'package:vango/models/notificacao_entrada.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';

/// Painel geral do motorista. Não é o painel operacional de uma van: a
/// operação (chamada/alunos/viagem) continua em `/driver/home`, sempre da van
/// selecionada. Aqui o motorista vê o conjunto das suas vans e acessa cada uma.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  List<GrupoVan> _grupos = <GrupoVan>[];
  Map<String, int> _alunosPorGrupo = <String, int>{};
  Map<String, int?> _pendentesPorGrupo = <String, int?>{};
  bool _carregando = true;
  String? _erro;

  late final VanGoStore _store;

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    // A criação de van pode terminar com um `go` para esta mesma rota: o
    // Future do push não completa. O listener garante que o resumo reflita a
    // quantidade real de vans sem depender da pilha de navegação.
    _store.addListener(_aoStoreMudar);
    _carregar();
  }

  @override
  void dispose() {
    _store.removeListener(_aoStoreMudar);
    super.dispose();
  }

  void _aoStoreMudar() {
    if (!mounted || _carregando) return;
    if (_store.meusGrupos.length != _grupos.length) {
      _carregar();
      return;
    }
    // Aprovação/recusa e novas solicitações alteram a contagem reativa: o
    // resumo é recalculado sem depender de um refresh manual.
    final atual = _store.pendentesPorGrupo;
    final mudou = atual.entries.any(
      (entrada) => entrada.value != (_pendentesPorGrupo[entrada.key] ?? -1),
    );
    if (mudou) _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final store = StoreScope.read(context);
    try {
      final grupos = await store.carregarMeusGrupos();
      final alunos = <String, int>{};
      final pendentes = <String, int?>{};
      for (final grupo in grupos) {
        // Cada consulta é filtrada pelo grupo. Nenhuma lista global é lida.
        alunos[grupo.id] = await store.contarAlunosGrupo(grupo.id);
        pendentes[grupo.id] = await store.contarSolicitacoesGrupo(grupo.id);
      }
      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _alunosPorGrupo = alunos;
        _pendentesPorGrupo = pendentes;
        _erro = store.erro;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os dados das suas vans.';
        _carregando = false;
      });
    }
  }

  Future<void> _criarVan() async {
    // Retorno explícito: criar van não pode travar a navegação nem deixar o
    // dashboard com a lista antiga. A rota volta e recarrega os dados reais.
    await context.push('/driver/vans/new?retorno=/driver/dashboard');
    if (mounted) await _carregar();
  }

  Future<void> _abrirPainel(GrupoVan grupo) async {
    final resultado = await StoreScope.read(context).selecionarGrupo(grupo.id);
    if (!mounted) return;
    if (!resultado.sucesso) {
      mostrarToast(
        context,
        resultado.mensagem ?? 'Não foi possível abrir o painel desta van.',
        erro: true,
      );
      return;
    }
    context.go('/driver/home');
  }

  Future<void> _administrar(GrupoVan grupo) async {
    await context.push('/driver/vans/${grupo.id}');
    if (mounted) await _carregar();
  }

  /// Abre exatamente a van e a solicitação do aviso tocado.
  Future<void> _abrirSolicitacao(NotificacaoEntrada aviso) async {
    final alunoId = Uri.encodeComponent(aviso.solicitacaoId);
    await context.push('/driver/vans/${aviso.grupoId}?solicitacaoId=$alunoId');
    if (mounted) await _carregar();
  }

  /// Usa a contagem reativa quando o listener já carregou as solicitações;
  /// mantém a contagem consultada na abertura como fallback.
  int? _pendente(VanGoStore store, String grupoId) =>
      store.pendentesPorGrupo[grupoId] ?? _pendentesPorGrupo[grupoId];

  Future<void> _sair() async {
    await StoreScope.read(context).sair();
    if (!mounted) return;
    context.go('/login');
  }

  double _larguraColuna(double util, int colunas) =>
      colunas <= 1
          ? util
          : (util - AppSpacing.md * (colunas - 1)) / colunas;

  @override
  Widget build(BuildContext context) {
    final motorista = StoreScope.of(context).usuarioAtual;
    if (motorista == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: VangoAppBar(
        title: 'Painel do motorista',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/driver/profile'),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/driver/profile'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _sair,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final util = constraints.maxWidth > 1200
                ? 1200.0
                : constraints.maxWidth;
            final colunas = util >= 1000 ? 3 : util >= 680 ? 2 : 1;
            final larguraColuna = _larguraColuna(util, colunas);
            final colunasMetrica = util >= 900 ? 4 : util >= 520 ? 2 : 1;
            final larguraMetrica = _larguraColuna(util, colunasMetrica);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: AnimatedBuilder(
                    animation: StoreScope.of(context),
                    builder: (context, _) {
                      final store = StoreScope.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Cabecalho(
                            motorista: motorista,
                            onPerfil: () => context.push('/driver/profile'),
                            onSair: _sair,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_carregando)
                            const CarregandoView(
                              mensagem: 'Carregando seu painel…',
                            )
                          else if (_grupos.isEmpty)
                            _estadoInicial(util)
                          else ...[
                            if (_erro != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Text(
                                  _erro!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            _cartaoResumo(
                              store: store,
                              largura: larguraMetrica,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (store.notificacoesEntrada.isNotEmpty) ...[
                              SolicitacoesEntradaCard(
                                notificacoes: store.notificacoesEntrada,
                                onAbrir: _abrirSolicitacao,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            _cartaoOperacao(store: store, grupos: _grupos),
                            const SecaoRotulo('Acesso rápido'),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.md,
                              children: [
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.directions_bus_rounded,
                                    titulo: 'Minhas vans',
                                    subtitulo: 'Gerencie rotas, códigos e alunos',
                                    onTap: () => context.push('/driver/vans'),
                                  ),
                                ),
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.add_rounded,
                                    titulo: 'Criar nova van',
                                    subtitulo: 'Adicione outra van à sua frota',
                                    onTap: _criarVan,
                                  ),
                                ),
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.how_to_reg_rounded,
                                    titulo: 'Solicitações de entrada',
                                    subtitulo: 'Analise quem quer entrar nas vans',
                                    onTap: () =>
                                        context.push('/driver/requests'),
                                  ),
                                ),
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.people_outline_rounded,
                                    titulo: 'Alunos',
                                    subtitulo: 'Veja os alunos da van ativa',
                                    onTap: () => context.push('/driver/students'),
                                  ),
                                ),
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.history_rounded,
                                    titulo: 'Histórico',
                                    subtitulo: 'Consulte viagens anteriores',
                                    onTap: () => context.push('/driver/history'),
                                  ),
                                ),
                                SizedBox(
                                  width: larguraColuna,
                                  child: _AcaoRapida(
                                    icon: Icons.person_outline_rounded,
                                    titulo: 'Meu perfil',
                                    subtitulo: 'Dados, senha e foto de perfil',
                                    onTap: () => context.push('/driver/profile'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SecaoRotulo('Minhas vans'),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.md,
                              children: [
                                for (final grupo in _grupos)
                                  SizedBox(
                                    width: larguraColuna,
                                    child: _CartaoVan(
                                      grupo: grupo,
                                      alunos: _alunosPorGrupo[grupo.id] ?? 0,
                                      pendentes: _pendente(store, grupo.id),
                                      onAdministrar: () => _administrar(grupo),
                                      onPainel: () => _abrirPainel(grupo),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Center(
                            child: Text(
                              store.modoDemo
                                  ? 'VanGo · modo demonstração · dados em memória'
                                  : 'VanGo · conectado ao Firebase',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _estadoInicial(double largura) {
    if (_erro != null) {
      return SizedBox(
        width: largura,
        child: EstadoView(
          titulo: 'Não foi possível carregar o painel',
          mensagem: _erro!,
          tipo: EstadoTipo.erro,
          acaoLabel: 'Tentar novamente',
          onAcao: _carregar,
        ),
      );
    }
    return SizedBox(
      width: largura,
      child: EstadoView(
        titulo: 'Você ainda não tem uma van',
        mensagem:
            'Crie sua primeira van para gerar um código de entrada e começar '
            'a gerenciar alunos e chamadas.',
        acaoLabel: 'Criar minha primeira van',
        onAcao: _criarVan,
      ),
    );
  }

  Widget _cartaoResumo({
    required VanGoStore store,
    required double largura,
  }) {
    final totalAlunos = _alunosPorGrupo.values.fold<int>(
      0,
      (total, valor) => total + valor,
    );
    final pendentes = <int?>[
      for (final grupo in _grupos) _pendente(store, grupo.id),
    ];
    final pendenteIndisponivel = pendentes.any((valor) => valor == null);
    final totalPendentes = pendentes.fold<int>(
      0,
      (total, valor) => total + (valor ?? 0),
    );

    final chamada = store.chamadaAmanha;
    final viagem = store.viagemAtual;
    final operacao = viagem?.status == StatusViagem.emAndamento
        ? 'Viagem em andamento'
        : chamada?.aberta == true
        ? 'Chamada aberta'
        : 'Nenhuma operação ativa';

    final metricas = <Widget>[
      SizedBox(
        width: largura,
        child: _Metrica(
          titulo: 'Vans cadastradas',
          valor: '${_grupos.length}',
          icone: Icons.directions_bus_rounded,
        ),
      ),
      SizedBox(
        width: largura,
        child: _Metrica(
          titulo: 'Alunos ativos',
          valor: '$totalAlunos',
          icone: Icons.people_outline_rounded,
        ),
      ),
      SizedBox(
        width: largura,
        child: _Metrica(
          titulo: 'Solicitações pendentes',
          valor: pendenteIndisponivel ? 'indisponível' : '$totalPendentes',
          icone: Icons.how_to_reg_rounded,
          destaque: !pendenteIndisponivel && totalPendentes > 0,
        ),
      ),
      SizedBox(
        width: largura,
        child: _Metrica(
          titulo: 'Operação',
          valor: operacao,
          icone: Icons.play_circle_outline_rounded,
          pequeno: true,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SecaoRotulo('Resumo'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: metricas,
        ),
      ],
    );
  }

  Widget _cartaoOperacao({
    required VanGoStore store,
    required List<GrupoVan> grupos,
  }) {
    final chamada = store.chamadaAmanha;
    final viagem = store.viagemAtual;
    final emViagem = viagem?.status == StatusViagem.emAndamento;
    final chamadaAberta = chamada?.aberta == true;
    if (!emViagem && !chamadaAberta) return const SizedBox.shrink();

    final grupoId = emViagem ? viagem!.grupoId : chamada!.grupoId;
    final grupo = grupos.cast<GrupoVan?>().firstWhere(
      (item) => item?.id == grupoId,
      orElse: () => null,
    );
    final titulo = emViagem
        ? 'Viagem de ${viagem!.sentido.label.toLowerCase()} em andamento'
        : 'Chamada aberta para amanhã';
    final descricao = emViagem
        ? 'A operação em andamento pertence à van ${grupo?.nome ?? 'selecionada'}.'
        : 'As respostas de presença estão sendo recebidas.';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: VangoCard(
        color: AppColors.accentSoft,
        borderColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(descricao, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            if (grupo != null) ...[
              const SizedBox(height: AppSpacing.sm),
              VangoButton(
                label: 'Abrir painel da van',
                icon: Icons.dashboard_outlined,
                variant: VangoButtonVariant.outline,
                expand: false,
                height: 44,
                onPressed: () => _abrirPainel(grupo),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.motorista,
    required this.onPerfil,
    required this.onSair,
  });

  final Usuario motorista;
  final VoidCallback onPerfil;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      color: AppColors.primarySoft,
      borderColor: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOTORISTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Olá, ${motorista.primeiroNome}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatarDataLonga(DateTime.now()),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              VangoAvatar(
                nome: motorista.nome,
                fotoUrl: motorista.fotoUrl,
                radius: 28,
                onTap: onPerfil,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              VangoButton(
                label: 'Meu perfil',
                icon: Icons.person_outline_rounded,
                variant: VangoButtonVariant.outline,
                expand: false,
                height: 44,
                onPressed: onPerfil,
              ),
              VangoButton(
                label: 'Sair da conta',
                icon: Icons.logout_rounded,
                variant: VangoButtonVariant.ghost,
                expand: false,
                height: 44,
                onPressed: onSair,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.titulo,
    required this.valor,
    required this.icone,
    this.destaque = false,
    this.pequeno = false,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final bool destaque;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      color: destaque ? AppColors.accentSoft : AppColors.surface,
      borderColor: destaque ? AppColors.accent : AppColors.divider,
      child: Row(
        children: [
          Icon(icone, color: destaque ? AppColors.accent : AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: pequeno ? 14 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcaoRapida extends StatelessWidget {
  const _AcaoRapida({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _CartaoVan extends StatelessWidget {
  const _CartaoVan({
    required this.grupo,
    required this.alunos,
    required this.pendentes,
    required this.onAdministrar,
    required this.onPainel,
  });

  final GrupoVan grupo;
  final int alunos;
  final int? pendentes;
  final VoidCallback onAdministrar;
  final VoidCallback onPainel;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grupo.nome,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (grupo.trajeto.isNotEmpty)
            InfoLinha(icon: Icons.route_outlined, texto: grupo.trajeto),
          InfoLinha(
            icon: Icons.schedule_outlined,
            texto: 'Período: ${grupo.periodoOuPadrao}',
          ),
          InfoLinha(
            icon: Icons.people_outline_rounded,
            texto: '$alunos alunos ativos',
          ),
          InfoLinha(
            icon: Icons.how_to_reg_rounded,
            texto: pendentes == null
                ? 'Solicitações: indisponível'
                : '$pendentes solicitações pendentes',
            cor: pendentes == null ? AppColors.muted : AppColors.text,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              VangoButton(
                label: 'Administrar',
                icon: Icons.tune_rounded,
                variant: VangoButtonVariant.outline,
                expand: false,
                height: 44,
                onPressed: onAdministrar,
              ),
              VangoButton(
                label: 'Abrir painel',
                icon: Icons.dashboard_outlined,
                expand: false,
                height: 44,
                onPressed: onPainel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
