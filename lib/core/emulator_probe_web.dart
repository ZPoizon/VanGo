import 'dart:html' as html;

Future<void> probeEmulatorHost(
  String host,
  int port,
  String name,
  String projectId,
) async {
  try {
    await html.HttpRequest.request(
      'http://$host:$port/',
      method: 'GET',
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    throw StateError(
      'Emulador $name indisponível em http://$host:$port/. '
      'Inicie Auth+Firestore no mesmo projectId ($projectId) antes do app. '
      'Fallback para produção não permitido. Detalhe: $e',
    );
  }
}
