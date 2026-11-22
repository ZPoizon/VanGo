import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/router.dart';
import 'package:vango/core/store.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/usuario.dart';

Widget _criarApp(VanGoStore store, GoRouter router) {
  return StoreScope(
    notifier: store,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// O rótulo do VangoTextField fica em um Text irmão do TextFormField.
Finder _campo(String rotulo) => find.descendant(
  of: find.ancestor(of: find.text(rotulo), matching: find.byType(Column)),
  matching: find.byType(TextFormField),
);

/// O perfil é um ListView longo: aumenta a viewport para todos os campos e botões
/// ficarem montados de uma vez nos testes.
void _usarTelaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<DemoStore> _alunoRecemCadastrado() async {
  final store = DemoStore.demo();
  final resultado = await store.cadastrarAluno(
    nome: 'Maria Aluna',
    email: 'maria@teste.com',
    telefone: '15988888888',
    instituicao: 'IFSP',
    turno: Turno.matutino,
    endereco: 'Rua A, 10',
    senha: '123456',
  );
  expect(resultado.sucesso, isTrue);
  expect(store.autenticado, isTrue);
  expect(store.usuarioAtual!.status, StatusConta.pendente);
  expect(store.usuarioAtual!.grupoId, isNull);
  return store;
}

Future<GoRouter> _abrirHome(WidgetTester tester, DemoStore store) async {
  final router = criarRouter(store);
  await tester.pumpWidget(_criarApp(store, router));
  await tester.pumpAndSettle();
  expect(router.state.uri.path, '/student/home');
  return router;
}

Future<void> _solicitarEntrada(WidgetTester tester) async {
  await tester.tap(find.text('Entrar em um grupo'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '123456');
  await tester.tap(find.text('Buscar Van'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Solicitar entrada nesta van'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'seta Voltar retorna do cadastro de motorista para a escolha de perfil',
    (tester) async {
      final store = DemoStore.demo();
      final router = criarRouter(store);
      await tester.pumpWidget(_criarApp(store, router));
      await tester.pumpAndSettle();

      router.go('/login');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/signup/choice');

      await tester.tap(find.text('Sou motorista'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/signup/driver');

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/signup/choice');
    },
  );

  testWidgets('tela de código exige sessão e volta para o login se deslogado', (
    tester,
  ) async {
    final store = DemoStore.demo();
    final router = criarRouter(store);
    await tester.pumpWidget(_criarApp(store, router));
    await tester.pumpAndSettle();

    router.go('/signup/enter-group');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/login');
    expect(store.autenticado, isFalse);
  });

  testWidgets('cadastro de motorista abre Minhas vans sem criar uma van', (
    tester,
  ) async {
    final store = DemoStore.demo();
    final router = criarRouter(store);
    await tester.pumpWidget(_criarApp(store, router));
    router.go('/signup/driver');
    await tester.pumpAndSettle();

    expect(find.text('Nome da van / rota'), findsNothing);

    final campos = find.byType(TextFormField);
    expect(campos, findsNWidgets(4));
    await tester.enterText(campos.at(0), 'Joao Motorista');
    await tester.enterText(campos.at(1), 'joao@teste.com');
    await tester.enterText(campos.at(2), '15999999999');
    await tester.enterText(campos.at(3), '123456');

    await tester.tap(find.text('Criar conta de motorista'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/driver/vans');
    expect(find.text('Você ainda não tem uma van'), findsOneWidget);
    expect(find.text('Criar minha primeira van'), findsOneWidget);
    expect(store.usuarioAtual!.grupoId, isNull);

    router.go('/driver/home');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/vans');
  });

  testWidgets('cadastro de aluno pela tela abre a Home sem grupo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = DemoStore.demo();
    final router = criarRouter(store);
    await tester.pumpWidget(_criarApp(store, router));
    router.go('/signup/student');
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    expect(campos, findsNWidgets(5));
    await tester.enterText(campos.at(0), 'Maria Aluna');
    await tester.enterText(campos.at(1), 'maria@teste.com');
    await tester.enterText(campos.at(2), '15988888888');
    await tester.enterText(campos.at(3), 'Rua A, 10');
    await tester.enterText(campos.at(4), '123456');

    await tester.tap(find.text('Criar conta de aluno').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/student/home');
    expect(find.text('Você ainda não está em uma van'), findsOneWidget);
    expect(find.text('Entrar em um grupo'), findsOneWidget);
    expect(store.usuarioAtual!.grupoId, isNull);
    expect(store.autenticado, isTrue);
  });

  testWidgets(
    'botão Entrar em um grupo abre o código e Voltar retorna à Home sem logout',
    (tester) async {
      final store = await _alunoRecemCadastrado();
      final router = await _abrirHome(tester, store);

      await tester.tap(find.text('Entrar em um grupo'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/signup/enter-group');
      expect(find.text('Entrar em uma Van'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/student/home');
      expect(find.text('Você ainda não está em uma van'), findsOneWidget);
      expect(store.autenticado, isTrue);
    },
  );

  testWidgets('solicitação pendente mostra nome da van e aguarda aprovação', (
    tester,
  ) async {
    final store = await _alunoRecemCadastrado();
    final router = await _abrirHome(tester, store);

    await _solicitarEntrada(tester);

    expect(router.state.uri.path, '/student/home');
    expect(
      find.text('Van do Roberto (Capão Bonito → Itapetininga)'),
      findsOneWidget,
    );
    expect(find.text('Aguardando aprovação'), findsOneWidget);
    expect(find.text('Entrar em um grupo'), findsNothing);
    expect(store.autenticado, isTrue);
  });

  testWidgets(
    'aluno pendente acessa perfil e sai, mas não acessa rotas privadas',
    (tester) async {
      _usarTelaAlta(tester);
      final store = await _alunoRecemCadastrado();
      final router = await _abrirHome(tester, store);

      router.go('/student/today');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/student/home');

      await tester.tap(find.text('Meu perfil'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/student/profile');
      expect(find.text('Meu perfil'), findsOneWidget);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(store.autenticado, isFalse);
    },
  );

  testWidgets('recusa informa motivo e permite nova tentativa sem logout', (
    tester,
  ) async {
    final store = await _alunoRecemCadastrado();
    final router = await _abrirHome(tester, store);
    await _solicitarEntrada(tester);

    await store.recusarAluno(store.usuarioAtual!.id, motivo: 'Vaga limitada');
    await tester.pumpAndSettle();

    expect(find.text('Solicitação recusada'), findsOneWidget);
    expect(find.text('Motivo: Vaga limitada'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(store.autenticado, isTrue);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/signup/enter-group');

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/student/home');
    expect(find.text('Solicitação recusada'), findsOneWidget);
  });

  testWidgets('aprovação do motorista libera o painel normal automaticamente', (
    tester,
  ) async {
    final store = await _alunoRecemCadastrado();
    final router = await _abrirHome(tester, store);
    await _solicitarEntrada(tester);

    expect(find.text('Aguardando aprovação'), findsOneWidget);

    await store.aprovarAluno(store.usuarioAtual!.id);
    await tester.pumpAndSettle();

    expect(find.text('Aguardando aprovação'), findsNothing);
    expect(find.text('Você ainda não está em uma van'), findsNothing);
    expect(find.text('Chamada de amanhã'), findsOneWidget);

    router.go('/student/today');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/student/today');
  });

  // -------------------------------------------------- Fase 1.3: perfil

  testWidgets(
    'aluno sem grupo salva telefone e endereço e vê os dados atualizados',
    (tester) async {
      _usarTelaAlta(tester);
      final store = await _alunoRecemCadastrado();
      final router = await _abrirHome(tester, store);
      router.go('/student/profile');
      await tester.pumpAndSettle();

      final telefone = _campo('Telefone');
      final endereco = _campo('Endereço de embarque');
      await tester.enterText(telefone, '(15) 98888-7777');
      await tester.enterText(endereco, 'Rua Nova, 99');
      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();

      expect(store.usuarioAtual!.telefone, '(15) 98888-7777');
      expect(store.usuarioAtual!.enderecoEmbarque, 'Rua Nova, 99');
      expect(
        tester.widget<TextFormField>(telefone).controller!.text,
        '(15) 98888-7777',
      );
      expect(
        tester.widget<TextFormField>(endereco).controller!.text,
        'Rua Nova, 99',
      );
      expect(find.text('Perfil atualizado.'), findsOneWidget);

      // Reabrir a tela com a mesma store simula o recarregamento do perfil.
      router.go('/student/home');
      await tester.pumpAndSettle();
      router.go('/student/profile');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_campo('Telefone')).controller!.text,
        '(15) 98888-7777',
      );
    },
  );

  testWidgets('cancelar edição restaura os valores carregados', (tester) async {
    _usarTelaAlta(tester);
    final store = await _alunoRecemCadastrado();
    final router = await _abrirHome(tester, store);
    router.go('/student/profile');
    await tester.pumpAndSettle();

    final telefone = _campo('Telefone');
    await tester.enterText(telefone, '(15) 90000-0000');
    await tester.tap(find.text('Cancelar edição'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(telefone).controller!.text,
      '15988888888',
    );
    expect(store.usuarioAtual!.telefone, '15988888888');
    expect(find.text('Alterações descartadas.'), findsOneWidget);
  });

  testWidgets('salvar somente o telefone preserva os demais dados do aluno', (
    tester,
  ) async {
    _usarTelaAlta(tester);
    final store = await _alunoRecemCadastrado();
    final router = await _abrirHome(tester, store);
    router.go('/student/profile');
    await tester.pumpAndSettle();

    await tester.enterText(_campo('Telefone'), '(15) 96666-5555');
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();

    final aluno = store.usuarioAtual!;
    expect(aluno.telefone, '(15) 96666-5555');
    expect(aluno.instituicao, 'IFSP');
    expect(aluno.turno, Turno.matutino);
    expect(aluno.enderecoEmbarque, 'Rua A, 10');
  });

  testWidgets('motorista sem grupo abre o perfil e edita só nome e telefone', (
    tester,
  ) async {
    _usarTelaAlta(tester);
    final store = DemoStore.demo();
    await store.entrarComo(PerfilUsuario.motorista);
    final router = criarRouter(store);
    await tester.pumpWidget(_criarApp(store, router));
    await tester.pump();
    await tester.pump();
    expect(router.state.uri.path, '/driver/vans');

    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/profile');
    expect(find.text('Instituição'), findsNothing);
    expect(find.text('Endereço de embarque'), findsNothing);
    expect(find.text('Referência do endereço'), findsNothing);
    expect(find.text('Turno'), findsNothing);

    final campos = find.byType(TextFormField);
    expect(campos, findsNWidgets(2));
    await tester.enterText(campos.at(0), 'Roberto Novo');
    await tester.enterText(campos.at(1), '(15) 92222-3333');
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();

    final motorista = store.usuarioAtual!;
    expect(motorista.nome, 'Roberto Novo');
    expect(motorista.telefone, '(15) 92222-3333');
    expect(motorista.instituicao, isNull);
    expect(motorista.enderecoEmbarque, isNull);
  });
}
