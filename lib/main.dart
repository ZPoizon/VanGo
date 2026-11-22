import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vango/app/app.dart';
import 'package:vango/core/firebase_bootstrap.dart';
import 'package:vango/core/store.dart';
import 'package:vango/data/firebase/firebase_store.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/firebase_options.dart';

/// Ponto de entrada do VanGo.
///
/// Quando as credenciais do Firebase estão configuradas, o app inicializa o
/// [FirebaseStore]. Se houver falha de conexão na versão real, exibe tela de erro
/// com botão de tentar novamente em vez de fallback silencioso.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseConfigurado = DefaultFirebaseOptions.isConfigured;
  final firebaseDisponivel = await FirebaseBootstrap.initialize();

  // Em ambiente de produção configurado, se o Firebase falhar, não abre modo demo silencioso.
  if (firebaseConfigurado && !firebaseDisponivel) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF9F5F2),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF001941)),
        ),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: Color(0xFFFD5C3C),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Falha de Conexão com o Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001941),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Não foi possível conectar ao servidor real do VanGo. Verifique sua conexão com a internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF687386)),
                    ),
                    if (FirebaseBootstrap.erro != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        FirebaseBootstrap.erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF687386),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001941),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                      onPressed: () {
                        unawaited(main());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  final VanGoStore store = firebaseDisponivel
      ? FirebaseStore()
      : DemoStore.demo();

  unawaited(store.inicializar());

  runApp(VanGoApp(store: store));
}
