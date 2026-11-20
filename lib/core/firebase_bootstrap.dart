import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
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

  static Future<bool> initialize() async {
    _disponivel = false;

    if (!_plataformaSuportada) {
      debugPrint(
        '[Firebase] plataforma ${defaultTargetPlatform.name} não suportada. '
        'Usando modo demonstração.',
      );
      return false;
    }

    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        '[Firebase] credenciais ausentes. Usando modo demonstração. '
        'Rode "flutterfire configure" ou use firebase.local.json.',
      );
      return false;
    }

    try {
      final opcoes = DefaultFirebaseOptions.currentPlatform;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: opcoes);
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }
      await PushNotifications.instance.inicializar();
      debugPrint(
        '[Firebase] conectado ao projeto ${opcoes.projectId} '
        '(${kIsWeb ? 'web' : defaultTargetPlatform.name}).',
      );
      _disponivel = true;
      return true;
    } catch (error, stack) {
      debugPrint('[Firebase] falha na inicialização: $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }
}
