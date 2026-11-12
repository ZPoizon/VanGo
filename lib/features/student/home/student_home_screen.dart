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
              const SizedBox(height: AppSpacing.lg),
              _AvisoChegadaCard(store: store),
              const SizedBox(height: AppSpacing.md),
              _ChamadaAmanhaCard(store: store, usuario: usuario),
              const SizedBox(height: AppSpacing.md),
              _LiberacaoCard(store: store, usuario: usuario),
              const SizedBox(height: AppSpacing.md),
              _HorariosCard(store: store),
              const SizedBox(height: AppSpacing.md),
              _MenuAluno(
                onQuemVaiHoje: () => context.push('/student/today'),
                onPadrao: () => context.push('/student/schedule'),
                onNotificacoes: () => _abrirNotificacoesDemo(context),
                onSair: () {
                  StoreScope.read(context).sair();
                  context.go('/login');
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const Center(
                child: Text(
                  'VanGo · Etapa 1 · dados em memória',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirNotificacoesDemo(BuildContext context) {
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
              'Prévia de notificações',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Simulação visual (SCR-018 e SCR-019). O envio real via FCM '
              'entra na Etapa 4.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            _NotificacaoDemo(
              titulo: 'Chamada aberta!',
              texto: 'Confirme sua presença de amanhã.',
              hora: 'agora',
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),
            _NotificacaoDemo(
              titulo: 'Lembrete da chamada',
              texto: 'Você ainda não respondeu a chamada de amanhã.',
              hora: 'há 2 h',
              onTap: () => Navigator.of(sheetContext).pop(),
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

class _AvisoChegadaCard extends StatelessWidget {
  const _AvisoChegadaCard({required this.store});

  final VanGoStore store;

  @override
  Widget build(BuildContext context) {
    final viagem = store.viagemAtual;
    final ativa = viagem?.status == StatusViagem.emAndamento;
    final destino = ativa ? viagem!.id : 'demo';

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
                StatusChip(
                  label: chamada.status.label,
                  tone: chamada.aberta ? VangoTone.success : VangoTone.neutral,
                  compact: true,
                ),
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
                child: _GradeRespostas(
                  resposta: resposta,
                  onResponder: (ida, volta) async {
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
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Respostas bloqueadas: a chamada foi encerrada.',
                        style: TextStyle(
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

class _GradeRespostas extends StatelessWidget {
  const _GradeRespostas({required this.resposta, required this.onResponder});

  final RespostaPresenca resposta;
  final void Function(bool ida, bool volta) onResponder;

  @override
  Widget build(BuildContext context) {
    final opcoes = [
      _OpcaoResposta(
        label: 'Só vou',
        detalhe: 'ida',
        icone: Icons.arrow_upward_rounded,
        selecionado:
            resposta.ida == RespostaSentido.vai &&
            resposta.volta == RespostaSentido.naoVai,
        tone: VangoTone.info,
        onTap: () => onResponder(true, false),
      ),
      _OpcaoResposta(
        label: 'Só volto',
        detalhe: 'volta',
        icone: Icons.arrow_downward_rounded,
        selecionado:
            resposta.ida == RespostaSentido.naoVai &&
            resposta.volta == RespostaSentido.vai,
        tone: VangoTone.purple,
        onTap: () => onResponder(false, true),
      ),
      _OpcaoResposta(
        label: 'Ida e volta',
        detalhe: 'ida + volta',
        icone: Icons.sync_alt_rounded,
        selecionado:
            resposta.ida == RespostaSentido.vai &&
            resposta.volta == RespostaSentido.vai,
        tone: VangoTone.success,
        onTap: () => onResponder(true, true),
      ),
      _OpcaoResposta(
        label: 'Não vou',
        detalhe: 'ausente',
        icone: Icons.block_rounded,
        selecionado:
            resposta.ida == RespostaSentido.naoVai &&
            resposta.volta == RespostaSentido.naoVai,
        tone: VangoTone.error,
        onTap: () => onResponder(false, false),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = (constraints.maxWidth - AppSpacing.xs) / 2;
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: opcoes
              .map((opcao) => SizedBox(width: largura, child: opcao))
              .toList(),
        );
      },
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
    required this.onQuemVaiHoje,
    required this.onPadrao,
    required this.onNotificacoes,
    required this.onSair,
  });

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
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icone,
        color: destrutivo ? AppColors.error : AppColors.primary,
      ),
      title: Text(
        titulo,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cor),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}

class _NotificacaoDemo extends StatelessWidget {
  const _NotificacaoDemo({
    required this.titulo,
    required this.texto,
    required this.hora,
    required this.onTap,
  });

  final String titulo;
  final String texto;
  final String hora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VangoCard(
      onTap: onTap,
      color: AppColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      hora,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
