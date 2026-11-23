import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vango/core/store.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/features/driver/home/driver_home_screen.dart';
import 'package:vango/models/chamada.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';

import 'support/fake_path_provider.dart';

Widget _app(VanGoStore store) {
  return StoreScope(
    notifier: store,
    child: const MaterialApp(home: DriverHomeScreen()),
  );
}

Future<DemoStore> _motorista() async {
  final store = DemoStore.demo();
  await store.entrarComo(PerfilUsuario.motorista);
  return store;
}

Future<void> _abrirPainel(WidgetTester tester, DemoStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FakePathProvider.instalar);
  tearDownAll(FakePathProvider.remover);

  group('Fase 4: conclusão e cancelamento operacional', () {
    test('conclui ida e volta preservando os dois registros no histórico', () async {
      final store = await _motorista();
      expect((await store.encerrarChamada()).sucesso, isTrue);
      final chamadaId = store.chamadaAmanha!.id;

      final ida = await store.iniciarViagem(SentidoViagem.ida);
      expect(ida.sucesso, isTrue, reason: ida.mensagem);
      final concluiIda = await store.encerrarViagem();
      expect(concluiIda.sucesso, isTrue, reason: concluiIda.mensagem);
      expect(store.historico.first.concluida, isTrue);
      expect(store.historico.first.sentido, SentidoViagem.ida);

      final volta = await store.iniciarViagem(SentidoViagem.volta);
      expect(volta.sucesso, isTrue, reason: volta.mensagem);
      final concluiVolta = await store.encerrarViagem();
      expect(concluiVolta.sucesso, isTrue, reason: concluiVolta.mensagem);
      expect(concluiVolta.mensagem, contains('concluída com sucesso'));

      final concluidas = store.historico
          .where((v) => v.chamadaId == chamadaId && v.concluida)
          .toList();
      expect(concluidas.length, 2);
      expect(
        concluidas.map((v) => v.sentido).toSet(),
        {SentidoViagem.ida, SentidoViagem.volta},
      );
      expect(store.viagemAtual, isNull);
    });

    test('cancela chamada já encerrada sem apagar respostas antigas', () async {
      final store = await _motorista();
      await store.encerrarChamada();
      await store.entrarComo(PerfilUsuario.aluno);
      await store.responderChamada(ida: true, volta: true);
      await store.entrarComo(PerfilUsuario.motorista);

      final respostasAntes = store.totalRespostas;
      final cancelamento = await store.cancelarChamada(motivo: 'Imprevisto');

      expect(cancelamento.sucesso, isTrue, reason: cancelamento.mensagem);
      expect(store.chamadaAmanha?.status, StatusChamada.cancelada);
      expect(store.chamadaAmanha?.motivoCancelamento, 'Imprevisto');
      expect(store.totalRespostas, respostasAntes);
    });

    test('bloqueia volta antes da ida e impedir reiniciar sentido registrado', () async {
      final store = await _motorista();
      await store.encerrarChamada();

      final voltaAntesDaIda = await store.iniciarViagem(SentidoViagem.volta);
      expect(voltaAntesDaIda.sucesso, isFalse);
      expect(voltaAntesDaIda.mensagem, contains('Conclua a viagem de ida'));

      await store.iniciarViagem(SentidoViagem.ida);
      await store.encerrarViagem();
      final segundaIda = await store.iniciarViagem(SentidoViagem.ida);
      expect(segundaIda.sucesso, isFalse);
      expect(segundaIda.mensagem, contains('não pode ser iniciada novamente'));
    });

    testWidgets('ação principal conclui a viagem e separa o cancelamento', (
      tester,
    ) async {
      final store = await _motorista();
      await store.encerrarChamada();
      await store.iniciarViagem(SentidoViagem.ida);
      await _abrirPainel(tester, store);

      expect(find.text('Concluir viagem'), findsOneWidget);
      expect(find.text('Cancelar viagem'), findsOneWidget);
      expect(find.text('Encerrar'), findsNothing);

      await tester.tap(find.text('Concluir viagem'));
      await tester.pumpAndSettle();
      expect(find.text('Concluir viagem de IDA?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Concluir viagem'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.viagemAtual, isNull);
      expect(store.historico.first.concluida, isTrue);
      expect(find.text('Iniciar VOLTA'), findsOneWidget);
      expect(find.text('Iniciar IDA'), findsNothing);
    });

    testWidgets('viagem cancelada oferece nova chamada sem reiniciar a viagem', (
      tester,
    ) async {
      final store = await _motorista();
      await store.encerrarChamada();
      await store.iniciarViagem(SentidoViagem.ida);
      await _abrirPainel(tester, store);

      await tester.tap(find.text('Cancelar viagem'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancelar viagem'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abrir chamada de amanhã'), findsOneWidget);
      expect(find.text('Iniciar IDA'), findsNothing);
      expect(store.historico.first.cancelada, isTrue);

      final repetida = await store.iniciarViagem(SentidoViagem.ida);
      expect(repetida.sucesso, isFalse);
    });

    testWidgets('volta concluída mostra operação concluída no painel', (
      tester,
    ) async {
      final store = await _motorista();
      await store.encerrarChamada();
      await store.iniciarViagem(SentidoViagem.ida);
      await store.encerrarViagem();
      await store.iniciarViagem(SentidoViagem.volta);
      await _abrirPainel(tester, store);

      await tester.tap(find.text('Concluir viagem'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Concluir viagem'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Operação concluída com sucesso'), findsOneWidget);
      expect(find.text('Ida e volta concluídas com sucesso.'), findsOneWidget);
      expect(find.text('Abrir chamada de amanhã'), findsOneWidget);
    });

    test('aluno não altera resposta após a chamada ser encerrada', () async {
      final store = await _motorista();
      await store.encerrarChamada();
      await store.entrarComo(PerfilUsuario.aluno);

      expect(store.respostaBloqueada, isTrue);
      final tentativa = await store.responderChamada(ida: true);
      expect(tentativa.sucesso, isFalse);
    });
  });
}
