import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';

class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Cadastro enviado!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Sua solicitação foi registrada como pendente. O motorista do '
                'grupo precisa aprovar seu acesso antes do primeiro login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const VangoCard(
                child: Column(
                  children: [
                    _Passo(
                      numero: '1',
                      texto: 'Solicitação recebida pelo motorista',
                      ativo: true,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _Passo(
                      numero: '2',
                      texto: 'Aprovação e vínculo ao grupo/turno',
                      ativo: false,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _Passo(
                      numero: '3',
                      texto: 'Acesso liberado para responder chamadas',
                      ativo: false,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              VangoButton(
                label: 'Voltar ao login',
                icon: Icons.login_rounded,
                onPressed: () async {
                  await StoreScope.read(context).sair();
                  if (!context.mounted) return;
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({
    required this.numero,
    required this.texto,
    required this.ativo,
  });

  final String numero;
  final String texto;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativo ? AppColors.success : AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: ativo ? AppColors.success : AppColors.divider,
            ),
          ),
          child: Text(
            numero,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ativo ? Colors.white : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              color: ativo ? AppColors.text : AppColors.muted,
              fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
