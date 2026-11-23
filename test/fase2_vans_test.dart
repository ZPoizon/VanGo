import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vango/core/share/compartilhamento.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/features/driver/vans/create_van_screen.dart';
import 'package:vango/features/driver/vans/van_detail_screen.dart';
import 'package:vango/models/grupo.dart';
import 'package:vango/models/usuario.dart';

import 'support/fake_path_provider.dart';

class _PlataformaFalsa extends CompartilhamentoPlataforma {
  _PlataformaFalsa({
    required this.ehWeb,
    required this.webShareDisponivelFlag,
  });

  @override
  final bool ehWeb;

  final bool webShareDisponivelFlag;

  int compartilhamentosNativos = 0;
  int compartilhamentosWeb = 0;
  final List<String> copias = <String>[];
  final List<String> whatsapp = <String>[];

  @override
  bool webShareDisponivel() => webShareDisponivelFlag;

  @override
  Future<bool> compartilharWeb({
    required String titulo,
    required String texto,
  }) async {
    compartilhamentosWeb++;
    return true;
  }

  @override
  Future<void> compartilharNativo({
    required String titulo,
    required String texto,
  }) async {
    compartilhamentosNativos++;
  }

  @override
  Future<void> copiar(String texto) async {
    copias.add(texto);
  }

  @override
  void abrirWhatsApp(String texto) => whatsapp.add(texto);
}

class _CompartilhamentoRegistrador extends CompartilhamentoVan {
  int chamadas = 0;
  String? texto;
  String? titulo;

  @override
  Future<void> compartilhar({
    required BuildContext context,
    required String titulo,
    required String texto,
  }) async {
    chamadas++;
    this.titulo = titulo;
    this.texto = texto;
  }
}

Widget _comStore(Widget filho, DemoStore store) {
  return MaterialApp(
    home: StoreScope(notifier: store, child: filho),
  );
}

