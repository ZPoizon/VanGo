import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/usuario.dart';
import '../formatadores.dart';
import 'vango_avatar.dart';

class StudentListTile extends StatelessWidget {
  const StudentListTile({
    super.key,
    required this.aluno,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showCheckbox = false,
    this.selected = false,
    this.onChanged,
    this.enabled = true,
  });

  final Usuario aluno;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showCheckbox;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final descricao =
        subtitle ??
        [
          aluno.instituicao,
          aluno.turno?.label,
        ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (showCheckbox) ...[
                Checkbox(
                  value: selected,
                  onChanged: enabled ? onChanged : null,
                  activeColor: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xxs),
              ] else ...[
                VangoAvatar(nome: aluno.nome, radius: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aluno.nome,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (descricao.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        descricao,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String descricaoAluno(Usuario aluno) {
  final partes = <String>[
    if (aluno.instituicao != null) aluno.instituicao!,
    if (aluno.telefone != null) aluno.telefone!,
  ];
  return partes.join(' · ');
}

String iniciaisDe(Usuario aluno) => iniciais(aluno.nome);
