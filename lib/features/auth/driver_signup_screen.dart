import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/validadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _senha = TextEditingController();
  final _confirmarSenha = TextEditingController();

  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmacao = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _senha.dispose();
    _confirmarSenha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Segunda barreira: a confirmação nunca é enviada ao Firebase.
    if (_confirmarSenha.text != _senha.text) {
      mostrarToast(context, 'As senhas não coincidem.', erro: true);
      return;
    }

    setState(() => _carregando = true);

    final resultado = await StoreScope.read(context).cadastrarMotorista(
      nome: _nome.text,
      email: _email.text,
      telefone: _telefone.text,
      senha: _senha.text,
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (!resultado.sucesso) {
      mostrarResultado(context, resultado);
      return;
    }

    if (!context.mounted) return;
    mostrarToast(context, 'Conta de motorista criada com sucesso!');
    context.go('/driver/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VangoAppBar(title: 'Cadastro de Motorista'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              VangoCard(
                color: AppColors.primarySoft,
                borderColor: AppColors.primarySoft,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Crie primeiro sua conta de motorista. Depois, no painel "Minhas vans", você poderá cadastrar sua primeira van e compartilhar o código de entrada com os alunos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _nome,
                label: 'Nome completo',
                hint: 'Nome do motorista',
                validator: validarNome,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _email,
                label: 'E-mail profissional',
                hint: 'seu@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: validarEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _telefone,
                label: 'Telefone / WhatsApp',
                hint: '(15) 99999-9999',
                keyboardType: TextInputType.phone,
                validator: validarTelefone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _senha,
                label: 'Senha de acesso',
                hint: 'Mínimo de 6 caracteres',
                obscureText: !_mostrarSenha,
                validator: validarSenha,
                suffixIcon: IconButton(
                  tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                  icon: Icon(
                    _mostrarSenha
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarSenha = !_mostrarSenha),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _confirmarSenha,
                label: 'Confirmar senha',
                hint: 'Repita a senha',
                obscureText: !_mostrarConfirmacao,
                validator: (valor) =>
                    validarConfirmacaoSenha(valor, _senha.text),
                suffixIcon: IconButton(
                  tooltip: _mostrarConfirmacao
                      ? 'Ocultar confirmação'
                      : 'Mostrar confirmação',
                  icon: Icon(
                    _mostrarConfirmacao
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(
                    () => _mostrarConfirmacao = !_mostrarConfirmacao,
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.lg),
              VangoButton(
                label: 'Criar conta de motorista',
                icon: Icons.check_circle_rounded,
                loading: _carregando,
                onPressed: _enviar,
              ),
              const SizedBox(height: AppSpacing.sm),
              VangoButton(
                label: 'Já tenho conta',
                variant: VangoButtonVariant.ghost,
                height: 48,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: AppSpacing.xs),
              VangoButton(
                label: 'Voltar',
                variant: VangoButtonVariant.ghost,
                height: 48,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
