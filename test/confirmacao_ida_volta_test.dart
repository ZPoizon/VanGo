import 'package:flutter_test/flutter_test.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/presenca.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/models/viagem.dart';

void main() {
  late DemoStore store;
  late String alunoId;

  setUp(() async {
    store = DemoStore.demo();
    await store.entrarComo(PerfilUsuario.aluno);
    alunoId = store.usuarioAtual!.id;
  });

  RespostaPresenca resposta() => store.respostaDe(alunoId);

  test('confirmar somente a ida preserva a volta', () async {
    final resultado = await store.responderChamada(ida: true);

    expect(resultado.sucesso, isTrue);
    expect(resposta().ida, RespostaSentido.vai);
    expect(resposta().volta, RespostaSentido.semResposta);
    expect(resposta().statusCombinado, StatusPresenca.soIda);
  });

  test('ida e volta são alterados de forma independente', () async {
    await store.responderChamada(ida: true);
    await store.responderChamada(volta: false);

    expect(resposta().ida, RespostaSentido.vai);
    expect(resposta().volta, RespostaSentido.naoVai);
    expect(resposta().statusCombinado, StatusPresenca.soIda);

    await store.responderChamada(ida: false);

    expect(resposta().ida, RespostaSentido.naoVai);
    expect(resposta().volta, RespostaSentido.naoVai);
    expect(resposta().statusCombinado, StatusPresenca.naoVai);

    await store.responderChamada(volta: true);

    expect(resposta().ida, RespostaSentido.naoVai);
    expect(resposta().volta, RespostaSentido.vai);
    expect(resposta().statusCombinado, StatusPresenca.soVolta);
  });

  test('chamar sem sentido não grava resposta', () async {
    final resultado = await store.responderChamada();

    expect(resultado.sucesso, isFalse);
    expect(resposta().ida, RespostaSentido.semResposta);
    expect(resposta().volta, RespostaSentido.semResposta);
  });

  test('resposta é bloqueada após o encerramento da chamada', () async {
    await store.responderChamada(ida: true, volta: true);

    await store.entrarComo(PerfilUsuario.motorista);
    final encerramento = await store.encerrarChamada();
    expect(encerramento.sucesso, isTrue);

    await store.entrarComo(PerfilUsuario.aluno);
    final tentativa = await store.responderChamada(ida: false);

    expect(tentativa.sucesso, isFalse);
    expect(resposta().ida, RespostaSentido.vai);
    expect(resposta().volta, RespostaSentido.vai);
  });

  test('motorista não responde a própria chamada', () async {
    await store.entrarComo(PerfilUsuario.motorista);
    final resultado = await store.responderChamada(ida: true);

    expect(resultado.sucesso, isFalse);
  });

  test('primeira resposta não gera notificação', () async {
    await store.responderChamada(ida: true);
    await store.responderChamada(volta: false);

    expect(store.notificacoesResposta, isEmpty);
  });

  test('alteração da volta gera aviso e repetir a opção não duplica', () async {
    await store.responderChamada(ida: true, volta: false);
    expect(store.notificacoesResposta, isEmpty);

    await store.responderChamada(volta: true);

    expect(store.notificacoesResposta, hasLength(1));
    final aviso = store.notificacoesResposta.single;
    expect(aviso.alunoId, alunoId);
    expect(aviso.sentido, SentidoViagem.volta);
    expect(aviso.anterior, RespostaSentido.naoVai);
    expect(aviso.atual, RespostaSentido.vai);
    expect(aviso.mudanca, 'Volta: Não vai → Vai');

    await store.responderChamada(volta: true);

    expect(store.notificacoesResposta, hasLength(1));
  });

  test('alteração da ida gera aviso separado', () async {
    await store.responderChamada(ida: true, volta: true);
    await store.responderChamada(ida: false);

    expect(store.notificacoesResposta, hasLength(1));
    final aviso = store.notificacoesResposta.single;
    expect(aviso.sentido, SentidoViagem.ida);
    expect(aviso.mudanca, 'Ida: Vai → Não vai');
  });

  test('não notifica alteração recusada após o encerramento', () async {
    await store.responderChamada(ida: true, volta: false);

    await store.entrarComo(PerfilUsuario.motorista);
    await store.encerrarChamada();
    await store.entrarComo(PerfilUsuario.aluno);

    final resultado = await store.responderChamada(volta: true);

    expect(resultado.sucesso, isFalse);
    expect(store.notificacoesResposta, isEmpty);
  });
}
