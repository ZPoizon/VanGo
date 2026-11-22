import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implementação falsa do `path_provider` exclusiva para `flutter test`.
///
/// O plugin nativo não existe no ambiente de testes, então sem este fake o
/// [SelecaoGrupoStore] registra `MissingPluginException` e perde a persistência
/// local. Nada aqui é importado por `lib/`, portanto Android, iOS, macOS e Web
/// continuam usando as implementações reais do plugin.
abstract final class FakePathProvider {
  static const MethodChannel _canal = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  static Directory? _diretorio;

  static void instalar() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _diretorio ??= Directory.systemTemp.createTempSync(
      'vango_test_path_provider_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, _responder);
  }

  static void remover() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
    final diretorio = _diretorio;
    if (diretorio != null && diretorio.existsSync()) {
      diretorio.deleteSync(recursive: true);
    }
    _diretorio = null;
  }

  static Future<String> _responder(MethodCall chamada) async {
    switch (chamada.method) {
      case 'getApplicationSupportDirectory':
      case 'getApplicationDocumentsDirectory':
      case 'getTemporaryDirectory':
      case 'getDownloadsDirectory':
        return _diretorio!.path;
      default:
        // Não engole falha real: qualquer método não previsto continua
        // sinalizando ausência de implementação.
        throw MissingPluginException(
          'FakePathProvider não implementa ${chamada.method}',
        );
    }
  }
}
