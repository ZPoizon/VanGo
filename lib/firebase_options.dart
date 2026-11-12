import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuração do Firebase por plataforma.
///
/// Há duas formas de configurar:
///
/// 1. **Recomendado:** rodar `flutterfire configure` no projeto. O comando
///    sobrescreve este arquivo com os valores reais do seu projeto.
/// 2. **Sem CLI:** informar os valores em tempo de compilação com
///    `--dart-define-from-file=firebase.local.json` (use
///    `firebase.local.example.json` como base).
///
/// Enquanto os valores estiverem vazios, o app inicia em **modo demonstração**
/// (dados em memória), sem quebrar o build.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String _appIdAndroid = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const String _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const String _appIdMacos = String.fromEnvironment(
    'FIREBASE_APP_ID_MACOS',
  );
  static const String _appIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.vango.vango',
  );
  static const String _macosBundleId = String.fromEnvironment(
    'FIREBASE_MACOS_BUNDLE_ID',
    defaultValue: 'com.vango.vango',
  );

  static String get _appIdAtual {
    if (kIsWeb) return _appIdWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _appIdAndroid;
      case TargetPlatform.iOS:
        return _appIdIos;
      case TargetPlatform.macOS:
        return _appIdMacos;
      default:
        return '';
    }
  }

  static String get _bucketPadrao {
    if (_storageBucket.isNotEmpty) return _storageBucket;
    return '$_projectId.firebasestorage.app';
  }

  /// `true` quando há configuração suficiente para inicializar o Firebase.
  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _appIdAtual.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError(
        'Firebase não configurado. Rode "flutterfire configure" ou informe '
        'os valores via --dart-define-from-file=firebase.local.json.',
      );
    }

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _appIdWeb,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty
            ? '$_projectId.firebaseapp.com'
            : _authDomain,
        storageBucket: _bucketPadrao,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _appIdAndroid,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _bucketPadrao,
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _appIdIos,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _bucketPadrao,
          iosBundleId: _iosBundleId,
        );
      case TargetPlatform.macOS:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _appIdMacos,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _bucketPadrao,
          iosBundleId: _macosBundleId,
        );
      default:
        throw UnsupportedError(
          'Firebase não é suportado nesta plataforma: '
          '${defaultTargetPlatform.name}.',
        );
    }
  }
}
