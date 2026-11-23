import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/router.dart';
import 'package:vango/core/selecao_grupo_store.dart';
import 'package:vango/core/store.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/grupo.dart';
import 'package:vango/models/usuario.dart';

import 'support/fake_path_provider.dart';

Widget _app(VanGoStore store, GoRouter router) {
  return StoreScope(
    notifier: store,
    child: MaterialApp.router(routerConfig: router),
  );
}

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _telaAmpla(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Algumas ações persistem a van ativa (path_provider). Em teste de widget, a
/// chamada de canal precisa de um Intervalo com I/O real. Esperar pela
/// condição observável evita depender de um atraso fixo (a suíte roda vários
/// arquivos em paralelo e o tempo de I/O varia).
Future<void> _esperarCondicao(
  WidgetTester tester,
  bool Function() condicao, {
  required String descricao,
}) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condicao()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('Tempo esgotado aguardando: $descricao');
}

Future<void> _tapComPersistencia(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
}

Future<DemoStore> _motoristaComUmaVan() async {
  final store = DemoStore.demo();
  await store.entrarComo(PerfilUsuario.motorista);
  return store;
}

Future<DemoStore> _motoristaSemVan() async {
  final store = DemoStore.demo();
  final resultado = await store.cadastrarMotorista(
    nome: 'Motorista Novo',
    email: 'novo.motorista@teste.com',
    telefone: '15999999999',
    senha: '123456',
  );
  expect(resultado.sucesso, isTrue, reason: resultado.mensagem);
  return store;
}

