import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/validadores.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/profile_photo_sheet.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';
import 'package:vango/demo/demo_data.dart';
import 'package:vango/models/usuario.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _instituicao = TextEditingController();
  final _endereco = TextEditingController();
  final _cep = TextEditingController();
  final _referencia = TextEditingController();
  final _turnoPersonalizado = TextEditingController();

  Turno _turno = Turno.matutino;
  bool _salvando = false;
  bool _alterandoSenha = false;
  final _senhaAtual = TextEditingController();
  final _novaSenha = TextEditingController();

  /// Dados exibidos no topo e snapshot usado como base do botão Cancelar.
  late Usuario _usuario;
  late Usuario _usuarioOriginal;

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
    _instituicao.dispose();
    _endereco.dispose();
    _cep.dispose();
    _referencia.dispose();
    _turnoPersonalizado.dispose();
    _senhaAtual.dispose();
    _novaSenha.dispose();
    super.dispose();
  }

  void _aplicarUsuario(Usuario usuario) {
    _nome.text = usuario.nome;
    _telefone.text = usuario.telefone ?? '';
    _instituicao.text = usuario.instituicao ?? '';
    _endereco.text = usuario.enderecoEmbarque ?? '';
    _cep.text = usuario.cep ?? '';
    _referencia.text = usuario.referenciaEndereco ?? '';
    _turno = usuario.turno ?? Turno.matutino;
    _turnoPersonalizado.text = usuario.turnoPersonalizado ?? '';
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

    final instituicao = _instituicao.text.trim();
    final cep = _cep.text.trim();
    final turnoPersonalizado = _turno == Turno.outro
        ? _turnoPersonalizado.text.trim()
        : null;
    final atual = _usuarioOriginal;

    // Campos opcionais não alterados não são enviados: o Firestore faz merge
    // e os valores originais permanecem intactos.
    setState(() => _salvando = true);
    final resultado = await StoreScope.read(context).atualizarPerfil(
      nome: _nome.text,
      telefone: _telefone.text,
      instituicao: instituicao == (atual.instituicao ?? '')
          ? null
          : instituicao,
      endereco: _endereco.text == (atual.enderecoEmbarque ?? '')
          ? null
          : _endereco.text,
      cep: cep == (atual.cep ?? '') ? null : cep,
      referencia: _referencia.text == (atual.referenciaEndereco ?? '')
          ? null
          : _referencia.text,
      turno: _turno == (atual.turno ?? Turno.matutino) ? null : _turno,
      turnoPersonalizado:
          turnoPersonalizado == (atual.turnoPersonalizado ?? '')
              ? null
              : turnoPersonalizado,
    );
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

  Future<void> _alterarFoto() async {
    final store = StoreScope.read(context);
    final alterou = await mostrarEditorFotoPerfil(
      context,
      possuiFoto: _usuario.fotoUrl != null,
      salvar: store.atualizarFotoPerfil,
      remover: store.removerFotoPerfil,
    );
    if (!alterou || !mounted) return;
    final atualizado = StoreScope.read(context).usuarioAtual;
    if (atualizado == null) return;
    setState(() {
      _usuario = atualizado;
      _usuarioOriginal = atualizado;
    });
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
                      onPressed: _alterarFoto,
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
                helper: 'Alteração de e-mail exige reautenticação no Firebase.',
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _telefone,
                label: 'Telefone',
                keyboardType: TextInputType.phone,
                validator: validarTelefone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              _CampoInstituicao(controller: _instituicao),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<Turno>(
                initialValue: _turno,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Turno',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                items: Turno.values
                    .map(
                      (turno) => DropdownMenuItem<Turno>(
                        value: turno,
                        child: Text(turno.label),
                      ),
                    )
                    .toList(),
                onChanged: _salvando
                    ? null
                    : (novo) {
                        if (novo != null) setState(() => _turno = novo);
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
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _endereco,
                label: 'Endereço de embarque',
                maxLines: 2,
                validator: validarEndereco,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _cep,
                label: 'CEP',
                hint: '00000-000',
                keyboardType: TextInputType.number,
                // Documentos antigos não têm CEP; quando preenchido, exige 8 dígitos.
                validator: (valor) => valor == null || valor.trim().isEmpty
                    ? null
                    : validarCep(valor),
                onChanged: (valor) {
                  final formatado = aplicarMascaraCep(valor);
                  if (formatado == valor) return;
                  _cep.value = TextEditingValue(
                    text: formatado,
                    selection: TextSelection.collapsed(offset: formatado.length),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              VangoTextField(
                controller: _referencia,
                label: 'Referência do endereço',
                hint: 'Ex.: portão azul, ao lado da padaria',
                maxLines: 2,
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

/// Instituição é texto livre; os nomes conhecidos viram apenas atalhos.
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
          // Contas antigas podem não ter instituição: o campo é opcional aqui.
          validator: (valor) => valor == null || valor.trim().isEmpty
              ? null
              : validarObrigatorio(valor, 'a instituição'),
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
