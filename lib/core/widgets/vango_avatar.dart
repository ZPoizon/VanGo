import 'dart:convert';

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
    final imagem = _imagemDe(fotoUrl);
    final conteudo = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage: imagem,
      child: imagem == null
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

  /// No modo demo a foto vive apenas em memória, como data URI. No Firebase,
  /// [fotoUrl] é a URL de download do Storage e segue por [NetworkImage].
  static ImageProvider<Object>? _imagemDe(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image/')) {
      final virgula = url.indexOf(',');
      if (virgula < 0) return null;
      try {
        return MemoryImage(base64Decode(url.substring(virgula + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }
}
