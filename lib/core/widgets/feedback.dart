import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../resultado.dart';

void mostrarResultado(BuildContext context, OperacaoResultado resultado) {
  mostrarToast(
    context,
    resultado.mensagem ?? (resultado.sucesso ? 'Operação concluída.' : 'Erro.'),
    erro: !resultado.sucesso,
  );
}

void mostrarToast(BuildContext context, String mensagem, {bool erro = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: erro ? AppColors.error : AppColors.primary,
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(
            erro ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(mensagem)),
        ],
      ),
    ),
  );
}

Future<bool> confirmarAcao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmarLabel = 'Confirmar',
  String cancelarLabel = 'Cancelar',
  bool destrutivo = false,
  IconData? icone,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icone == null
          ? null
          : Icon(
              icone,
              color: destrutivo ? AppColors.error : AppColors.primary,
              size: 32,
            ),
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelarLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destrutivo
              ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmarLabel),
        ),
      ],
    ),
  );
  return resultado ?? false;
}
