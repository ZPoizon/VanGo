import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Handler executado em background/terminated pelo FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('[FCM] mensagem em background: ${message.messageId}');
  } catch (error) {
    debugPrint('[FCM] falha ao inicializar em background: $error');
  }
}

/// Registra o dispositivo no FCM e exibe notificações em foreground.
///
/// O envio real das notificações é feito pela Cloud Function em `functions/`,
/// disparada quando o motorista avisa os alunos.
class PushNotifications {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _inicializado = false;
  String? _uid;
  String? _grupoId;

  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'vango_chegada',
    'Avisos da van',
    description: 'Avisos de chegada e lembretes da chamada.',
    importance: Importance.max,
    playSound: true,
  );

  bool get _suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> inicializar() async {
    if (_inicializado || !_suportado) return;
    _inicializado = true;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );

      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_canal);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_mostrarEmForeground);
      // ignore: deprecated_member_use
      _messaging.onTokenRefresh.listen((token) => _salvarToken(token));
    } catch (error) {
      debugPrint('[FCM] falha ao inicializar notificações: $error');
    }
  }

  /// Pede permissão, salva o token em `usuarios/{uid}/tokens` e assina o tópico
  /// do grupo. Deve ser chamado depois de cada login.
  Future<void> registrarDispositivo({
    required String uid,
    required String grupoId,
  }) async {
    _uid = uid;
    _grupoId = grupoId;
    if (!_suportado) return;

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await _salvarToken(token);

      await _messaging.subscribeToTopic('grupo_$grupoId');
    } catch (error) {
      debugPrint('[FCM] falha ao registrar dispositivo: $error');
    }
  }

  Future<void> removerDispositivo() async {
    final uid = _uid;
    final grupoId = _grupoId;
    _uid = null;
    _grupoId = null;
    if (!_suportado || uid == null) return;

    try {
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .collection('tokens')
            .doc(token)
            .delete();
      }
      if (grupoId != null) {
        await _messaging.unsubscribeFromTopic('grupo_$grupoId');
      }
    } catch (error) {
      debugPrint('[FCM] falha ao remover dispositivo: $error');
    }
  }

  Future<void> _salvarToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .set(<String, dynamic>{
            'token': token,
            'plataforma': defaultTargetPlatform.name,
            'atualizadoEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[FCM] falha ao salvar token: $error');
    }
  }

  Future<void> _mostrarEmForeground(RemoteMessage message) async {
    // No iOS/macOS o próprio FCM já apresenta a notificação em foreground.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notificacao = message.notification;
    if (notificacao == null) return;

    await _local.show(
      id: notificacao.hashCode,
      title: notificacao.title,
      body: notificacao.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'vango_chegada',
          'Avisos da van',
          channelDescription: 'Avisos de chegada e lembretes da chamada.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['viagemId'],
    );
  }
}
