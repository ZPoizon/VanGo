import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/feedback.dart';
import 'web_share_stub.dart' if (dart.library.js_interop) 'web_share_web.dart';

/// Abstração da plataforma para permitir testes sem abrir o share sheet real.
abstract class CompartilhamentoPlataforma {
  const CompartilhamentoPlataforma();

  bool get ehWeb;

  bool webShareDisponivel();

  Future<bool> compartilharWeb({
    required String titulo,
    required String texto,
  });

  Future<void> compartilharNativo({
    required String titulo,
    required String texto,
  });

  Future<void> copiar(String texto);

  void abrirWhatsApp(String texto);
}

/// Implementação usada pelo app: menu nativo no Android, Web Share API no Web
/// e WhatsApp/cópia como alternativas quando o navegador não oferece share.
class CompartilhamentoPlataformaPadrao extends CompartilhamentoPlataforma {
  const CompartilhamentoPlataformaPadrao();

  @override
  bool get ehWeb => kIsWeb;

  @override
  bool webShareDisponivel() => webShareDisponivelNativo();

  @override
  Future<bool> compartilharWeb({
    required String titulo,
    required String texto,
  }) =>
      compartilharViaWebShare(titulo: titulo, texto: texto);

  @override
  Future<void> compartilharNativo({
    required String titulo,
    required String texto,
  }) =>
      SharePlus.instance.share(
        ShareParams(text: texto, title: titulo, subject: titulo),
      );

  @override
  Future<void> copiar(String texto) =>
      Clipboard.setData(ClipboardData(text: texto));

  @override
  void abrirWhatsApp(String texto) => abrirWhatsAppNativo(texto);
}

/// Serviço de compartilhamento de vans.
abstract class CompartilhamentoVan {
  const CompartilhamentoVan();

  Future<void> compartilhar({
    required BuildContext context,
    required String titulo,
    required String texto,
  });
}

class CompartilhamentoPadrao extends CompartilhamentoVan {
  const CompartilhamentoPadrao({
    this.plataforma = const CompartilhamentoPlataformaPadrao(),
  });

  final CompartilhamentoPlataforma plataforma;

  /// Mensagem única usada em todas as plataformas: apenas nome da van e código.
  /// Nenhum dado de aluno entra neste texto.
  static String mensagem({
    required String nomeVan,
    required String codigo,
  }) =>
      'Entre na van $nomeVan no VanGo com o código $codigo.';

  @override
  Future<void> compartilhar({
    required BuildContext context,
    required String titulo,
    required String texto,
  }) async {
    if (!plataforma.ehWeb) {
      await plataforma.compartilharNativo(titulo: titulo, texto: texto);
      return;
    }

    if (plataforma.webShareDisponivel()) {
      final compartilhado = await plataforma.compartilharWeb(
        titulo: titulo,
        texto: texto,
      );
      if (compartilhado) return;
    }

    if (!context.mounted) return;
    await _mostrarAlternativasWeb(context, texto);
  }

  Future<void> _mostrarAlternativasWeb(
    BuildContext context,
    String texto,
  ) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Compartilhar código',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Escolha como enviar o convite da van.'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar mensagem'),
              onTap: () async {
                await plataforma.copiar(texto);
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (context.mounted) {
                  mostrarToast(context, 'Mensagem copiada.');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded),
              title: const Text('Compartilhar no WhatsApp'),
              onTap: () {
                plataforma.abrirWhatsApp(texto);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
