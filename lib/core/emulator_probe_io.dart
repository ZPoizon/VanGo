import 'dart:io';

Future<void> probeEmulatorHost(
  String host,
  int port,
  String name,
  String projectId,
) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('http://$host:$port/'));
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    client.close(force: true);
  } catch (e) {
    throw StateError(
      'Emulador $name indisponível em http://$host:$port/. '
      'Inicie Auth+Firestore no mesmo projectId ($projectId) antes do app. '
      'Fallback para produção não permitido. Detalhe: $e',
    );
  }
}
