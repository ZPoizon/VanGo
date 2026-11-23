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
  final _instituicao = TextEditingController();
  final _endereco = TextEditingController();
  final _cep = TextEditingController();
  final _senha = TextEditingController();
  final _turnoPersonalizado = TextEditingController();

  late Turno _turno;
  bool _carregando = false;

  bool get _isSolicitacaoDireta =>
      widget.token == 'solicitacao-direta' ||
      widget.token == 'solicitacao' ||
      widget.token == 'convite-demo';

  @override
  void initState() {
    super.initState();
    _turno = StoreScope.read(context).conviteTurno;
    _carregarConvite();
  }

  Future<void> _carregarConvite() async {
    if (_isSolicitacaoDireta) return;
    final turno = await StoreScope.read(context).carregarConvite(widget.token);
    if (!mounted || turno == null) return;
    setState(() => _turno = turno);
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _instituicao.dispose();
    _endereco.dispose();
    _cep.dispose();
    _senha.dispose();
    _turnoPersonalizado.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final instituicao = _instituicao.text.trim();
    final turnoPersonalizado = _turno == Turno.outro
        ? _turnoPersonalizado.text.trim()
        : null;
    if (turnoPersonalizado != null && turnoPersonalizado.isEmpty) {
      mostrarToast(context, 'Informe o turno personalizado.', erro: true);
      return;
    }

    setState(() => _carregando = true);

    final store = StoreScope.read(context);
    final resultado = _isSolicitacaoDireta
        ? await store.cadastrarAluno(
            nome: _nome.text,
            email: _email.text,
            telefone: _telefone.text,
            instituicao: instituicao,
            endereco: _endereco.text,
            cep: _cep.text.trim(),
            senha: _senha.text,
            turno: _turno,
            turnoPersonalizado: turnoPersonalizado,
          )
        : await store.enviarSolicitacao(
            nome: _nome.text,
            email: _email.text,
            telefone: _telefone.text,
            instituicao: instituicao,
            endereco: _endereco.text,
            cep: _cep.text.trim(),
            senha: _senha.text,
            turno: _turno,
            turnoPersonalizado: turnoPersonalizado,
            conviteToken: widget.token,
          );
    if (!mounted) return;

    setState(() => _carregando = false);
    if (!resultado.sucesso) {
      mostrarResultado(context, resultado);
      return;
    }
    // A conta passa a valer imediatamente: o aluno entra na própria Home e
    // solicita entrada na van a partir dali, sem logout.
    context.go('/student/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: VangoAppBar(
        title: _isSolicitacaoDireta
            ? 'Criar conta de aluno'
            : 'Criar perfil por convite',
      ),
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
                        _isSolicitacaoDireta
                            ? 'Crie sua conta de aluno. Depois de criar a conta, você já acessa seu painel e pode informar o código da van do motorista.'
                            : 'Convite: ${widget.token}. Seu cadastro ficará pendente até a aprovação do motorista.',
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
              _CampoInstituicao(controller: _instituicao),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _endereco,
                label: 'Endereço de embarque',
                hint: 'Rua, número e referência',
                validator: validarEndereco,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _cep,
                label: 'CEP',
                hint: '00000-000',
                keyboardType: TextInputType.number,
                validator: validarCep,
                onChanged: (valor) {
                  final formatado = aplicarMascaraCep(valor);
                  if (formatado == valor) return;
                  _cep.value = TextEditingValue(
                    text: formatado,
                    selection: TextSelection.collapsed(offset: formatado.length),
                  );
                },
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final largura = (constraints.maxWidth - AppSpacing.xs) / 2;
                  return Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final opcao in Turno.values)
                        SizedBox(
                          width: largura,
                          child: _TurnoOpcao(
                            label: opcao.label,
                            selecionado: _turno == opcao,
                            onTap: () => setState(() => _turno = opcao),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_turno == Turno.outro) ...[
                const SizedBox(height: AppSpacing.md),
                VangoTextField(
                  controller: _turnoPersonalizado,
                  label: 'Turno personalizado',
                  hint: 'Ex.: Integrado',
                  validator: (valor) =>
                      validarObrigatorio(valor, 'o turno personalizado'),
                  textInputAction: TextInputAction.next,
                ),
              ],
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
                'Sua conta será criada de forma segura e ativada após a validação do motorista.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              VangoButton(
                label: _isSolicitacaoDireta
                    ? 'Criar conta de aluno'
                    : 'Enviar solicitação',
                icon: _isSolicitacaoDireta
                    ? Icons.person_add_alt_1_rounded
                    : Icons.send_rounded,
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

/// Campo livre com sugestões opcionais: o aluno pode digitar qualquer
/// instituição e não existe valor pré-selecionado.
class _CampoInstituicao extends StatelessWidget {
  const _CampoInstituicao({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final sugestoes = DemoData.instituicoes
        .where((nome) => nome.trim().isNotEmpty && nome != 'Outra')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VangoTextField(
          controller: controller,
          label: 'Instituição',
          hint: 'Digite o nome da instituição',
          validator: (valor) => validarObrigatorio(valor, 'a instituição'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Sugestões (opcional)',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final nome in sugestoes)
              ActionChip(
                label: Text(nome, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  controller.text = nome;
                  controller.selection = TextSelection.collapsed(
                    offset: nome.length,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
