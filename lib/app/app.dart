import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:vango/app/router.dart';
import 'package:vango/app/theme/app_theme.dart';
import 'package:vango/core/store.dart';
import 'package:vango/core/store_scope.dart';

class VanGoApp extends StatefulWidget {
  const VanGoApp({super.key, required this.store});

  final VanGoStore store;

  @override
  State<VanGoApp> createState() => _VanGoAppState();
}

class _VanGoAppState extends State<VanGoApp> {
  late final _router = criarRouter(widget.store);

  @override
  void dispose() {
    _router.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      notifier: widget.store,
      child: MaterialApp.router(
        title: 'VanGo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
