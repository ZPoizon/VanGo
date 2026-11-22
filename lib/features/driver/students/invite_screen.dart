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
import 'package:vango/models/usuario.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late Turno _turno;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _turno = store.conviteTurno;
    if (store.conviteToken == null) {
      _gerar();
    }
  }

  Future<void> _gerar() async {
    final token = await StoreScope.read(context).gerarConvite(_turno);
    if (!mounted) return;
    mostrarToast(
      context,
      token == null
          ? 'Não foi possível gerar o link de convite. Tente novamente.'
          : 'Novo link de convite gerado.',
      erro: token == null,
    );
    setState(() {});
  }

  Future<void> _copiar() async {
    final link = StoreScope.read(context).linkConvite;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    mostrarToast(context, 'Link copiado para a área de transferência.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final link = store.linkConvite ?? '';
    final token = store.conviteToken ?? '';

    return Scaffold(
      appBar: const VangoAppBar(title: 'Convidar aluno'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            VangoCard(
              color: AppColors.primarySoft,
              borderColor: AppColors.primarySoft,
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Compartilhe o link com o aluno. O cadastro ficará '
                      'pendente até sua aprovação.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Turno do convite',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<Turno>(
              segments: const [
                ButtonSegment(value: Turno.matutino, label: Text('Matutino')),
                ButtonSegment(value: Turno.noturno, label: Text('Noturno')),
              ],
              selected: {_turno},
              onSelectionChanged: (value) {
                setState(() => _turno = value.first);
                _gerar();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            VangoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Link de convite',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: _turno.label,
                        tone: VangoTone.info,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    link,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VangoButton(
              label: 'Copiar link',
              icon: Icons.copy_rounded,
              onPressed: _copiar,
            ),
            const SizedBox(height: AppSpacing.sm),
            VangoButton(
              label: 'Compartilhar no WhatsApp',
              icon: Icons.chat_bubble_outline_rounded,
              variant: VangoButtonVariant.outline,
              onPressed: () => mostrarToast(
                context,
                'Integração com WhatsApp/share sheet prevista para etapa futura.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            VangoButton(
              label: 'Abrir link de teste',
              icon: Icons.open_in_new_rounded,
              variant: VangoButtonVariant.ghost,
              onPressed: () => context.push('/signup/$token'),
            ),
            const SizedBox(height: AppSpacing.sm),
            VangoButton(
              label: 'Gerar novo link',
              icon: Icons.refresh_rounded,
              variant: VangoButtonVariant.ghost,
              onPressed: _gerar,
            ),
          ],
        ),
      ),
    );
  }
}
