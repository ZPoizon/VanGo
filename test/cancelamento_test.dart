import 'package:flutter_test/flutter_test.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/chamada.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';

import 'support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FakePathProvider.instalar);
  tearDownAll(FakePathProvider.remover);
  late DemoStore store;

  setUp(() async {
    store = DemoStore.demo();
    await store.entrarComo(PerfilUsuario.motorista);
  });

  group('Fase 3: Cancelamento de chamadas e viagens', () {
    test('1. motorista pode cancelar chamada ainda não iniciada com motivo opcional', () async {
      expect(store.chamadaAmanha, isNotNull);
      expect(store.chamadaAmanha!.aberta, isTrue);

      final resultado = await store.cancelarChamada(motivo: 'Chuva forte');

      expect(resultado.sucesso, isTrue);
      expect(store.chamadaAmanha!.status, StatusChamada.cancelada);
      expect(store.chamadaAmanha!.cancelada, isTrue);
      expect(store.chamadaAmanha!.motivoCancelamento, 'Chuva forte');
      expect(store.chamadaAmanha!.canceladaEm, isNotNull);
    });

    test(
      '2. motorista pode cancelar viagem em andamento com motivo opcional',
      () async {
        await store.encerrarChamada();
        final inicio = await store.iniciarViagem(SentidoViagem.ida);
        expect(inicio.sucesso, isTrue);
        expect(store.viagemAtual, isNotNull);

        final resultado = await store.cancelarViagem(
          motivo: 'Problema mecânico',
        );

        expect(resultado.sucesso, isTrue);
        expect(store.viagemAtual, isNull);
        expect(store.historico, isNotEmpty);

        final viagemCancelada = store.historico.first;
        expect(viagemCancelada.status, StatusViagem.cancelada);
        expect(viagemCancelada.cancelada, isTrue);
        expect(viagemCancelada.sentido, SentidoViagem.ida);
        expect(viagemCancelada.motivoCancelamento, 'Problema mecânico');
      },
    );

    test('4. enum StatusChamada e StatusViagem exibem rótulos corretos', () {
      expect(StatusChamada.aberta.label, 'Aberta');
      expect(StatusChamada.encerrada.label, 'Encerrada');
      expect(StatusChamada.cancelada.label, 'Cancelada');

      expect(StatusViagem.agendada.label, 'Agendada');
      expect(StatusViagem.emAndamento.label, 'Em andamento');
      expect(StatusViagem.encerrada.label, 'Concluída');
      expect(StatusViagem.cancelada.label, 'Cancelada');
    });

    test('5. impede iniciar viagem a partir de chamada cancelada', () async {
      await store.cancelarChamada(motivo: 'Cancelada pelo motorista');

      final resultado = await store.iniciarViagem(SentidoViagem.ida);

      expect(resultado.sucesso, isFalse);
      expect(resultado.mensagem, contains('chamada cancelada'));
      expect(store.viagemAtual, isNull);
    });

    test('5. impede reiniciar viagem cancelada anteriormente', () async {
      await store.encerrarChamada();
      await store.iniciarViagem(SentidoViagem.ida);
      await store.cancelarViagem(motivo: 'Imprevisto');

      final resultado = await store.iniciarViagem(SentidoViagem.ida);

      expect(resultado.sucesso, isFalse);
      expect(resultado.mensagem, contains('não pode ser iniciada novamente'));
    });

    test('6. impede cancelar novamente chamada já cancelada', () async {
      await store.cancelarChamada();

      final segundoTentativa = await store.cancelarChamada();

      expect(segundoTentativa.sucesso, isFalse);
      expect(segundoTentativa.mensagem, contains('já foi cancelada'));
    });

    test(
      '6. impede cancelar novamente viagem sem viagem em andamento',
      () async {
        final resultado = await store.cancelarViagem();

        expect(resultado.sucesso, isFalse);
        expect(resultado.mensagem, contains('Nenhuma viagem'));
      },
    );

    test('7. preserva chamadas e viagens canceladas no histórico sem apagar registros', () async {
      await store.encerrarChamada();
      await store.iniciarViagem(SentidoViagem.ida);
      await store.cancelarViagem(motivo: 'Cancelada no meio do trajeto');

      expect(store.historico, hasLength(greaterThanOrEqualTo(1)));
      final viagemHistorico = store.historico.first;
      expect(viagemHistorico.status, StatusViagem.cancelada);
      expect(store.viagemPorId(viagemHistorico.id), equals(viagemHistorico));
    });

    test(
      '8. cancelamento sem motivo opcional grava motivo como nulo',
      () async {
        final resultado = await store.cancelarChamada();

        expect(resultado.sucesso, isTrue);
        expect(store.chamadaAmanha!.status, StatusChamada.cancelada);
        expect(store.chamadaAmanha!.motivoCancelamento, isNull);
      },
    );

    test(
      '9. bloqueia resposta de alunos quando a chamada está cancelada',
      () async {
        await store.cancelarChamada(motivo: 'Sem aula amanhã');

        await store.entrarComo(PerfilUsuario.aluno);
        expect(store.respostaBloqueada, isTrue);

        final tentativa = await store.responderChamada(ida: true);
        expect(tentativa.sucesso, isFalse);
      },
    );

    test('10. operações aplicam-se somente à van selecionada', () async {
      await store.cancelarChamada(motivo: 'Van 1 sem serviço');
      expect(store.chamadaAmanha!.status, StatusChamada.cancelada);

      // Alternar van / grupo
      final vans = await store.carregarMeusGrupos();
      if (vans.length > 1) {
        await store.selecionarGrupo(vans.last.id);
        // Van 2 isolada
        expect(store.chamadaAmanha?.motivoCancelamento, isNull);
      }
    });
  });
}
