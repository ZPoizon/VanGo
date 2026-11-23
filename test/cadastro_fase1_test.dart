import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/router.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/validadores.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/usuario.dart';

Widget _app(DemoStore store, GoRouter router) {
  return StoreScope(
    notifier: store,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// O rótulo do VangoTextField é um Text irmão do TextFormField.
Finder _campo(String rotulo) => find.descendant(
  of: find.ancestor(of: find.text(rotulo), matching: find.byType(Column)),
  matching: find.byType(TextFormField),
);

Future<void> _abrir(WidgetTester tester, GoRouter router, String rota) async {
  router.go(rota);
  await tester.pumpAndSettle();
}

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _preencherAluno(
  WidgetTester tester, {
  required String instituicao,
  required String cep,
  Turno? turno,
  String? turnoPersonalizado,
}) async {
  await tester.enterText(_campo('Nome completo'), 'Maria Custom');
  await tester.enterText(_campo('E-mail'), 'maria.custom@teste.com');
  await tester.enterText(_campo('Telefone'), '15988888888');
  await tester.enterText(_campo('Instituição'), instituicao);
  await tester.enterText(_campo('Endereço de embarque'), 'Rua B, 20');
  await tester.enterText(_campo('CEP'), cep);
  if (turno != null) {
    await tester.tap(find.text(turno.label));
    // O campo personalizado só entra na árvore após selecionar "Outro".
    await tester.pump();
  }
  if (turnoPersonalizado != null) {
    await tester.enterText(
      _campo('Turno personalizado'),
      turnoPersonalizado,
    );
  }
  await tester.enterText(_campo('Senha'), '123456');
  await tester.pump();
}

void main() {
  group('validadores e modelo da Fase 1', () {
    test('máscara e validação do CEP', () {
      expect(aplicarMascaraCep('18000000'), '18000-000');
      expect(aplicarMascaraCep('18000'), '18000');
      expect(aplicarMascaraCep('180000000000'), '18000-000');
      expect(validarCep('18000-000'), isNull);
      expect(validarCep('18000000'), isNull);
      expect(validarCep('1234'), contains('8 dígitos'));
      expect(validarCep(''), isNotNull);
    });

    test('confirmação de senha e turnos', () {
      expect(validarConfirmacaoSenha('123456', '123456'), isNull);
      expect(validarConfirmacaoSenha('654321', '123456'),
          'As senhas não coincidem.');
      expect(validarConfirmacaoSenha('', '123456'), isNotNull);
      expect(Turno.values.map((t) => t.label).toList(),
          ['Matutino', 'Vespertino', 'Noturno', 'Outro']);
      expect(
        Usuario(
          id: 'antigo',
          nome: 'Antigo',
          email: 'antigo@teste.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          turno: Turno.matutino,
        ).periodo,
        'Matutino',
      );
    });
  });

  group('cadastro do motorista', () {
    testWidgets('senha divergente bloqueia a criação da conta', (tester) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/signup/driver');

      await tester.enterText(_campo('Nome completo'), 'Joao Motorista');
      await tester.enterText(_campo('E-mail profissional'), 'joao@teste.com');
      await tester.enterText(_campo('Telefone / WhatsApp'), '15999999999');
      await tester.enterText(_campo('Senha de acesso'), '123456');
      await tester.enterText(_campo('Confirmar senha'), '654321');
      await tester.tap(find.text('Criar conta de motorista'));
      await tester.pumpAndSettle();

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(router.state.uri.path, '/signup/driver');
      expect(store.autenticado, isFalse);
    });

    testWidgets('olhos de senha e confirmação são independentes', (tester) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/signup/driver');

      expect(find.byTooltip('Mostrar senha'), findsOneWidget);
      expect(find.byTooltip('Mostrar confirmação'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _campo('Senha de acesso'),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
      expect(find.byTooltip('Mostrar confirmação'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _campo('Senha de acesso'),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isFalse,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _campo('Confirmar senha'),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Mostrar confirmação'));
      await tester.pump();
      expect(find.byTooltip('Ocultar confirmação'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _campo('Confirmar senha'),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isFalse,
      );

      await tester.enterText(_campo('Nome completo'), 'Joao Motorista');
      await tester.enterText(_campo('E-mail profissional'), 'joao@teste.com');
      await tester.enterText(_campo('Telefone / WhatsApp'), '15999999999');
      await tester.enterText(_campo('Senha de acesso'), '123456');
      await tester.enterText(_campo('Confirmar senha'), '123456');
      await tester.tap(find.text('Criar conta de motorista'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/driver/dashboard');
      expect(store.usuarioAtual!.perfil, PerfilUsuario.motorista);
    });
  });

  group('cadastro do aluno', () {
    testWidgets('instituição personalizada, CEP e turno vespertino persistem', (
      tester,
    ) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/signup/student');

      // Nenhuma instituição vem pré-selecionada.
      expect(
        tester.widget<TextFormField>(_campo('Instituição')).controller!.text,
        isEmpty,
      );
      await _preencherAluno(
        tester,
        instituicao: 'Instituição Personalizada',
        cep: '18000000',
        turno: Turno.vespertino,
      );
      expect(
        tester.widget<TextFormField>(_campo('CEP')).controller!.text,
        '18000-000',
      );

      await tester.tap(find.text('Criar conta de aluno').first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/student/home');
      final aluno = store.usuarioAtual!;
      expect(aluno.instituicao, 'Instituição Personalizada');
      expect(aluno.cep, '18000-000');
      expect(aluno.turno, Turno.vespertino);
      expect(aluno.periodo, 'Vespertino');
      expect(aluno.grupoId, isNull);

      // Reabrir a tela simula atualizar a página.
      await _abrir(tester, router, '/student/profile');
      expect(
        tester.widget<TextFormField>(_campo('Instituição')).controller!.text,
        'Instituição Personalizada',
      );
      expect(
        tester.widget<TextFormField>(_campo('CEP')).controller!.text,
        '18000-000',
      );
    });

    testWidgets('turno Outro aceita descrição personalizada', (tester) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/signup/student');

      await _preencherAluno(
        tester,
        instituicao: 'UNIP',
        cep: '18000000',
        turno: Turno.outro,
        turnoPersonalizado: 'Integrado',
      );
      expect(find.text('Turno personalizado'), findsOneWidget);
      await tester.tap(find.text('Criar conta de aluno').first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/student/home');
      final aluno = store.usuarioAtual!;
      expect(aluno.turno, Turno.outro);
      expect(aluno.turnoPersonalizado, 'Integrado');
      expect(aluno.periodo, 'Integrado');
      expect(aluno.grupoId, isNull);

      await _abrir(tester, router, '/student/profile');
      expect(
        tester.widget<TextFormField>(_campo('Turno personalizado'))
            .controller!
            .text,
        'Integrado',
      );
    });

    testWidgets('CEP inválido impede o cadastro', (tester) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/signup/student');

      await _preencherAluno(
        tester,
        instituicao: 'IFSP',
        cep: '1234',
        turno: Turno.noturno,
      );
      await tester.tap(find.text('Criar conta de aluno').first);
      await tester.pumpAndSettle();

      expect(find.text('Informe o CEP com 8 dígitos.'), findsOneWidget);
      expect(router.state.uri.path, '/signup/student');
      expect(store.autenticado, isFalse);
    });

    testWidgets('perfil antigo sem CEP continua editável', (tester) async {
      _telaAlta(tester);
      final store = DemoStore.demo();
      final resultado = await store.cadastrarAluno(
        nome: 'Aluno Antigo',
        email: 'antigo@teste.com',
        telefone: '15988888888',
        instituicao: 'IFSP',
        turno: Turno.noturno,
        endereco: 'Rua A, 1',
        senha: '123456',
      );
      expect(resultado.sucesso, isTrue);
      expect(store.usuarioAtual!.cep, isNull);

      final router = criarRouter(store);
      await tester.pumpWidget(_app(store, router));
      await _abrir(tester, router, '/student/profile');
      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Perfil atualizado.'), findsOneWidget);
      expect(store.usuarioAtual!.turno, Turno.noturno);
      expect(store.usuarioAtual!.cep, isNull);
    });
  });
}
