import 'package:flutter_test/flutter_test.dart';

import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/grupo.dart';
import 'package:vango/models/usuario.dart';

Future<DemoStore> _motoristaSemGrupo() async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'motorista cria várias vans com códigos únicos e troca de grupo',
    () async {
      final store = await _motoristaSemGrupo();

      final primeira = await store.criarGrupo(
        nome: 'Van Manhã',
        cidadeOrigem: 'Capão Bonito',
        cidadeDestino: 'Itapetininga',
        periodo: PeriodoVan.manha,
        horarioSaida: '07:00',
      );
      expect(primeira.sucesso, isTrue, reason: primeira.mensagem);

      final segunda = await store.criarGrupo(
        nome: 'Van Noite',
        cidadeOrigem: 'Itapetininga',
        cidadeDestino: 'Capão Bonito',
        periodo: PeriodoVan.noite,
      );
      expect(segunda.sucesso, isTrue, reason: segunda.mensagem);

      final grupos = await store.carregarMeusGrupos();
      expect(grupos.length, 2);
      final codigos = grupos.map((g) => g.codigo).toSet();
      expect(codigos.length, 2);
      for (final codigo in codigos) {
        expect(codigo, matches(RegExp(r'^\d{6}$')));
      }

      final primeiroId = grupos.first.id;
      final segundoId = grupos.last.id;
      expect(store.grupoSelecionado?.id, segundoId);

      await store.selecionarGrupo(primeiroId);
      expect(store.grupoSelecionado?.id, primeiroId);
      await store.selecionarGrupo(segundoId);
      expect(store.grupoSelecionado?.id, segundoId);
    },
  );

  test('alunos e solicitações são isolados por grupo selecionado', () async {
    final store = await _motoristaSemGrupo();

    final vanA = await store.criarGrupo(nome: 'Van A');
    expect(vanA.sucesso, isTrue);
    final grupos = await store.carregarMeusGrupos();
    final idA = grupos.first.id;

    await store.selecionarGrupo(idA);
    expect(store.alunosAtivos, isEmpty);

    final aluno = Usuario(
      id: 'aluno-isolado',
      nome: 'Aluno Isolado',
      email: 'isolado@teste.com',
      perfil: PerfilUsuario.aluno,
      status: StatusConta.pendente,
      ativoFirestore: false,
      grupoId: idA,
    );
    await store.salvarAluno(aluno);

    final solicitacoes = await store.carregarSolicitacoes(idA);
    expect(solicitacoes.map((a) => a.id), contains('aluno-isolado'));

    final vanB = await store.criarGrupo(nome: 'Van B');
    expect(vanB.sucesso, isTrue);
    final gruposDepois = await store.carregarMeusGrupos();
    final idB = gruposDepois.firstWhere((grupo) => grupo.nome == 'Van B').id;

    await store.selecionarGrupo(idB);
    expect(store.alunosAtivos, isEmpty);
    expect(await store.carregarSolicitacoes(idB), isEmpty);

    await store.selecionarGrupo(idA);
    expect(store.alunosPendentes.map((a) => a.id), contains('aluno-isolado'));
  });

  test('chamada, viagem e respostas não misturam ao trocar de van', () async {
    final store = await _motoristaSemGrupo();

    await store.criarGrupo(nome: 'Van A');
    final idA = store.grupoSelecionado?.id;
    expect(idA, isNotNull);

    final aberta = await store.abrirChamada();
    expect(aberta.sucesso, isTrue, reason: aberta.mensagem);
    expect(store.chamadaAmanha?.grupoId, idA);

    final novaVan = await store.criarGrupo(nome: 'Van B');
    expect(novaVan.sucesso, isTrue, reason: novaVan.mensagem);
    final idB = store.grupoSelecionado?.id;
    expect(idB, isNot(idA));
    expect(store.chamadaAmanha, isNull);
    expect(store.respostaBloqueada, isTrue);

    final reaberta = await store.abrirChamada();
    expect(reaberta.sucesso, isTrue, reason: reaberta.mensagem);
    expect(store.chamadaAmanha?.grupoId, idB);

    await store.selecionarGrupo(idA!);
    expect(store.chamadaAmanha, isNull);
  });

  test('motorista não altera código de van de outro motorista', () async {
    final store = await _motoristaSemGrupo();
    final resultado = await store.atualizarCodigoGrupo(
      'grupo-de-outro-motorista',
      '999999',
    );
    expect(resultado.sucesso, isFalse);
  });

  test('código gerado é permanente até solicitação explícita', () async {
    final store = await _motoristaSemGrupo();
    await store.criarGrupo(nome: 'Van Estável');
    final grupo = (await store.carregarMeusGrupos()).first;
    final codigoOriginal = grupo.codigo;

    await store.carregarMeusGrupos();
    final grupoDepois = (await store.carregarMeusGrupos()).first;
    expect(grupoDepois.codigo, codigoOriginal);

    final gerado = await store.gerarNovoCodigoGrupo(grupo.id);
    expect(gerado.sucesso, isTrue);
    final novoCodigo = (await store.carregarMeusGrupos()).first.codigo;
    expect(novoCodigo, isNot(codigoOriginal));
    expect(novoCodigo, matches(RegExp(r'^\d{6}$')));
  });
}
