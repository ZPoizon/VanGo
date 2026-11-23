// Import condicional exclusivo da Web, usado apenas para sondar os emuladores
// antes de chamar useAuthEmulator/useFirestoreEmulator/useEmulator do Storage.
// A migração para
// package:web fica fora do escopo desta consolidação.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
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
      'Inicie Auth+Firestore+Storage no mesmo projectId ($projectId) '
      'antes do app. '
      'Fallback para produção não permitido. Detalhe: $e',
    );
  }
}
