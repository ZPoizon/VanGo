import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/feedback.dart';
import 'package:vango/core/widgets/status_chip.dart';
import 'package:vango/core/widgets/student_list_tile.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/viagem.dart';

class NotifyStudentsScreen extends StatefulWidget {
  const NotifyStudentsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<NotifyStudentsScreen> createState() => _NotifyStudentsScreenState();
}

class _NotifyStudentsScreenState extends State<NotifyStudentsScreen> {
  final Set<String> _selecionados = <String>{};
  bool _enviando = false;

  void _alternar(String alunoId, bool? valor) {
    setState(() {
      if (valor ?? false) {
        _selecionados.add(alunoId);
      } else {
        _selecionados.remove(alunoId);
      }
    });
  }

  void _selecionarTodos(List<String> elegiveis) {
    setState(() {
      final todosSelecionados = elegiveis.every(_selecionados.contains);
      if (todosSelecionados) {
        _selecionados.clear();
      } else {
        _selecionados
          ..clear()
          ..addAll(elegiveis);
      }
    });
  }

  Future<void> _avisar() async {
    if (_selecionados.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    final resultado = await StoreScope.read(context)
        .avisarAlunos(_selecionados.toList());
    if (!mounted) return;
    setState(() => _enviando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final viagem = store.viagemPorId(widget.tripId);
    final ativa = viagem?.status == StatusViagem.emAndamento;

    if (viagem == null || !ativa) {
      return Scaffold(
        appBar: const VangoAppBar(title: 'Quem avisar?'),
        body: EstadoView(
          titulo: 'Nenhuma viagem em andamento',
          mensagem:
              'O aviso de chegada só pode ser enviado durante uma viagem '
              'ativa. Inicie a viagem de ${viagem?.sentido.label ?? 'IDA ou VOLTA'} '
              'na tela inicial.',
          tipo: EstadoTipo.erro,
          acaoLabel: 'Voltar ao início',
          onAcao: () => context.go('/driver/home'),
        ),
      );
    }

    final presencas = store.presencasViagemAtual;
    final elegiveis = presencas
        .where((presenca) => presenca.resposta.avisadoEm == null)
        .map((presenca) => presenca.aluno.id)
        .toList();
    final jaAvisados = presencas
        .where((presenca) => presenca.resposta.avisadoEm != null)
        .length;
    final todosSelecionados =
        elegiveis.isNotEmpty && elegiveis.every(_selecionados.contains);

    return Scaffold(
      appBar: const VangoAppBar(title: 'Quem avisar?'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: VangoCard(
                color: AppColors.accentSoft,
                borderColor: AppColors.accent,
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Viagem de ${viagem.sentido.label} em andamento',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'O aviso será enviado somente aos alunos '
                            'confirmados neste sentido.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Checkbox(
                    value: todosSelecionados,
                    onChanged: elegiveis.isEmpty
                        ? null
                        : (_) => _selecionarTodos(elegiveis),
                  ),
                  Expanded(
                    child: Text(
                      'Selecionar todos (${elegiveis.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (jaAvisados > 0)
                    StatusChip(
                      label: '$jaAvisados avisado(s)',
                      tone: VangoTone.accent,
                      compact: true,
                    ),
                ],
              ),
            ),
            Expanded(
              child: presencas.isEmpty
                  ? const EstadoView(
                      titulo: 'Nenhum aluno confirmado',
                      mensagem:
                          'A viagem foi iniciada sem alunos confirmados neste '
                          'sentido. Volte e verifique as respostas da chamada.',
                      tipo: EstadoTipo.info,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      itemCount: presencas.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final presenca = presencas[index];
                        final avisado = presenca.resposta.avisadoEm != null;
                        return StudentListTile(
                          aluno: presenca.aluno,
                          subtitle: presenca.aluno.instituicao,
                          showCheckbox: true,
                          selected: _selecionados.contains(presenca.aluno.id),
                          enabled: !avisado,
                          onChanged: (valor) =>
                              _alternar(presenca.aluno.id, valor),
                          trailing: avisado
                              ? const StatusChip(
                                  label: 'Avisado',
                                  tone: VangoTone.accent,
                                  icon: Icons.check_rounded,
                                  compact: true,
                                )
                              : null,
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: VangoButton(
                label: _selecionados.isEmpty
                    ? 'Selecione os alunos'
                    : 'Avisar (${_selecionados.length})',
                icon: Icons.send_rounded,
                loading: _enviando,
                onPressed: _selecionados.isEmpty ? null : _avisar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
