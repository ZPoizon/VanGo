import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

/// Fallback usado quando a rota foi aberta por `go` (sem pilha para `pop`).
String? _rotaAnterior(String caminho) {
  // Aluno autenticado pode abrir a tela de código a partir da Home. Sem pilha
  // de navegação, o Voltar deve levá-lo de volta ao próprio painel.
  if (caminho == '/signup/enter-group') return '/student/home';
  if (caminho == '/student/profile') return '/student/home';
  if (caminho == '/driver/profile') return '/driver/home';
  if (caminho.startsWith('/driver/vans/')) return '/driver/vans';
  if (caminho == '/signup/choice') return '/login';
  if (caminho.startsWith('/signup/')) return '/signup/choice';
  return null;
}

class VangoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VangoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  /// Ação explícita do botão Voltar. Quando informada, tem prioridade sobre o
  /// pop/go padrão e evita redirecionamentos indevidos ao login.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBackButton,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                  return;
                }
                final router = GoRouter.maybeOf(context);
                if (router != null && context.canPop()) {
                  context.pop();
                  return;
                }
                if (router != null) {
                  final anterior = _rotaAnterior(
                    GoRouterState.of(context).uri.path,
                  );
                  if (anterior != null) {
                    context.go(anterior);
                    return;
                  }
                }
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            )
          : null,
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
    );
  }
}
