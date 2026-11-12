import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/formatadores.dart';

class VangoAvatar extends StatelessWidget {
  const VangoAvatar({
    super.key,
    required this.nome,
    this.radius = 24,
    this.fotoUrl,
    this.onTap,
  });

  final String nome;
  final double radius;
  final String? fotoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final conteudo = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage: fotoUrl == null ? null : NetworkImage(fotoUrl!),
      child: fotoUrl == null
          ? Text(
              iniciais(nome),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.62,
              ),
            )
          : null,
    );

    if (onTap == null) return conteudo;
    return Semantics(
      button: true,
      label: 'Abrir perfil de $nome',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: conteudo,
      ),
    );
  }
}