Finder _cartaoDaVan(String nome) => find.ancestor(
  of: find.text(nome),
  matching: find.byType(VangoCard),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    FakePathProvider.instalar();
    // Evita que um test anterior deixe uma seleção persistida em memória.
    await SelecaoGrupoStore.salvar(null);
  });
  tearDownAll(() {
    // Não apaga o diretório temporário: alguma escrita pode ainda estar
    // pendente quando o último teste termina no Windows.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  testWidgets('motorista novo sem vans entra no dashboard e não é redirecionado', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaSemVan();
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/driver/dashboard');
    expect(find.text('Olá, Motorista'), findsOneWidget);
    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(find.text('Você ainda não tem uma van'), findsOneWidget);
    expect(find.text('Criar minha primeira van'), findsOneWidget);
    expect(find.text('Acesso rápido'), findsNothing);
    expect(store.meusGrupos, isEmpty);
  });

  testWidgets('dashboard com uma van mostra resumo real e acessos funcionais', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    final grupos = await store.carregarMeusGrupos();
    final totalAlunos = await store.contarAlunosGrupo(grupos.first.id);
    final totalPendentes = await store.contarSolicitacoesGrupo(grupos.first.id);
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/driver/dashboard');
    expect(find.text('Vans cadastradas'), findsOneWidget);
    expect(find.text('Alunos ativos'), findsOneWidget);
    expect(find.text('Solicitações pendentes'), findsOneWidget);
    expect(find.text('Operação'), findsOneWidget);
    expect(find.text(grupos.first.nome), findsOneWidget);
    expect(find.text('$totalAlunos alunos ativos'), findsOneWidget);
    expect(
      find.text('$totalPendentes solicitações pendentes'),
      findsOneWidget,
    );
    expect(find.text('Minhas vans'), findsOneWidget);
    expect(find.text('Criar nova van'), findsOneWidget);
    expect(find.text('Solicitações de entrada'), findsOneWidget);
    expect(find.text('Alunos'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
  });

  testWidgets('duas vans aparecem separadamente com contagens próprias', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    await tester.runAsync(
      () => store.criarGrupo(
        nome: 'Van Noite',
        cidadeOrigem: 'Itapetininga',
        cidadeDestino: 'Capão Bonito',
        periodo: PeriodoVan.noite,
      ),
    );
    final grupos = await store.carregarMeusGrupos();
    expect(grupos.length, 2);
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    for (final grupo in grupos) {
      final cartao = _cartaoDaVan(grupo.nome);
      expect(cartao, findsOneWidget);
      final alunos = await store.contarAlunosGrupo(grupo.id);
      final pendentes = await store.contarSolicitacoesGrupo(grupo.id);
      expect(
        find.descendant(of: cartao, matching: find.text('$alunos alunos ativos')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cartao,
          matching: find.text('$pendentes solicitações pendentes'),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Abrir painel'), findsNWidgets(2));
    expect(find.text('Administrar'), findsNWidgets(2));
  });

  testWidgets('cria van pelo dashboard e retorna ao painel com a nova van', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaSemVan();
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar minha primeira van'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/vans/new');

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Van Nova Rota');
    await tester.enterText(campos.at(1), 'Sorocaba');
    await tester.enterText(campos.at(2), 'Itapetininga');
    await _tapComPersistencia(tester, find.text('Criar van'));
    await _esperarCondicao(
      tester,
      () =>
          router.state.uri.path == '/driver/dashboard' &&
          find.text('Van Nova Rota').evaluate().isNotEmpty,
      descricao: 'retorno ao dashboard com a van criada',
    );

    expect(router.state.uri.path, '/driver/dashboard');
    expect(find.text('Van Nova Rota'), findsOneWidget);
    expect(store.meusGrupos.length, 1);
    expect(store.meusGrupos.first.nome, 'Van Nova Rota');
  });

  testWidgets('após criar van a navegação continua respondendo e o refresh mantém o dashboard', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaSemVan();
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar minha primeira van'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Van Pós Criação');
    await tester.enterText(campos.at(1), 'Sorocaba');
    await tester.enterText(campos.at(2), 'Itapetininga');
    await _tapComPersistencia(tester, find.text('Criar van'));
    await _esperarCondicao(
      tester,
      () =>
          router.state.uri.path == '/driver/dashboard' &&
          find.text('Van Pós Criação').evaluate().isNotEmpty,
      descricao: 'retorno ao dashboard com a van criada',
    );

    expect(router.state.uri.path, '/driver/dashboard');
    expect(find.text('Van Pós Criação'), findsOneWidget);
    expect(store.meusGrupos.length, 1);

    // A navegação não travou após a criação (antigo refreshListenable: store).
    await tester.tap(find.text('Alunos'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/students');

    // Simula refresh: um novo GoRouter com a mesma sessão entra no dashboard.
    final routerDepois = criarRouter(store);
    await tester.pumpWidget(_app(store, routerDepois));
    await tester.pumpAndSettle();
    expect(routerDepois.state.uri.path, '/driver/dashboard');
    expect(find.text('Van Pós Criação'), findsOneWidget);
  });

  testWidgets('Meu perfil abre o perfil do motorista e Voltar retorna ao dashboard', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meu perfil').first);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/profile');

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/dashboard');
  });

  testWidgets('Sair da conta encerra a sessão a partir do dashboard', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    await _tapComPersistencia(tester, find.text('Sair da conta'));
    await _esperarCondicao(
      tester,
      () => router.state.uri.path == '/login',
      descricao: 'saída da conta',
    );
    expect(router.state.uri.path, '/login');
    expect(store.autenticado, isFalse);
  });

  testWidgets('selecionar uma van no dashboard abre o painel operacional correto', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    await tester.runAsync(
      () => store.criarGrupo(
        nome: 'Van Segunda',
        cidadeOrigem: 'Capão Bonito',
        cidadeDestino: 'Sorocaba',
        periodo: PeriodoVan.tarde,
      ),
    );
    final grupos = await store.carregarMeusGrupos();
    final primeira = grupos.firstWhere((g) => g.nome != 'Van Segunda');
    final segunda = grupos.firstWhere((g) => g.nome == 'Van Segunda');

    await tester.runAsync(() => store.selecionarGrupo(primeira.id));
    final abriu = await store.abrirChamada();
    expect(abriu.sucesso, isTrue, reason: abriu.mensagem);
    expect(store.chamadaAmanha, isNotNull);

    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    final cartaoSegunda = _cartaoDaVan(segunda.nome);
    await _tapComPersistencia(
      tester,
      find.descendant(of: cartaoSegunda, matching: find.text('Abrir painel')),
    );
    await _esperarCondicao(
      tester,
      () => router.state.uri.path == '/driver/home',
      descricao: 'abertura do painel da van selecionada',
    );

    expect(router.state.uri.path, '/driver/home');
    expect(store.grupoSelecionado?.id, segunda.id);
    // Nada da van anterior pode continuar visível no painel da nova.
    expect(store.chamadaAmanha, isNull);
    expect(store.alunosAtivos.isEmpty || store.alunosAtivos.every((a) => a.grupoId == segunda.id), isTrue);
  });

  testWidgets('atalho Solicitações de entrada mostra pendências das próprias vans', (
    tester,
  ) async {
    _telaAlta(tester);
    final store = await _motoristaComUmaVan();
    final grupos = await store.carregarMeusGrupos();
    final pendentes = await store.contarSolicitacoesGrupo(grupos.first.id) ?? 0;
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Solicitações de entrada'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/driver/requests');
    if (pendentes > 0) {
      expect(
        find.text('$pendentes solicitações aguardando análise'),
        findsOneWidget,
      );
      expect(find.text('Administrar solicitações'), findsOneWidget);
    } else {
      expect(find.text('Nenhuma solicitação pendente'), findsOneWidget);
    }
  });

  testWidgets('layout amplo organiza o dashboard em colunas sem transbordar', (
    tester,
  ) async {
    _telaAmpla(tester);
    final store = await _motoristaComUmaVan();
    await tester.runAsync(
      () => store.criarGrupo(nome: 'Van Tarde', periodo: PeriodoVan.tarde),
    );
    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Van Tarde'), findsOneWidget);
    expect(find.text('RESUMO'), findsOneWidget);
    expect(find.text('MINHAS VANS'), findsOneWidget);
  });

  testWidgets('aluno autenticado nunca acessa o dashboard do motorista', (
    tester,
  ) async {
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

    final router = criarRouter(store);
    await tester.pumpWidget(_app(store, router));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/student/home');

    router.go('/driver/dashboard');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/student/home');

    router.go('/driver/home');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/student/home');
  });
}
