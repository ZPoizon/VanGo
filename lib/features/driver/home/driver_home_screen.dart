import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/store.dart';
import 'package:vango/features/driver/widgets/alteracoes_presenca_card.dart';
import 'package:vango/models/chamada.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _processando = false;

  Future<void> _executar(Future<void> Function() acao) async {
    if (_processando) return;
    setState(() => _processando = true);
    await acao();
    if (mounted) setState(() => _processando = false);
  }

  Future<void> _iniciarViagem(SentidoViagem sentido) async {
    final confirmar = await confirmarAcao(
      context,
      titulo: 'Iniciar viagem de ${sentido.label}?',
      mensagem:
          'A chamada já deve estar encerrada. Confirme o sentido para evitar '
          'avisar os alunos errados.',
      confirmarLabel: 'Iniciar ${sentido.label}',
      icone: Icons.play_circle_outline_rounded,
    );
    if (!confirmar || !mounted) return;

    await _executar(() async {
      final resultado = await StoreScope.read(context).iniciarViagem(sentido);
      if (!mounted) return;
      mostrarResultado(context, resultado);
    });
  }

  Future<void> _concluirViagem() async {
    final viagem = StoreScope.read(context).viagemAtual;
    if (viagem == null) return;
    final confirmar = await confirmarAcao(
      context,
      titulo: 'Concluir viagem de ${viagem.sentido.label}?',
      mensagem: viagem.sentido == SentidoViagem.ida
          ? 'A ida será registrada como concluída e a viagem de volta poderá '
                'ser iniciada em seguida.'
          : 'A volta será registrada como concluída e uma nova chamada poderá '
                'ser aberta.',
      confirmarLabel: 'Concluir viagem',
      icone: Icons.check_circle_outline_rounded,
    );
    if (!confirmar || !mounted) return;

    await _executar(() async {
      final resultado = await StoreScope.read(context).encerrarViagem();
      if (!mounted) return;
      mostrarResultado(context, resultado);
    });
  }

  Future<void> _cancelarChamada() async {
    final chamada = StoreScope.read(context).chamadaAmanha;
    if (chamada == null) return;
    final motivo = await confirmarCancelamento(
      context,
      titulo: 'Cancelar chamada?',
      mensagem: 'A chamada será cancelada e os alunos ativos do grupo serão notificados.',
      confirmarLabel: 'Cancelar chamada',
    );
    if (motivo == null || !mounted) return;

    await _executar(() async {
      final resultado = await StoreScope.read(context)
          .cancelarChamada(motivo: motivo.isEmpty ? null : motivo);
      if (!mounted) return;
      mostrarResultado(context, resultado);
    });
  }

  Future<void> _cancelarViagem() async {
    final viagem = StoreScope.read(context).viagemAtual;
    if (viagem == null) return;
    final motivo = await confirmarCancelamento(
      context,
      titulo: 'Cancelar viagem de ${viagem.sentido.label}?',
      mensagem:
          'A viagem em andamento será cancelada e os alunos serão notificados.',
      confirmarLabel: 'Cancelar viagem',
    );
    if (motivo == null || !mounted) return;

    await _executar(() async {
      final resultado = await StoreScope.read(context)
          .cancelarViagem(motivo: motivo.isEmpty ? null : motivo);
      if (!mounted) return;
      mostrarResultado(context, resultado);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final motorista = store.usuarioAtual;
    if (motorista == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _CabecalhoMotorista(
              motorista: motorista,
              onPerfil: () => context.push('/driver/profile'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(height: AppSpacing.lg),
            _CartaoOperacao(store: store),
            if (store.notificacoesResposta.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AlteracoesPresencaCard(notificacoes: store.notificacoesResposta),
            ],
            const SizedBox(height: AppSpacing.md),
            _AcoesOperacao(
              store: store,
              processando: _processando,
              onAbrir: () => _executar(() async {
                final resultado = await StoreScope.read(context).abrirChamada();
                if (!context.mounted) return;
                mostrarResultado(context, resultado);
              }),
              onEncerrar: () => _executar(() async {
                final resultado = await StoreScope.read(context)
                    .encerrarChamada();
                if (!context.mounted) return;
                mostrarResultado(context, resultado);
              }),
              onCancelarChamada: _cancelarChamada,
              onIniciarIda: () => _iniciarViagem(SentidoViagem.ida),
              onIniciarVolta: () => _iniciarViagem(SentidoViagem.volta),
              onConcluirViagem: _concluirViagem,
              onCancelarViagem: _cancelarViagem,
            ),
            const SizedBox(height: AppSpacing.lg),
            _MenuMotorista(
              onVans: () => context.push('/driver/vans'),
              onLista: () => context.push('/driver/daily-list'),
              onAlunos: () => context.push('/driver/students'),
              onHistorico: () => context.push('/driver/history'),
              onPerfil: () => context.push('/driver/profile'),
              onSair: () async {
                await StoreScope.read(context).sair();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                store.modoDemo
                    ? 'VanGo · modo demonstração · dados em memória'
                    : 'VanGo · conectado ao Firebase',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoMotorista extends StatelessWidget {
  const _CabecalhoMotorista({required this.motorista, required this.onPerfil});

  final Usuario motorista;
  final VoidCallback onPerfil;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontSize: 26,
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
        VangoAvatar(
          nome: motorista.nome,
          fotoUrl: motorista.fotoUrl,
          onTap: onPerfil,
        ),
      ],
    );
  }
}

/// Resume o que já aconteceu na chamada/viagem ativa sem consultar dados de
/// outras vans. Usado pelo cartão de estado e pelas ações operacionais.
class _EstadoViagens {
  const _EstadoViagens({
    required this.idaConcluida,
    required this.voltaConcluida,
    required this.cancelada,
  });

  factory _EstadoViagens.de(VanGoStore store, String? chamadaId) {
    final id =
        chamadaId ??
        (store.historico.isEmpty ? null : store.historico.first.chamadaId);
    final doServico = id == null
        ? <Viagem>[]
        : store.historico.where((viagem) => viagem.chamadaId == id).toList();
    return _EstadoViagens(
      idaConcluida: doServico.any(
        (viagem) =>
            viagem.sentido == SentidoViagem.ida && viagem.concluida,
      ),
      voltaConcluida: doServico.any(
        (viagem) =>
            viagem.sentido == SentidoViagem.volta && viagem.concluida,
      ),
      cancelada:
          store.chamadaAmanha?.cancelada == true ||
          doServico.any((viagem) => viagem.cancelada),
    );
  }

  final bool idaConcluida;
  final bool voltaConcluida;
  final bool cancelada;

  bool get operacaoConcluida => voltaConcluida;
  bool get podeIniciarVolta => idaConcluida && !voltaConcluida && !cancelada;
}

class _CartaoOperacao extends StatelessWidget {
  const _CartaoOperacao({required this.store});

  final VanGoStore store;

  @override
  Widget build(BuildContext context) {
    final chamada = store.chamadaAmanha;
    final viagem = store.viagemAtual;
    final emViagem = viagem?.status == StatusViagem.emAndamento;
    final estado = _EstadoViagens.de(store, chamada?.id);

    return VangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(
                cor: emViagem
                    ? AppColors.accent
                    : estado.operacaoConcluida
                    ? AppColors.success
                    : chamada?.aberta == true
                    ? AppColors.success
                    : chamada?.status == StatusChamada.cancelada ||
                            estado.cancelada
                    ? AppColors.error
                    : AppColors.muted,
              ),
              const SizedBox(width: 6),
              const Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              if (emViagem)
                StatusChip.viagem(viagem!.status, compact: true)
              else if (estado.operacaoConcluida)
                const StatusChip(
                  label: 'Concluída',
                  tone: VangoTone.success,
                  icon: Icons.check_circle_outline_rounded,
                  compact: true,
                )
              else if (estado.cancelada)
                const StatusChip(
                  label: 'Cancelada',
                  tone: VangoTone.error,
                  icon: Icons.cancel_outlined,
                  compact: true,
                )
              else if (chamada != null)
                StatusChip.chamada(chamada.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            emViagem
                ? 'Viagem de ${viagem!.sentido.label.toLowerCase()} em andamento'
                : estado.operacaoConcluida
                ? 'Operação concluída com sucesso'
                : chamada == null
                ? 'Nenhuma chamada aberta'
                : chamada.aberta
                ? 'Chamada aberta para amanhã'
                : chamada.status == StatusChamada.cancelada
                ? 'Chamada cancelada'
                : estado.cancelada
                ? 'Viagem cancelada'
                : estado.idaConcluida
                ? 'Ida concluída · volta pendente'
                : 'Chamada encerrada',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            emViagem
                ? 'Iniciada às ${formatarHoraTexto(viagem!.iniciadaEm == null ? null : formatarHora(viagem.iniciadaEm!))} · ${viagem.totalConfirmados} aluno(s) no sentido'
                : estado.operacaoConcluida
                ? 'Ida e volta registradas no histórico. Uma nova chamada já pode ser aberta.'
                : chamada == null
                ? 'Abra a chamada para receber as respostas de amanhã.'
                : chamada.status == StatusChamada.cancelada
                ? (chamada.motivoCancelamento != null &&
                          chamada.motivoCancelamento!.isNotEmpty
                      ? 'Motivo: ${chamada.motivoCancelamento}'
                      : 'Serviço de ${formatarDataCurta(chamada.dataServico)} cancelado.')
                : estado.cancelada
                ? 'A viagem foi cancelada e registrada no histórico.'
                : estado.idaConcluida
                ? 'A viagem de ida foi concluída. Inicie a volta para finalizar a operação.'
                : 'Serviço de ${formatarDataCurta(chamada.dataServico)} · '
                      '${store.totalRespostas} de ${store.presencasChamada.length} responderam',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (chamada != null &&
              !emViagem &&
              !estado.operacaoConcluida &&
              !estado.cancelada &&
              chamada.status != StatusChamada.cancelada) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _MiniContagem(
                    valor: '${store.totalRespostas}',
                    rotulo: 'responderam',
                    tone: VangoTone.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MiniContagem(
                    valor:
                        '${store.presencasChamada.length - store.totalRespostas}',
                    rotulo: 'pendentes',
                    tone: VangoTone.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MiniContagem(
                    valor: '${store.presencasChamada.length}',
                    rotulo: 'alunos ativos',
                    tone: VangoTone.info,
                  ),
                ),
              ],
            ),
          ],
          if (emViagem) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _MiniContagem(
                    valor: '${viagem!.totalConfirmados}',
                    rotulo: 'no sentido',
                    tone: VangoTone.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MiniContagem(
                    valor: '${viagem.totalEstouIndo}',
                    rotulo: 'estou indo',
                    tone: VangoTone.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MiniContagem(
                    valor:
                        '${viagem.confirmacoes.where((c) => c.avisadoEm != null).length}',
                    rotulo: 'avisados',
                    tone: VangoTone.accent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AcoesOperacao extends StatelessWidget {
  const _AcoesOperacao({
    required this.store,
    required this.processando,
    required this.onAbrir,
    required this.onEncerrar,
    required this.onCancelarChamada,
    required this.onIniciarIda,
    required this.onIniciarVolta,
    required this.onConcluirViagem,
    required this.onCancelarViagem,
  });

  final VanGoStore store;
  final bool processando;
  final VoidCallback onAbrir;
  final VoidCallback onEncerrar;
  final VoidCallback onCancelarChamada;
  final VoidCallback onIniciarIda;
  final VoidCallback onIniciarVolta;
  final VoidCallback onConcluirViagem;
  final VoidCallback onCancelarViagem;

  @override
  Widget build(BuildContext context) {
    final chamada = store.chamadaAmanha;
    final viagem = store.viagemAtual;
    final emViagem = viagem?.status == StatusViagem.emAndamento;
    final estado = _EstadoViagens.de(store, chamada?.id);

    if (emViagem) {
      return Column(
        children: [
          VangoButton(
            label: 'Concluir viagem',
            icon: Icons.check_circle_outline_rounded,
            variant: VangoButtonVariant.success,
            loading: processando,
            onPressed: onConcluirViagem,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: VangoButton(
                  label: 'Estou chegando',
                  icon: Icons.notifications_active_outlined,
                  variant: VangoButtonVariant.accent,
                  height: 48,
                  onPressed: () =>
                      context.push('/driver/trips/${viagem!.id}/notify'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: VangoButton(
                  label: 'Ver lista',
                  icon: Icons.group_outlined,
                  variant: VangoButtonVariant.outline,
                  height: 48,
                  onPressed: () => context.push('/driver/daily-list'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          VangoButton(
            label: 'Cancelar viagem',
            icon: Icons.cancel_outlined,
            variant: VangoButtonVariant.ghost,
            loading: processando,
            onPressed: onCancelarViagem,
          ),
        ],
      );
    }

    if (chamada == null ||
        chamada.status == StatusChamada.cancelada ||
        estado.operacaoConcluida ||
        estado.cancelada) {
      return Column(
        children: [
          if (estado.operacaoConcluida) ...[
            const Text(
              'Ida e volta concluídas com sucesso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.success),
            ),
            const SizedBox(height: AppSpacing.xs),
          ] else if (estado.cancelada) ...[
            const Text(
              'Viagem cancelada. O serviço foi registrado no histórico.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          VangoButton(
            label: 'Abrir chamada de amanhã',
            icon: Icons.campaign_outlined,
            loading: processando,
            onPressed: onAbrir,
          ),
        ],
      );
    }

    if (chamada.aberta) {
      return Column(
        children: [
          VangoButton(
            label: 'Ver respostas',
            icon: Icons.fact_check_outlined,
            onPressed: () => context.push('/driver/daily-list'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: VangoButton(
                  label: 'Encerrar chamada',
                  icon: Icons.lock_outline_rounded,
                  variant: VangoButtonVariant.danger,
                  loading: processando,
                  onPressed: onEncerrar,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: VangoButton(
                  label: 'Cancelar chamada',
                  icon: Icons.cancel_outlined,
                  variant: VangoButtonVariant.outline,
                  loading: processando,
                  onPressed: onCancelarChamada,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          estado.podeIniciarVolta
              ? 'Ida concluída. Inicie a volta para finalizar a operação.'
              : 'Chamada encerrada. Inicie a viagem de ida.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        VangoButton(
          label: estado.podeIniciarVolta ? 'Iniciar VOLTA' : 'Iniciar IDA',
          icon: estado.podeIniciarVolta
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          loading: processando,
          onPressed: estado.podeIniciarVolta ? onIniciarVolta : onIniciarIda,
        ),
        const SizedBox(height: AppSpacing.xs),
        VangoButton(
          label: 'Cancelar chamada',
          icon: Icons.cancel_outlined,
          variant: VangoButtonVariant.ghost,
          loading: processando,
          onPressed: onCancelarChamada,
        ),
      ],
    );
  }
}

class _MiniContagem extends StatelessWidget {
  const _MiniContagem({
    required this.valor,
    required this.rotulo,
    required this.tone,
  });

  final String valor;
  final String rotulo;
  final VangoTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: tone.foreground),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
    );
  }
}

class _MenuMotorista extends StatelessWidget {
  const _MenuMotorista({
    required this.onVans,
    required this.onLista,
    required this.onAlunos,
    required this.onHistorico,
    required this.onPerfil,
    required this.onSair,
  });

  final VoidCallback onVans;
  final VoidCallback onLista;
  final VoidCallback onAlunos;
  final VoidCallback onHistorico;
  final VoidCallback onPerfil;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _ItemMenu(
            icone: Icons.directions_bus_rounded,
            titulo: 'Minhas vans',
            subtitulo: 'Criar e alternar grupos',
            onTap: onVans,
          ),
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.group_outlined,
            titulo: 'Lista do dia',
            subtitulo: 'Confirmações, avisos e liberações',
            onTap: onLista,
          ),
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.people_alt_outlined,
            titulo: 'Alunos',
            subtitulo: 'Cadastros, turnos e pendências',
            onTap: onAlunos,
          ),
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.history_rounded,
            titulo: 'Histórico',
            subtitulo: 'Viagens encerradas por período',
            onTap: onHistorico,
          ),
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.person_outline_rounded,
            titulo: 'Meu perfil',
            subtitulo: 'Dados, foto e senha',
            onTap: onPerfil,
          ),
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.logout_rounded,
            titulo: 'Sair',
            destrutivo: true,
            onTap: onSair,
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icone,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
    this.destrutivo = false,
  });

  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;
  final bool destrutivo;

  @override
  Widget build(BuildContext context) {
    // Material próprio mantém o fundo e o ink do ListTile acima do card.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icone,
          color: destrutivo ? AppColors.error : AppColors.primary,
        ),
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: destrutivo ? AppColors.error : AppColors.text,
          ),
        ),
        subtitle: subtitulo == null
            ? null
            : Text(
                subtitulo!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ),
    );
  }
}
