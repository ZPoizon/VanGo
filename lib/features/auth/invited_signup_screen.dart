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
import 'package:vango/demo/demo_data.dart';
import 'package:vango/models/usuario.dart';

class InvitedSignupScreen extends StatefulWidget {
  const InvitedSignupScreen({super.key, required this.token});

  final String token;

  @override
  State<InvitedSignupScreen> createState() => _InvitedSignupScreenState();
}

class _InvitedSignupScreenState extends State<InvitedSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _endereco = TextEditingController();
  final _senha = TextEditingController();
  final _outraInstituicao = TextEditingController();

  String _instituicao = 'Fatec';
  late Turno _turno;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _turno = StoreScope.read(context).conviteTurno;
    _carregarConvite();
  }

  Future<void> _carregarConvite() async {
    final turno = await StoreScope.read(context).carregarConvite(widget.token);
    if (!mounted || turno == null) return;
    setState(() => _turno = turno);
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _endereco.dispose();
    _senha.dispose();
    _outraInstituicao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final instituicao = _instituicao == 'Outra'
        ? _outraInstituicao.text.trim()
        : _instituicao;
    if (_instituicao == 'Outra' && instituicao.isEmpty) {
      mostrarToast(context, 'Informe o nome da instituição.', erro: true);
      return;
    }

    setState(() => _carregando = true);

    final resultado = await StoreScope.read(context).enviarSolicitacao(
      nome: _nome.text,
      email: _email.text,
      telefone: _telefone.text,
      instituicao: instituicao,
      endereco: _endereco.text,
      senha: _senha.text,
      turno: _turno,
      conviteToken: widget.token,
    );
    if (!mounted) return;

    setState(() => _carregando = false);
    if (!resultado.sucesso) {
      mostrarResultado(context, resultado);
      return;
    }
    context.go('/signup/success');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VangoAppBar(title: 'Criar perfil por convite'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              VangoCard(
                color: AppColors.primarySoft,
                borderColor: AppColors.primarySoft,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Convite: ${widget.token}. Seu cadastro ficará pendente '
                        'até a aprovação do motorista.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
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
                hint: 'Como você aparece na lista',
                validator: validarNome,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _email,
                label: 'E-mail',
                hint: 'seu@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: validarEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _telefone,
                label: 'Telefone',
                hint: '(15) 99999-9999',
                keyboardType: TextInputType.phone,
                validator: validarTelefone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              _CampoInstituicao(
                valor: _instituicao,
                onChanged: (valor) => setState(() => _instituicao = valor),
              ),
              if (_instituicao == 'Outra') ...[
                const SizedBox(height: AppSpacing.md),
                VangoTextField(
                  controller: _outraInstituicao,
                  label: 'Outra instituição',
                  hint: 'Nome da instituição',
                  validator: (valor) =>
                      validarObrigatorio(valor, 'a instituição'),
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _endereco,
                label: 'Endereço de embarque',
                hint: 'Rua, número e referência',
                validator: validarEndereco,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Turno',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _TurnoOpcao(
                      label: 'Matutino',
                      selecionado: _turno == Turno.matutino,
                      onTap: () => setState(() => _turno = Turno.matutino),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _TurnoOpcao(
                      label: 'Noturno',
                      selecionado: _turno == Turno.noturno,
                      onTap: () => setState(() => _turno = Turno.noturno),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _senha,
                label: 'Senha',
                hint: 'Mínimo de 6 caracteres',
                obscureText: true,
                validator: validarSenha,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'A senha não é armazenada no Firestore. Em produção será '
                'gerenciada pelo Firebase Auth.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              VangoButton(
                label: 'Enviar cadastro',
                icon: Icons.send_rounded,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnoOpcao extends StatelessWidget {
  const _TurnoOpcao({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selecionado ? AppColors.primary : AppColors.divider,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selecionado ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _CampoInstituicao extends StatelessWidget {
  const _CampoInstituicao({required this.valor, required this.onChanged});

  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instituição',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: valor,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Selecione'),
          items: DemoData.instituicoes
              .map(
                (instituicao) => DropdownMenuItem<String>(
                  value: instituicao,
                  child: Text(instituicao),
                ),
              )
              .toList(),
          onChanged: (novo) {
            if (novo != null) onChanged(novo);
          },
        ),
      ],
    );
  }
}
