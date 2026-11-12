import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/resultado.dart';
import 'package:vango/core/validadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/van_logo.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';
import 'package:vango/models/usuario.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrarSenha = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final resultado = await StoreScope.read(context)
        .entrar(email: _email.text, senha: _senha.text);

    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (resultado != LoginResultado.sucesso) {
        _erro = resultado.mensagem;
      }
    });

    // Em caso de sucesso, o redirect do GoRouter leva ao home do perfil.
  }

  Future<void> _entrarComo(PerfilUsuario perfil) async {
    await StoreScope.read(context).entrarComo(perfil);
  }

  Future<void> _esqueciSenha() async {
    final controller = TextEditingController(text: _email.text);
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o e-mail da sua conta. Enviaremos um link para '
              'redefinir a senha.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'seu@email.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (enviar != true || !mounted) return;

    final resultado = await StoreScope.read(context)
        .enviarRecuperacaoSenha(_email.text);
    if (!mounted) return;
    mostrarToast(context, resultado.mensagem ?? 'Solicitação enviada.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const Center(child: VanLogo(size: 96)),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'VanGo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Transporte Universitário por Van',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    VangoTextField(
                      controller: _email,
                      label: 'E-mail',
                      hint: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: validarEmail,
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VangoTextField(
                      controller: _senha,
                      label: 'Senha',
                      hint: 'Sua senha',
                      obscureText: !_mostrarSenha,
                      textInputAction: TextInputAction.done,
                      validator: validarSenha,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.muted,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _mostrarSenha
                            ? 'Ocultar senha'
                            : 'Mostrar senha',
                        icon: Icon(
                          _mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                        ),
                        onPressed: () =>
                            setState(() => _mostrarSenha = !_mostrarSenha),
                      ),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _erro!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    VangoButton(
                      label: 'Entrar',
                      onPressed: _entrar,
                      loading: _carregando,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: _esqueciSenha,
                            child: const Text(
                              'Esqueci minha senha',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              if (store.modoDemo) {
                                context.go('/signup/convite-demo');
                              } else {
                                mostrarToast(
                                  context,
                                  'O cadastro é feito pelo link de convite '
                                  'enviado pelo motorista do grupo.',
                                );
                              }
                            },
                            child: const Text(
                              'Criar conta',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (store.modoDemo) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Text(
                              'acesso rápido',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VangoCard(
                        color: AppColors.surface,
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 18,
                                  color: AppColors.muted,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Modo demonstração',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: VangoButton(
                                    label: 'Sou aluno',
                                    icon: Icons.school_outlined,
                                    variant: VangoButtonVariant.outline,
                                    height: 48,
                                    onPressed: () =>
                                        _entrarComo(PerfilUsuario.aluno),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: VangoButton(
                                    label: 'Sou motorista',
                                    icon: Icons.directions_bus_outlined,
                                    variant: VangoButtonVariant.outline,
                                    height: 48,
                                    onPressed: () =>
                                        _entrarComo(PerfilUsuario.motorista),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            VangoButton(
                              label: 'Continuar com Google',
                              icon: Icons.g_mobiledata_rounded,
                              variant: VangoButtonVariant.ghost,
                              height: 44,
                              onPressed: () => mostrarToast(
                                context,
                                'Google SSO está planejado para uma etapa '
                                'futura.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      store.modoDemo
                          ? 'Ambiente demonstrativo: os dados ficam apenas em '
                                'memória e são perdidos ao fechar o app.'
                          : 'Conectado ao Firebase. Precisa de acesso? Peça o '
                                'link de convite ao motorista do grupo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
