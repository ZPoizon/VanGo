import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/chamada.dart';
import 'package:vango/models/presenca.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';
import 'package:vango/core/store.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final usuario = store.usuarioAtual;
    if (usuario == null) return const SizedBox.shrink();

    final grupoId = usuario.grupoId?.trim() ?? '';
    final semGrupo = grupoId.isEmpty;
    final aprovado = usuario.podeAcessar;
    final mostrarSituacaoGrupo = !aprovado || semGrupo;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _CabecalhoAluno(
                usuario: usuario,
                onPerfil: () => context.push('/student/profile'),
              ),
              if (mostrarSituacaoGrupo) ...[
                const SizedBox(height: AppSpacing.lg),
                _SituacaoGrupoCard(store: store, usuario: usuario),
              ],
              if (aprovado) ...[
                const SizedBox(height: AppSpacing.lg),
                _AvisoChegadaCard(store: store),
                const SizedBox(height: AppSpacing.md),
                _ChamadaAmanhaCard(store: store, usuario: usuario),
                const SizedBox(height: AppSpacing.md),
                _LiberacaoCard(store: store, usuario: usuario),
                const SizedBox(height: AppSpacing.md),
                _HorariosCard(store: store),
              ],
              const SizedBox(height: AppSpacing.md),
              _MenuAluno(
                aprovado: aprovado,
                onPerfil: () => context.push('/student/profile'),
                onQuemVaiHoje: () => context.push('/student/today'),
                onPadrao: () => context.push('/student/schedule'),
                onNotificacoes: () => _abrirNotificacoes(context, store),
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
      ),
    );
  }

  void _abrirNotificacoes(BuildContext context, VanGoStore store) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notificações',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Avisos enviados pelo motorista da sua van.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            const EstadoView(
              titulo: 'Nenhum aviso por aqui',
              mensagem: 'Quando o motorista enviar avisos, eles aparecerão nas notificações do seu celular.',
              tipo: EstadoTipo.vazio,
            ),
          ],
        ),
      ),
    );
  }
}

class _CabecalhoAluno extends StatelessWidget {
  const _CabecalhoAluno({required this.usuario, required this.onPerfil});

  final Usuario usuario;
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
                'ALUNO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Olá, ${usuario.primeiroNome}',
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
          nome: usuario.nome,
          fotoUrl: usuario.fotoUrl,
          onTap: onPerfil,
        ),
      ],
    );
  }
}

/// Cartão de destaque da Home enquanto não há participação aprovada.
///
/// Também mantém o aluno informado sobre o nome da van solicitada, o motivo de
/// uma recusa (quando houver) e a possibilidade de tentar novamente.
class _SituacaoGrupoCard extends StatefulWidget {
  const _SituacaoGrupoCard({required this.store, required this.usuario});

  final VanGoStore store;
  final Usuario usuario;

  @override
  State<_SituacaoGrupoCard> createState() => _SituacaoGrupoCardState();
}

class _SituacaoGrupoCardState extends State<_SituacaoGrupoCard> {
  String? _nomeVan;

  @override
  void initState() {
    super.initState();
    _carregarNomeVan();
  }

