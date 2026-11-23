import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';
import 'package:vango/models/usuario.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final Usuario? _aluno;
  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _telefone;
  late final TextEditingController _endereco;
  late final TextEditingController _instituicao;

  @override
  void initState() {
    super.initState();
    _aluno = StoreScope.read(context).alunoPorId(widget.studentId);
    _nome = TextEditingController(text: _aluno?.nome ?? '');
    _email = TextEditingController(text: _aluno?.email ?? '');
    _telefone = TextEditingController(text: _aluno?.telefone ?? '');
    _endereco = TextEditingController(text: _aluno?.enderecoEmbarque ?? '');
    // Nenhum valor padrão: contas antigas podem não ter instituição e um nome
    // personalizado não pode ser trocado por "Fatec" ao salvar.
    _instituicao = TextEditingController(text: _aluno?.instituicao ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _endereco.dispose();
    _instituicao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final aluno = _aluno;
    if (aluno == null) return;
    final resultado = await StoreScope.read(context).salvarAluno(
      aluno.copyWith(
        nome: _nome.text.trim(),
        telefone: _telefone.text.trim(),
        instituicao: _instituicao.text.trim(),
        enderecoEmbarque: _endereco.text.trim(),
      ),
    );
    if (!mounted) return;
    mostrarResultado(context, resultado);
    if (resultado.sucesso) context.pop();
  }

  Future<void> _desativar() async {
    final aluno = _aluno;
    if (aluno == null) return;
    final confirmar = await confirmarAcao(
      context,
      titulo: 'Desativar aluno?',
      mensagem:
          '${aluno.nome} deixará de receber chamadas e avisos, mas o histórico '
          'de viagens será preservado.',
      confirmarLabel: 'Desativar',
      destrutivo: true,
      icone: Icons.person_off_outlined,
    );
    if (!confirmar || !mounted) return;
    final resultado = await StoreScope.read(context).desativarAluno(aluno.id);
    if (!mounted) return;
    mostrarResultado(context, resultado);
    if (resultado.sucesso) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final aluno = _aluno;
    if (aluno == null) {
      return const Scaffold(
        appBar: VangoAppBar(title: 'Aluno'),
        body: EstadoView(
          titulo: 'Aluno não encontrado',
          mensagem: 'Aluno não encontrado nesta van.',
          tipo: EstadoTipo.erro,
        ),
      );
    }

    return Scaffold(
      appBar: VangoAppBar(
        title: aluno.primeiroNome,
        actions: [
          IconButton(
            tooltip: 'Desativar',
            icon: const Icon(Icons.person_off_outlined),
            onPressed: _desativar,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            VangoCard(
              color: AppColors.primarySoft,
              borderColor: AppColors.primarySoft,
              child: Text(
                'Cadastro ${aluno.status.label.toLowerCase()} · ${aluno.periodo ?? 'Sem turno'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VangoTextField(
              controller: _nome,
              label: 'Nome completo',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            VangoReadOnlyField(
              label: 'E-mail',
              value: aluno.email,
              icon: Icons.mail_outline_rounded,
              helper: 'E-mail e senha de outro usuário não são alterados pelo cliente.',
            ),
            const SizedBox(height: AppSpacing.md),
            VangoTextField(
              controller: _telefone,
              label: 'Telefone',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            VangoTextField(
              controller: _instituicao,
              label: 'Instituição',
              hint: 'Nome da instituição',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            VangoTextField(
              controller: _endereco,
              label: 'Endereço de embarque',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            VangoButton(
              label: 'Salvar alterações',
              icon: Icons.save_outlined,
              onPressed: _salvar,
            ),
            const SizedBox(height: AppSpacing.sm),
            VangoButton(
              label: 'Desativar aluno',
              icon: Icons.person_off_outlined,
              variant: VangoButtonVariant.danger,
              onPressed: _desativar,
            ),
          ],
        ),
      ),
    );
  }
}