void _tela(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<DemoStore> _motoristaComVan() async {
  final store = DemoStore.demo();
  final cadastro = await store.cadastrarMotorista(
    nome: 'Motorista Teste',
    email: 'motorista.fase2@teste.com',
    telefone: '15999999999',
    senha: '123456',
  );
  expect(cadastro.sucesso, isTrue, reason: cadastro.mensagem);
  final criacao = await store.criarGrupo(
    nome: 'Van Compartilhada',
    cidadeOrigem: 'Origem',
    cidadeDestino: 'Destino',
    periodo: PeriodoVan.manha,
    horarioSaida: '07:15',
  );
  expect(criacao.sucesso, isTrue, reason: criacao.mensagem);
  return store;
}

Widget _botaoCompartilhar(CompartilhamentoVan servico) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => servico.compartilhar(
              context: context,
              titulo: 'VanGo — Van A',
              texto: CompartilhamentoPadrao.mensagem(
                nomeVan: 'Van A',
                codigo: '123456',
              ),
            ),
            child: const Text('Compartilhar'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(FakePathProvider.instalar);
  tearDownAll(FakePathProvider.remover);

  test('mensagem de convite contém apenas nome da van e código', () {
    final mensagem = CompartilhamentoPadrao.mensagem(
      nomeVan: 'Van Compartilhada',
      codigo: '123456',
    );
    expect(mensagem, contains('Van Compartilhada'));
    expect(mensagem, contains('123456'));
    expect(mensagem, isNot(contains('Aluno')));
    expect(mensagem, isNot(contains('@')));
  });

  group('criação de van', () {
    testWidgets('celular usa grade de duas colunas uniforme e sem exemplos', (
      tester,
    ) async {
      _tela(tester, const Size(400, 1100));
      await tester.pumpWidget(
        _comStore(const CreateVanScreen(), DemoStore.demo()),
      );

      expect(find.text('Cidade de origem'), findsOneWidget);
      expect(find.text('Cidade de destino'), findsOneWidget);
      expect(find.text('Ex.: Capão Bonito'), findsNothing);
      expect(find.text('Ex.: Itapetininga'), findsNothing);

      final opcoes = <Rect>[];
      for (final nome in ['manha', 'tarde', 'noite', 'personalizado']) {
        final finder = find.byKey(Key('periodo-$nome'));
        expect(finder, findsOneWidget);
        opcoes.add(tester.getRect(finder));
      }
      expect(opcoes.map((r) => r.width).toSet().length, 1);
      expect(opcoes.map((r) => r.height).toSet().length, 1);
      expect(opcoes[0].top, closeTo(opcoes[1].top, 1));
      expect(opcoes[2].top, greaterThan(opcoes[0].top));
      expect(opcoes[2].left, closeTo(opcoes[0].left, 1));

      final horarioTopo = tester
          .getRect(find.text('Horário habitual de saída (opcional)'))
          .top;
      expect(horarioTopo, greaterThan(opcoes.last.bottom));

      await tester.tap(find.byKey(const Key('periodo-personalizado')));
      await tester.pump();
      expect(find.text('Descreva o período'), findsOneWidget);
      expect(
        tester.getRect(find.text('Descreva o período')).top,
        greaterThan(horarioTopo),
      );
    });

    testWidgets('desktop alinha as quatro opções em uma única linha', (
      tester,
    ) async {
      _tela(tester, const Size(1100, 900));
      await tester.pumpWidget(
        _comStore(const CreateVanScreen(), DemoStore.demo()),
      );

      final opcoes = <Rect>[];
      for (final nome in ['manha', 'tarde', 'noite', 'personalizado']) {
        opcoes.add(tester.getRect(find.byKey(Key('periodo-$nome'))));
      }
      expect(opcoes.map((r) => r.top).toSet().length, 1);
      expect(opcoes.map((r) => r.width).toSet().length, 1);
    });
  });

  group('compartilhamento da van', () {
    testWidgets('botão usa o serviço real sem gerar código novo', (tester) async {
      _tela(tester, const Size(900, 1000));
      late DemoStore store;
      // A criação da van persiste a seleção via path_provider: fora do
      // runAsync o canal de método nunca responde dentro da zona de teste.
      await tester.runAsync(() async {
        store = await _motoristaComVan();
      });
      final grupos = await store.carregarMeusGrupos();
      final grupo = grupos.firstWhere((g) => g.nome == 'Van Compartilhada');
      await store.salvarAluno(
        Usuario(
          id: 'aluno-sigiloso',
          nome: 'Aluno Sigiloso',
          email: 'sigiloso@teste.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.pendente,
          ativoFirestore: false,
          grupoId: grupo.id,
        ),
      );

      final compartilhamento = _CompartilhamentoRegistrador();
      await tester.pumpWidget(
        _comStore(
          VanDetailScreen(
            grupoId: grupo.id,
            compartilhamento: compartilhamento,
          ),
          store,
        ),
      );
      await tester.pumpAndSettle();

      final codigoAntes = (await store.buscarGrupoPorId(grupo.id))!.codigo;
      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();

      expect(compartilhamento.chamadas, 1);
      expect(compartilhamento.titulo, contains('Van Compartilhada'));
      expect(compartilhamento.texto, contains('Van Compartilhada'));
      expect(compartilhamento.texto, contains(codigoAntes));
      expect(compartilhamento.texto, isNot(contains('Aluno Sigiloso')));
      expect(
        (await store.buscarGrupoPorId(grupo.id))!.codigo,
        codigoAntes,
      );
    });

    testWidgets('Android abre somente o compartilhamento nativo', (tester) async {
      final plataforma = _PlataformaFalsa(
        ehWeb: false,
        webShareDisponivelFlag: false,
      );
      await tester.pumpWidget(
        _botaoCompartilhar(CompartilhamentoPadrao(plataforma: plataforma)),
      );

      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();

      expect(plataforma.compartilhamentosNativos, 1);
      expect(plataforma.compartilhamentosWeb, 0);
      expect(find.text('Copiar mensagem'), findsNothing);
    });

    testWidgets('Web com Web Share API usa a API do navegador', (tester) async {
      final plataforma = _PlataformaFalsa(
        ehWeb: true,
        webShareDisponivelFlag: true,
      );
      await tester.pumpWidget(
        _botaoCompartilhar(CompartilhamentoPadrao(plataforma: plataforma)),
      );

      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();

      expect(plataforma.compartilhamentosWeb, 1);
      expect(plataforma.compartilhamentosNativos, 0);
      expect(find.text('Copiar mensagem'), findsNothing);
    });

    testWidgets('Web sem Web Share API oferece copiar e WhatsApp', (
      tester,
    ) async {
      final plataforma = _PlataformaFalsa(
        ehWeb: true,
        webShareDisponivelFlag: false,
      );
      await tester.pumpWidget(
        _botaoCompartilhar(CompartilhamentoPadrao(plataforma: plataforma)),
      );

      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar mensagem'), findsOneWidget);
      expect(find.text('Compartilhar no WhatsApp'), findsOneWidget);

      await tester.tap(find.text('Copiar mensagem'));
      await tester.pumpAndSettle();
      expect(plataforma.copias, hasLength(1));
      expect(plataforma.copias.first, contains('123456'));

      await tester.tap(find.text('Compartilhar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartilhar no WhatsApp'));
      await tester.pumpAndSettle();
      expect(plataforma.whatsapp, hasLength(1));
      expect(plataforma.whatsapp.first, contains('123456'));
    });
  });
}
