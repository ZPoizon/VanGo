import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/formatadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/van_logo.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/viagem.dart';

class ArrivalAlertScreen extends StatelessWidget {
  const ArrivalAlertScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final usuario = store.usuarioAtual;
    if (usuario == null) return const SizedBox.shrink();

    final viagem = tripId == 'demo' ? null : store.viagemPorId(tripId);
    final emAndamento = viagem?.status == StatusViagem.emAndamento;
    final resposta = store.respostaDe(usuario.id);
    final jaAvisou = resposta.estouIndo;

    return Scaffold(
      appBar: const VangoAppBar(title: 'Aviso de chegada'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!emAndamento)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusChip(
                      label: store.modoDemo
                          ? 'Prévia de demonstração'
                          : 'Nenhuma viagem em andamento',
                      tone: VangoTone.warning,
                      icon: Icons.science_outlined,
                      compact: true,
                    ),
                  ],
                ),
              ),
            VangoCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderColor: AppColors.accent,
              color: AppColors.accentSoft,
              child: Column(
                children: [
                  const VanLogo(size: 104),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'A van está chegando!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    emAndamento
                        ? '${store.motorista?.nome ?? 'O motorista'} iniciou a '
                              'viagem de ${viagem!.sentido.label.toLowerCase()}. '
                              'Vá para a frente de casa.'
                        : 'Prévia da notificação de alta visibilidade. Em '
                              'produção, o aviso chega via FCM quando o motorista '
                              'seleciona você.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                  if (emAndamento) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StatusChip(
                          label: viagem!.sentido.label,
                          tone: VangoTone.info,
                          compact: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        StatusChip(
                          label:
                              'Iniciada ${formatarHoraTexto(viagem.iniciadaEm == null ? null : formatarHora(viagem.iniciadaEm!))}',
                          tone: VangoTone.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (jaAvisou)
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
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Você respondeu "Estou indo"'
                              '${resposta.estouIndoEm == null ? '' : ' às ${formatarHora(resposta.estouIndoEm!)}'}. '
                              'O motorista já vê essa confirmação na lista.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    VangoButton(
                      label: 'Estou indo!',
                      icon: Icons.directions_walk_rounded,
                      onPressed: () async {
                        final resultado = await store.registrarEstouIndo();
                        if (!context.mounted) return;
                        mostrarResultado(context, resultado);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VangoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecaoRotulo('O que acontece agora'),
                  const SizedBox(height: AppSpacing.xs),
                  const BulletItem(
                    texto:
                        '"Estou indo" registra ciência do aviso, não embarque.',
                  ),
                  const BulletItem(
                    texto: 'O motorista vê a confirmação e o horário na lista do dia.',
                  ),
                  const BulletItem(
                    texto:
                        'A tela cheia não é garantida pelo Android; o canal de '
                        'alta importância é o fallback previsto.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            VangoButton(
              label: 'Voltar para o início',
              variant: VangoButtonVariant.ghost,
              icon: Icons.arrow_back_rounded,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/student/home');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BulletItem extends StatelessWidget {
  const BulletItem({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.muted),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
