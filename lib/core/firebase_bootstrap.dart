import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'emulator_probe_stub.dart'
    if (dart.library.io) 'emulator_probe_io.dart'
    if (dart.library.html) 'emulator_probe_web.dart'
    as emulator_probe;
import 'notifications/push_notifications.dart';

/// Inicializa o Firebase quando as credenciais estão disponíveis.
///
/// Se o projeto não estiver configurado (ou a plataforma não for suportada),
/// retorna `false` e o app usa o [DemoStore] em memória.
abstract final class FirebaseBootstrap {
  static bool _disponivel = false;

  static bool get disponivel => _disponivel;

  static bool get _plataformaSuportada =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Motivo da última inicialização, para a tela de erro mostrar a causa real
  /// em vez de atribuir qualquer falha à conexão com a internet.
  static String? erro;

  static const bool _usarEmuladores = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const String _emuladorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const int _authEmuladorPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int _firestoreEmuladorPort = int.fromEnvironment(
    'FIREBASE_FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  static const int _storageEmuladorPort = int.fromEnvironment(
    'FIREBASE_STORAGE_EMULATOR_PORT',
    defaultValue: 9199,
  );

  static const String _emuladorProjectId = String.fromEnvironment(
    'FIREBASE_EMULATOR_PROJECT_ID',
    defaultValue: 'demo-vango',
  );

  static FirebaseOptions _opcoesParaEmulador(FirebaseOptions base) {
    return FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: _emuladorProjectId,
      authDomain: '$_emuladorProjectId.firebaseapp.com',
      storageBucket: '$_emuladorProjectId.appspot.com',
      measurementId: base.measurementId,
    );
  }

  static Future<void> _garantirEmuladoresDisponiveis() async {
    await emulator_probe.probeEmulatorHost(
      _emuladorHost,
      _authEmuladorPort,
      'Auth',
      _emuladorProjectId,
    );
    await emulator_probe.probeEmulatorHost(
      _emuladorHost,
      _firestoreEmuladorPort,
      'Firestore',
      _emuladorProjectId,
    );
    // O emulador de Storage responde 501 na raiz (não é um erro de conexão),
    // o que geraria ruído de console no Web. No Web confiamos no
    // useStorageEmulator: o upload falha explicitamente se ele estiver ausente.
    if (!kIsWeb) {
      await emulator_probe.probeEmulatorHost(
        _emuladorHost,
        _storageEmuladorPort,
        'Storage',
        _emuladorProjectId,
      );
    }
  }

  static Future<bool> initialize() async {
    _disponivel = false;
    erro = null;

    if (!_plataformaSuportada) {
      erro =
          'Plataforma $defaultTargetPlatform não suportada pelo '
          'Firebase nesta compilação.';
      debugPrint('[Firebase] $erro');
      return false;
    }

    if (!DefaultFirebaseOptions.isConfigured) {
      erro =
          'Credenciais do Firebase ausentes nesta plataforma. '
          'Rode "flutterfire configure" ou configure firebase.local.json.';
      debugPrint('[Firebase] $erro');
      return false;
    }

    try {
      final base = DefaultFirebaseOptions.currentPlatform;
      final opcoes = _usarEmuladores ? _opcoesParaEmulador(base) : base;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: opcoes);
      }
      if (_usarEmuladores) {
        await _garantirEmuladoresDisponiveis();
        // Conecta Auth/Firestore/Storage a emuladores locais. Usado apenas
        // para validação E2E; nunca habilitado em produção.
        await FirebaseAuth.instance.useAuthEmulator(
          _emuladorHost,
          _authEmuladorPort,
        );
        FirebaseFirestore.instance.useFirestoreEmulator(
          _emuladorHost,
          _firestoreEmuladorPort,
        );
        await FirebaseStorage.instance.useStorageEmulator(
          _emuladorHost,
          _storageEmuladorPort,
        );
        final projetoAtivo = Firebase.app().options.projectId;
        if (projetoAtivo != _emuladorProjectId) {
          throw StateError(
            'ProjectId do app ($projetoAtivo) difere do emulador '
            '($_emuladorProjectId). Fallback para produção não permitido.',
          );
        }
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
        debugPrint(
          '[Firebase] emuladores: auth=$_emuladorHost:$_authEmuladorPort '
          'firestore=$_emuladorHost:$_firestoreEmuladorPort '
          'storage=$_emuladorHost:$_storageEmuladorPort '
          'projectId=$_emuladorProjectId',
        );
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }
      try {
        await PushNotifications.instance.inicializar();
      } catch (fcmError) {
        debugPrint(
          '[FCM] Falha ao inicializar notificações (não-bloqueante): $fcmError',
        );
      }
      debugPrint(
        '[Firebase] conectado ao projeto ${opcoes.projectId} '
        '(${kIsWeb ? 'web' : defaultTargetPlatform.name}).',
      );
      _disponivel = true;
      return true;
    } catch (error, stack) {
      erro = error.toString();
      debugPrint('[Firebase] falha na inicialização: $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }
}
