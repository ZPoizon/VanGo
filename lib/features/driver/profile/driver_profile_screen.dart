import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/validadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';
import 'package:vango/models/usuario.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _senhaAtual = TextEditingController();
  final _novaSenha = TextEditingController();

  late Usuario _usuario;
  late Usuario _usuarioOriginal;
  bool _salvando = false;
  bool _alterandoSenha = false;

  @override
  void initState() {
    super.initState();
    _usuario = StoreScope.read(context).usuarioAtual!;
    _usuarioOriginal = _usuario;
    _aplicarUsuario(_usuario);
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _senhaAtual.dispose();
    _novaSenha.dispose();
    super.dispose();
  }

  void _aplicarUsuario(Usuario usuario) {
    _nome.text = usuario.nome;
    _telefone.text = usuario.telefone ?? '';
  }

  void _cancelar() {
    if (_salvando) return;
    FocusScope.of(context).unfocus();
    setState(() => _aplicarUsuario(_usuarioOriginal));
    mostrarToast(context, 'Alterações descartadas.');
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (_salvando || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    // Nenhum campo de instituição/endereço/turno/van é enviado pelo motorista.
    final resultado = await StoreScope.read(context)
        .atualizarPerfil(nome: _nome.text, telefone: _telefone.text);
    if (!mounted) return;
    setState(() => _salvando = false);
    mostrarResultado(context, resultado);
    if (!resultado.sucesso) return;

    final salvo = StoreScope.read(context).usuarioAtual;
    if (salvo != null) {
      setState(() {
        _usuario = salvo;
        _usuarioOriginal = salvo;
        _aplicarUsuario(salvo);
      });
    }
  }

  Future<void> _salvarSenha() async {
    final resultado = await StoreScope.read(context)
        .alterarSenha(senhaAtual: _senhaAtual.text, novaSenha: _novaSenha.text);
    if (!mounted) return;
    mostrarResultado(context, resultado);
    if (resultado.sucesso) {
      setState(() {
        _alterandoSenha = false;
        _senhaAtual.clear();
        _novaSenha.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VangoAppBar(title: 'Meu perfil'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              VangoCard(
                child: Column(
                  children: [
                    VangoAvatar(
                      nome: _usuario.nome,
                      radius: 38,
                      fotoUrl: _usuario.fotoUrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _usuario.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    VangoButton(
                      label: 'Alterar foto',
                      icon: Icons.photo_camera_outlined,
                      variant: VangoButtonVariant.ghost,
                      height: 44,
                      onPressed: () => mostrarToast(
                        context,
                        'A seleção de foto será integrada ao Firebase Storage '
                        'na Etapa 3.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _nome,
                label: 'Nome completo',
                validator: validarNome,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoReadOnlyField(
                label: 'E-mail',
                value: _usuario.email,
                icon: Icons.mail_outline_rounded,
                helper:
                    'A alteração de e-mail exigirá reautenticação no Firebase.',
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _telefone,
                label: 'Telefone',
                hint: '(15) 99999-9999',
                keyboardType: TextInputType.phone,
                validator: validarTelefone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Expanded(
                          child: Text(
                            'Senha',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _alterandoSenha = !_alterandoSenha,
                          ),
                          child: Text(
                            _alterandoSenha ? 'Fechar' : 'Alterar senha',
                          ),
                        ),
                      ],
                    ),
                    if (_alterandoSenha) ...[
                      const SizedBox(height: AppSpacing.xs),
                      VangoTextField(
                        controller: _senhaAtual,
                        label: 'Senha atual',
                        obscureText: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VangoTextField(
                        controller: _novaSenha,
                        label: 'Nova senha',
                        hint: 'Mínimo de 6 caracteres',
                        obscureText: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VangoButton(
                        label: 'Salvar nova senha',
                        height: 48,
                        onPressed: _salvarSenha,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              VangoButton(
                label: 'Salvar perfil',
                icon: Icons.save_outlined,
                loading: _salvando,
                onPressed: _salvando ? null : _salvar,
              ),
              const SizedBox(height: AppSpacing.sm),
              VangoButton(
                label: 'Cancelar edição',
                icon: Icons.undo_rounded,
                variant: VangoButtonVariant.outline,
                onPressed: _salvando ? null : _cancelar,
              ),
              const SizedBox(height: AppSpacing.sm),
              VangoButton(
                label: 'Sair da conta',
                icon: Icons.logout_rounded,
                variant: VangoButtonVariant.ghost,
                onPressed: () {
                  StoreScope.read(context).sair();
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
