import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/core/widgets/vango_text_field.dart';
import 'package:vango/models/grupo.dart';

class EnterGroupCodeScreen extends StatefulWidget {
  const EnterGroupCodeScreen({super.key});

  @override
  State<EnterGroupCodeScreen> createState() => _EnterGroupCodeScreenState();
}

class _EnterGroupCodeScreenState extends State<EnterGroupCodeScreen> {
  final _codigoController = TextEditingController();
  GrupoVan? _grupoEncontrado;
  bool _buscando = false;
  bool _enviando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _buscarVan() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      mostrarToast(context, 'Digite o código da van.', erro: true);
      return;
    }

    setState(() {
      _buscando = true;
      _grupoEncontrado = null;
    });

    final store = StoreScope.read(context);
    final grupo = await store.buscarGrupoPorCodigo(codigo);

    if (!mounted) return;
    setState(() => _buscando = false);

    if (grupo == null) {
      final detalhe = store.erro;
      final mensagem =
          detalhe != null &&
              (detalhe.contains('permiss') ||
                  detalhe.contains('failed-precondition') ||
                  detalhe.contains('unavailable'))
          ? 'Não foi possível buscar a van agora. Tente novamente em instantes.'
          : 'Código não encontrado. Verifique os números com seu motorista.';
      mostrarToast(context, mensagem, erro: true);
      return;
    }

    setState(() => _grupoEncontrado = grupo);
  }

  Future<void> _solicitarEntrada() async {
    final grupo = _grupoEncontrado;
    if (grupo == null) return;

    setState(() => _enviando = true);

    final resultado = await StoreScope.read(context)
        .solicitarEntradaGrupo(grupoId: grupo.id);

    if (!mounted) return;
    setState(() => _enviando = false);

    if (!resultado.sucesso) {
      mostrarResultado(context, resultado);
      return;
    }

    mostrarToast(context, 'Solicitação enviada para ${grupo.nome}!');
    context.go('/student/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: VangoAppBar(
        title: 'Entrar em uma Van',
        onBack: () => context.go('/student/home'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            VangoCard(
              color: AppColors.accentSoft,
              borderColor: AppColors.accent,
              child: const Row(
                children: [
                  Icon(Icons.pin_rounded, color: AppColors.accent, size: 28),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código de Entrada',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Digite o código numérico fornecido pelo motorista da sua van.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            VangoTextField(
              controller: _codigoController,
              label: 'Código da Van (Ex: 849201)',
              hint: '000000',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(
                Icons.numbers_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VangoButton(
              label: 'Buscar Van',
              icon: Icons.search_rounded,
              loading: _buscando,
              onPressed: _buscarVan,
            ),
            if (_grupoEncontrado != null) ...[
              const SizedBox(height: AppSpacing.xl),
              VangoCard(
                color: AppColors.primarySoft,
                borderColor: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'Van Encontrada',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _grupoEncontrado!.nome,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (_grupoEncontrado!.trajeto.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Trajeto: ${_grupoEncontrado!.trajeto}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (_grupoEncontrado!.periodo.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Período: ${_grupoEncontrado!.periodo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Confira o nome da van antes de solicitar. A entrada '
                      'depende da aprovação do motorista.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VangoButton(
                      label: 'Solicitar entrada nesta van',
                      icon: Icons.send_rounded,
                      loading: _enviando,
                      onPressed: _solicitarEntrada,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
