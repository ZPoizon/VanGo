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
import 'package:vango/core/resultado.dart';
import 'package:vango/models/grupo.dart';

class CreateVanScreen extends StatefulWidget {
  const CreateVanScreen({super.key, this.rotaRetorno});

  /// Quando informado (fluxo iniciado pelo dashboard), a criação volta
  /// explicitamente para esta rota em vez de depender do pop da pilha.
  /// O fluxo de "Minhas vans" continua usando o pop com `true`.
  final String? rotaRetorno;

  @override
  State<CreateVanScreen> createState() => _CreateVanScreenState();
}

class _CreateVanScreenState extends State<CreateVanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _origem = TextEditingController();
  final _destino = TextEditingController();
  final _horario = TextEditingController();
  final _observacoes = TextEditingController();
  final _periodoPersonalizado = TextEditingController();
  PeriodoVan? _periodo;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _origem.dispose();
    _destino.dispose();
    _horario.dispose();
    _observacoes.dispose();
    _periodoPersonalizado.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final formState = _formKey.currentState;
    if (_salvando || formState == null) return;
    if (!formState.validate()) return;
    setState(() => _salvando = true);
    try {
      final resultado = await StoreScope.read(context).criarGrupo(
        nome: _nome.text,
        cidadeOrigem: _origem.text,
        cidadeDestino: _destino.text,
        periodo: _periodo,
        periodoPersonalizado: _periodoPersonalizado.text,
        horarioSaida: _horario.text,
        observacoes: _observacoes.text,
      );
      if (!mounted) return;
      mostrarResultado(context, resultado);
      if (resultado.sucesso) {
        // Não chamar unfocus manualmente: o desfoco imediato antes do pop
        // deixava o focus manager visitar render objects inativos
        // (Null check em RenderObject.getTransformTo / FocusScope inativo).
        final retorno = widget.rotaRetorno;
        if (retorno != null && retorno.isNotEmpty) {
          context.go(retorno);
        } else {
          context.pop(true);
        }
      }
    } catch (_) {
      if (!mounted) return;
      mostrarResultado(
        context,
        const OperacaoResultado.erro(
          'Não foi possível criar a van. Tente novamente.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VangoAppBar(title: 'Nova van'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              VangoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados da van',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Cada van terá código, alunos, chamadas e viagens próprios.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    VangoTextField(
                      controller: _nome,
                      label: 'Nome da van',
                      hint: 'Ex.: Van Manhã Centro',
                      validator: (valor) => (valor?.trim().length ?? 0) >= 3
                          ? null
                          : 'Informe o nome da van.',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VangoTextField(
                      controller: _origem,
                      label: 'Cidade de origem',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VangoTextField(
                      controller: _destino,
                      label: 'Cidade de destino',
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              VangoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Período e horário',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final colunas = constraints.maxWidth < 600 ? 2 : 4;
                        return GridView.count(
                          crossAxisCount: colunas,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: colunas == 2 ? 4.2 : 3.4,
                          children: [
                            for (final periodo in PeriodoVan.values)
                              _PeriodoOpcao(
                                key: Key('periodo-${periodo.name}'),
                                periodo: periodo,
                                selecionado: _periodo == periodo,
                                onSelecionado: (selecionado) => setState(() {
                                  _periodo = selecionado ? periodo : null;
                                }),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VangoTextField(
                      controller: _horario,
                      label: 'Horário habitual de saída (opcional)',
                      hint: 'Ex.: 07:15',
                      keyboardType: TextInputType.datetime,
                    ),
                    if (_periodo == PeriodoVan.personalizado) ...[
                      const SizedBox(height: AppSpacing.md),
                      VangoTextField(
                        controller: _periodoPersonalizado,
                        label: 'Descreva o período',
                        hint: 'Ex.: Segunda e quarta à tarde',
                        validator: (valor) => valor?.trim().isNotEmpty == true
                            ? null
                            : 'Descreva o período personalizado.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    VangoTextField(
                      controller: _observacoes,
                      label: 'Informações ou observações (opcional)',
                      hint: 'Ex.: ponto de encontro no portão azul',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              VangoButton(
                label: 'Criar van',
                icon: Icons.add_rounded,
                loading: _salvando,
                onPressed: _salvar,
              ),
              const SizedBox(height: AppSpacing.md),
              VangoButton(
                label: 'Cancelar',
                variant: VangoButtonVariant.ghost,
                onPressed: _salvando ? null : () => context.pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opção de período com altura/largura iguais às demais, controladas pela grade.
class _PeriodoOpcao extends StatelessWidget {
  const _PeriodoOpcao({
    super.key,
    required this.periodo,
    required this.selecionado,
    required this.onSelecionado,
  });

  final PeriodoVan periodo;
  final bool selecionado;
  final ValueChanged<bool> onSelecionado;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selecionado,
      child: InkWell(
        onTap: () => onSelecionado(!selecionado),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selecionado ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: selecionado ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            periodo.label,
            style: TextStyle(
              color: selecionado ? Colors.white : AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
