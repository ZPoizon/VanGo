import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vango/app/app.dart';
import 'package:vango/core/firebase_bootstrap.dart';
import 'package:vango/core/store.dart';
import 'package:vango/data/firebase/firebase_store.dart';
import 'package:vango/demo/demo_store.dart';

/// Ponto de entrada do VanGo.
///
/// Quando as credenciais do Firebase estão disponíveis (Android, iOS, macOS e
/// web), o app usa o [FirebaseStore]; caso contrário, inicia automaticamente no
/// modo demonstração com dados em memória.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseDisponivel = await FirebaseBootstrap.initialize();
  final VanGoStore store = firebaseDisponivel
      ? FirebaseStore()
      : DemoStore.demo();

  // A store carrega a sessão em segundo plano; o roteador reage quando estiver
  // pronta. Assim a tela de login aparece imediatamente.
  unawaited(store.inicializar());

  runApp(VanGoApp(store: store));
}
