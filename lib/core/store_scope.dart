import 'package:flutter/widgets.dart';

import 'store.dart';

class StoreScope extends InheritedNotifier<VanGoStore> {
  const StoreScope({
    super.key,
    required VanGoStore super.notifier,
    required super.child,
  });

  /// Observa a store e reconstrói o widget quando o estado muda.
  static VanGoStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope não encontrado na árvore de widgets.');
    return scope!.notifier!;
  }

  /// Lê a store sem criar dependência (uso em callbacks/initState).
  static VanGoStore read(BuildContext context) {
    final scope = context.findAncestorWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope não encontrado na árvore de widgets.');
    return scope!.notifier!;
  }
}
