/// Implementação neutra usada em plataformas que não são Web.
///
/// A versão Web é selecionada por import condicional em `compartilhamento.dart`.
bool webShareDisponivelNativo() => false;

Future<bool> compartilharViaWebShare({
  required String titulo,
  required String texto,
}) async =>
    false;

void abrirWhatsAppNativo(String texto) {}