  @override
  void didUpdateWidget(covariant _SituacaoGrupoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.grupoId != widget.usuario.grupoId) {
      _carregarNomeVan();
    }
  }

  Future<void> _carregarNomeVan() async {
    final grupoId = widget.usuario.grupoId?.trim();
    if (grupoId == null || grupoId.isEmpty) {
      if (mounted) setState(() => _nomeVan = null);
      return;
    }
    final grupo = await widget.store.buscarGrupoPorId(grupoId);
    if (!mounted) return;
    setState(() => _nomeVan = grupo?.nome);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final grupoId = usuario.grupoId?.trim() ?? '';
    final recusado = usuario.status == StatusConta.recusado;
    final pendente =
        usuario.status == StatusConta.pendente && grupoId.isNotEmpty;

    late final String titulo;
    late final String descricao;
    late final Color cor;
    late final Color corFundo;
    late final IconData icone;
    Widget? status;
    String? acao;

    if (recusado) {
      titulo = 'Solicitação recusada';
      descricao = (usuario.motivoRecusa?.trim().isNotEmpty ?? false)
          ? 'Motivo: ${usuario.motivoRecusa!.trim()}'
          : 'O motorista não aprovou esta solicitação. Você pode tentar '
                'novamente com outro código.';
      cor = AppColors.error;
      corFundo = AppColors.errorSoft;
      icone = Icons.cancel_outlined;
      status = const StatusChip(
        label: 'Recusada',
        tone: VangoTone.error,
        compact: true,
      );
      acao = 'Tentar novamente';
    } else if (pendente) {
      titulo = _nomeVan ?? 'Van solicitada';
      descricao =
          'Seu acesso será liberado automaticamente quando o '
          'motorista aprovar a solicitação.';
      cor = AppColors.warning;
      corFundo = AppColors.warningSoft;
      icone = Icons.hourglass_top_rounded;
      status = const StatusChip(
        label: 'Aguardando aprovação',
        tone: VangoTone.warning,
        icon: Icons.hourglass_top_rounded,
        compact: true,
      );
    } else {
      titulo = 'Você ainda não está em uma van';
      descricao =
          'Informe o código de seis dígitos fornecido pelo motorista '
          'para solicitar entrada em um grupo.';
      cor = AppColors.accent;
      corFundo = AppColors.accentSoft;
      icone = Icons.directions_bus_outlined;
      acao = 'Entrar em um grupo';
    }

    return VangoCard(
      color: corFundo,
      borderColor: cor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icone, color: AppColors.text, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              ?status,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            descricao,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (acao != null) ...[
            const SizedBox(height: AppSpacing.md),
            VangoButton(
              label: acao,
              icon: Icons.group_add_outlined,
              onPressed: () => context.push('/signup/enter-group'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvisoChegadaCard extends StatelessWidget {
  const _AvisoChegadaCard({required this.store});

  final VanGoStore store;

  @override
  Widget build(BuildContext context) {
    final viagem = store.viagemAtual;
    final ativa = viagem?.status == StatusViagem.emAndamento;
    final ultimaViagemCancelada =
        store.historico.isNotEmpty &&
            store.historico.first.status == StatusViagem.cancelada &&
            !ativa
        ? store.historico.first
        : null;
    final destino = ativa ? viagem!.id : '';

    if (ultimaViagemCancelada != null) {
      return VangoCard(
        color: AppColors.errorSoft,
        borderColor: AppColors.error,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viagem de ${ultimaViagemCancelada.sentido.label.toLowerCase()} cancelada',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ultimaViagemCancelada.motivoCancelamento != null &&
                            ultimaViagemCancelada.motivoCancelamento!.isNotEmpty
                        ? 'Motivo: ${ultimaViagemCancelada.motivoCancelamento}'
                        : 'A viagem foi cancelada pelo motorista.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return VangoCard(
      color: AppColors.accentSoft,
      borderColor: AppColors.accent,
      onTap: () => context.push('/student/arrival/$destino'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ativa ? 'A van está chegando!' : 'Avisos da van',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ativa
                      ? 'Toque para confirmar que você está indo.'
                      : 'Nenhum aviso ativo. Toque para ver a prévia.',
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

/// Explica ao aluno qual estado bloqueia a alteração de presença.
String _motivoBloqueio(Chamada? chamada, Viagem? viagem) {
  if (chamada == null) return 'Respostas bloqueadas: não há chamada aberta.';
  if (viagem?.status == StatusViagem.emAndamento) {
    return 'Respostas bloqueadas: a viagem já começou.';
  }
  if (chamada.cancelada)
    return 'Respostas bloqueadas: a chamada foi cancelada.';
  if (!chamada.aberta) return 'Respostas bloqueadas: a chamada foi encerrada.';
  return 'Respostas indisponíveis no momento.';
}

class _ChamadaAmanhaCard extends StatelessWidget {
  const _ChamadaAmanhaCard({required this.store, required this.usuario});

  final VanGoStore store;
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final chamada = store.chamadaAmanha;
    final resposta = store.respostaDe(usuario.id);
    final bloqueada = store.respostaBloqueada;

    return VangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Chamada de amanhã',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (chamada != null)
                StatusChip.chamada(chamada.status, compact: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatarDataLonga(store.dataAmanha),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Divider(height: AppSpacing.lg),
          if (chamada == null) ...[
            const Text(
              'Nenhuma chamada aberta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aguarde o motorista abrir a chamada do próximo dia.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ] else if (chamada.status == StatusChamada.cancelada) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      chamada.motivoCancelamento != null &&
                              chamada.motivoCancelamento!.isNotEmpty
                          ? 'A chamada de amanhã foi cancelada pelo motorista.\nMotivo: ${chamada.motivoCancelamento}'
                          : 'A chamada de amanhã foi cancelada pelo motorista.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Como você vai?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                StatusChip.presenca(resposta.statusCombinado, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Opacity(
              opacity: bloqueada ? 0.55 : 1,
              child: IgnorePointer(
                ignoring: bloqueada,
                child: _SentidosResposta(
                  resposta: resposta,
                  onResponder: ({bool? ida, bool? volta}) async {
                    final resultado = await store.responderChamada(
                      ida: ida,
                      volta: volta,
                    );
                    if (!context.mounted) return;
                    mostrarResultado(context, resultado);
                  },
                ),
              ),
            ),
            if (bloqueada) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_clock_outlined,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _motivoBloqueio(chamada, store.viagemAtual),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Dois controles independentes: a confirmação da ida não altera a da volta.
class _SentidosResposta extends StatelessWidget {
  const _SentidosResposta({required this.resposta, required this.onResponder});

  final RespostaPresenca resposta;
  final void Function({bool? ida, bool? volta}) onResponder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinhaSentido(
          titulo: 'Ida',
          icone: Icons.arrow_upward_rounded,
          selecao: resposta.ida,
          onVai: () => onResponder(ida: true),
          onNaoVai: () => onResponder(ida: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LinhaSentido(
          titulo: 'Volta',
          icone: Icons.arrow_downward_rounded,
          selecao: resposta.volta,
          onVai: () => onResponder(volta: true),
          onNaoVai: () => onResponder(volta: false),
        ),
      ],
    );
  }
}

class _LinhaSentido extends StatelessWidget {
  const _LinhaSentido({
    required this.titulo,
    required this.icone,
    required this.selecao,
    required this.onVai,
    required this.onNaoVai,
  });

  final String titulo;
  final IconData icone;
  final RespostaSentido selecao;
  final VoidCallback onVai;
  final VoidCallback onNaoVai;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _OpcaoResposta(
                label: 'Vou',
                detalhe: 'confirmar $titulo'.toLowerCase(),
                icone: Icons.check_circle_outline_rounded,
                selecionado: selecao == RespostaSentido.vai,
                tone: VangoTone.success,
                onTap: onVai,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _OpcaoResposta(
                label: 'Não vou',
                detalhe: 'confirmar $titulo'.toLowerCase(),
                icone: Icons.cancel_outlined,
                selecionado: selecao == RespostaSentido.naoVai,
                tone: VangoTone.error,
                onTap: onNaoVai,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpcaoResposta extends StatelessWidget {
  const _OpcaoResposta({
    required this.label,
    required this.detalhe,
    required this.icone,
    required this.selecionado,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final String detalhe;
  final IconData icone;
  final bool selecionado;
  final VangoTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selecionado ? tone.background : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selecionado ? tone.foreground : AppColors.divider,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icone,
              size: 20,
              color: selecionado ? tone.foreground : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selecionado ? tone.foreground : AppColors.text,
                    ),
                  ),
                  Text(
                    detalhe,
                    style: TextStyle(
                      fontSize: 10,
                      color: selecionado ? tone.foreground : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiberacaoCard extends StatelessWidget {
  const _LiberacaoCard({required this.store, required this.usuario});

  final VanGoStore store;
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final resposta = store.respostaDe(usuario.id);
    final podeLiberar = resposta.volta == RespostaSentido.vai;
    final liberado = resposta.liberadoEm != null;

    return VangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Já saiu da aula?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Avise o motorista quando estiver liberado para a volta.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!podeLiberar)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Disponível apenas para quem confirmou a volta na chamada.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          else if (liberado) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Aviso enviado às ${formatarHora(resposta.liberadoEm!)}. '
                      'O motorista vê você no topo da lista de volta.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            VangoButton(
              label: 'Cancelar aviso',
              variant: VangoButtonVariant.ghost,
              height: 44,
              onPressed: () async {
                final resultado = await store.cancelarLiberacao();
                if (!context.mounted) return;
                mostrarResultado(context, resultado);
              },
            ),
          ] else
            VangoButton(
              label: 'Estou liberado',
              icon: Icons.waving_hand_outlined,
              variant: VangoButtonVariant.accent,
              height: 48,
              onPressed: () async {
                final confirmar = await confirmarAcao(
                  context,
                  titulo: 'Avisar que está liberado?',
                  mensagem:
                      'O motorista receberá um aviso para a viagem de volta.',
                  confirmarLabel: 'Estou liberado',
                  icone: Icons.waving_hand_outlined,
                );
                if (!confirmar || !context.mounted) return;
                final resultado = await store.liberarAluno();
                if (!context.mounted) return;
                mostrarResultado(context, resultado);
              },
            ),
        ],
      ),
    );
  }
}

class _HorariosCard extends StatelessWidget {
  const _HorariosCard({required this.store});

  final VanGoStore store;

  @override
  Widget build(BuildContext context) {
    final padrao = store.padraoDoDia(store.dataAmanha.weekday);
    return VangoCard(
      onTap: () => context.push('/student/schedule'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(Icons.schedule_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amanhã · ${nomeDiaSemana(store.dataAmanha.weekday)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Entrada ${formatarHoraTexto(padrao.entraAs)} · '
                  'Saída ${formatarHoraTexto(padrao.saiAs)}',
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

class _MenuAluno extends StatelessWidget {
  const _MenuAluno({
    required this.aprovado,
    required this.onPerfil,
    required this.onQuemVaiHoje,
    required this.onPadrao,
    required this.onNotificacoes,
    required this.onSair,
  });

  final bool aprovado;
  final VoidCallback onPerfil;
  final VoidCallback onQuemVaiHoje;
  final VoidCallback onPadrao;
  final VoidCallback onNotificacoes;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _ItemMenu(
            icone: Icons.person_outline_rounded,
            titulo: 'Meu perfil',
            subtitulo: 'Seus dados e senha',
            onTap: onPerfil,
          ),
          if (aprovado) ...[
            const Divider(height: 1, indent: AppSpacing.md),
            _ItemMenu(
              icone: Icons.groups_2_outlined,
              titulo: 'Quem vai hoje',
              subtitulo: 'Confirmados para ida e volta',
              onTap: onQuemVaiHoje,
            ),
            const Divider(height: 1, indent: AppSpacing.md),
            _ItemMenu(
              icone: Icons.calendar_month_outlined,
              titulo: 'Meu padrão semanal',
              subtitulo: 'Dias e horários fixos',
              onTap: onPadrao,
            ),
            const Divider(height: 1, indent: AppSpacing.md),
            _ItemMenu(
              icone: Icons.notifications_none_rounded,
              titulo: 'Prévia de notificações',
              subtitulo: 'Chamada aberta e lembrete',
              onTap: onNotificacoes,
            ),
          ],
          const Divider(height: 1, indent: AppSpacing.md),
          _ItemMenu(
            icone: Icons.logout_rounded,
            titulo: 'Sair da conta',
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
    final cor = destrutivo ? AppColors.error : AppColors.text;
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
            color: cor,
          ),
        ),
        subtitle: subtitulo == null
            ? null
            : Text(
                subtitulo!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
