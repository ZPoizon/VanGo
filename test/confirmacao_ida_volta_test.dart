import 'package:flutter_test/flutter_test.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/presenca.dart';
import 'package:vango/models/usuario.dart';

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
}
