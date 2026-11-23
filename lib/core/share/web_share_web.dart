import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

JSObject? _navegador() {
  final nav = _window.getProperty('navigator'.toJS);
  return nav.isA<JSObject>() ? nav as JSObject : null;
}

bool webShareDisponivelNativo() {
  final nav = _navegador();
  if (nav == null) return false;
  return nav.getProperty('share'.toJS).isA<JSFunction>();
}

/// Usa a Web Share API do navegador quando ela está disponível.
///
/// Retorna `false` quando a API não existe ou quando o usuário cancela, para
/// que a interface possa oferecer as alternativas (copiar/WhatsApp).
Future<bool> compartilharViaWebShare({
  required String titulo,
  required String texto,
}) async {
  final nav = _navegador();
  if (nav == null) return false;
  final funcao = nav.getProperty('share'.toJS);
  if (!funcao.isA<JSFunction>()) return false;

  final dados = <String, String>{
    'title': titulo,
    'text': texto,
  }.jsify();
  if (dados == null) return false;

  try {
    final promise = (funcao as JSFunction).callAsFunction(nav, dados)
        as JSPromise<JSAny?>;
    await promise.toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Abre o WhatsApp Web com a mensagem já preenchida.
void abrirWhatsAppNativo(String texto) {
  final url = 'https://wa.me/?text=${Uri.encodeComponent(texto)}';
  final funcao = _window.getProperty('open'.toJS);
  if (!funcao.isA<JSFunction>()) return;
  (funcao as JSFunction).callAsFunction(
    _window,
    url.toJS,
    '_blank'.toJS,
  );
}
