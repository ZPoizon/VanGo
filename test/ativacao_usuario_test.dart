import 'package:flutter_test/flutter_test.dart';
import 'package:vango/core/resultado.dart';
import 'package:vango/data/firebase/firestore_mappers.dart';
import 'package:vango/models/usuario.dart';

void main() {
  group('situacaoAtivacaoDe', () {
    test('campo ativo oficial prevalece quando é true', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': true,
        'status': 'ativo',
      });

      expect(situacao.ativo, isTrue);
      expect(situacao.conflito, isFalse);
      expect(situacao.podeAcessar, isTrue);
      expect(situacao.status, StatusConta.ativo);
    });

    test('campo ativo oficial prevalece quando é false', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': false,
        'status': 'desativado',
      });

      expect(situacao.ativo, isFalse);
      expect(situacao.conflito, isFalse);
      expect(situacao.podeAcessar, isFalse);
    });

    test('documento antigo sem ativo usa apenas status', () {
      final ativo = situacaoAtivacaoDe(<String, dynamic>{'status': 'ativo'});
      final pendente =
          situacaoAtivacaoDe(<String, dynamic>{'status': 'pendente'});

      expect(ativo.podeAcessar, isTrue);
      expect(pendente.podeAcessar, isFalse);
      expect(pendente.status, StatusConta.pendente);
    });

    test('ativo true com status pendente é conflito e bloqueia', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': true,
        'status': 'pendente',
      });

      expect(situacao.conflito, isTrue);
      expect(situacao.ativo, isFalse);
      expect(situacao.podeAcessar, isFalse);
    });

    test('ativo false com status ativo é conflito e bloqueia', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': false,
        'status': 'ativo',
      });

      expect(situacao.conflito, isTrue);
      expect(situacao.podeAcessar, isFalse);
    });

    test('ativo com tipo inválido bloqueia por falha fechada', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': 'true',
        'status': 'ativo',
      });

      expect(situacao.conflito, isTrue);
      expect(situacao.ativo, isFalse);
      expect(situacao.podeAcessar, isFalse);
    });

    test('ativo sem status passa a ser a fonte da ativação', () {
      final ativo = situacaoAtivacaoDe(<String, dynamic>{'ativo': true});
      final inativo = situacaoAtivacaoDe(<String, dynamic>{'ativo': false});

      expect(ativo.podeAcessar, isTrue);
      expect(ativo.status, StatusConta.ativo);
      expect(inativo.podeAcessar, isFalse);
      expect(inativo.status, StatusConta.desativado);
    });

    test('documento vazio permanece bloqueado', () {
      final situacao = situacaoAtivacaoDe(const <String, dynamic>{});

      expect(situacao.podeAcessar, isFalse);
      expect(situacao.status, StatusConta.pendente);
    });
  });

  group('enumDe', () {
    test('aceita os valores reais do Firestore em maiúsculas', () {
      expect(
        enumDe(PerfilUsuario.values, 'MOTORISTA', PerfilUsuario.aluno),
        PerfilUsuario.motorista,
      );
      expect(
        enumDe(PerfilUsuario.values, 'ALUNO', PerfilUsuario.aluno),
        PerfilUsuario.aluno,
      );
    });

    test('aceita status em maiúsculas', () {
      final situacao = situacaoAtivacaoDe(<String, dynamic>{
        'ativo': true,
        'status': 'ATIVO',
      });

      expect(situacao.conflito, isFalse);
      expect(situacao.status, StatusConta.ativo);
      expect(situacao.podeAcessar, isTrue);
    });
  });

  group('enumDeOuNulo', () {
    test('perfil ausente ou desconhecido não vira aluno automaticamente', () {
      expect(
        enumDeOuNulo(PerfilUsuario.values, 'MOTORISTA'),
        PerfilUsuario.motorista,
      );
      expect(enumDeOuNulo(PerfilUsuario.values, null), isNull);
      expect(enumDeOuNulo(PerfilUsuario.values, 'VISITANTE'), isNull);
      expect(enumDeOuNulo(PerfilUsuario.values, 42), isNull);
    });
  });

  group('mensagens de login', () {
    test('credenciais inválidas não são descritas como falta de internet', () {
      final mensagem = LoginResultado.credenciaisInvalidas.mensagem;

      expect(mensagem.toLowerCase(), contains('incorretos'));
      expect(mensagem.toLowerCase(), isNot(contains('internet')));
      expect(mensagem.toLowerCase(), isNot(contains('conex')));
    });

    test('permissão negada tem mensagem própria', () {
      final mensagem = LoginResultado.permissoesNegadas.mensagem;

      expect(mensagem.toLowerCase(), contains('permiss'));
      expect(mensagem.toLowerCase(), isNot(contains('internet')));
      expect(mensagem.toLowerCase(), isNot(contains('conex')));
    });

    test('somente offline cita conexão', () {
      expect(
        LoginResultado.offline.mensagem.toLowerCase(),
        contains('conex'),
      );
    });
  });

  group('Usuario', () {
    test('ativoFirestore sobrescreve a derivação por status', () {
      final usuario = Usuario(
        id: 'uid',
        nome: 'Teste',
        email: 'teste@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        ativoFirestore: false,
      );

      expect(usuario.ativo, isFalse);
      expect(usuario.podeAcessar, isFalse);
    });

    test('copyWith preserva ativo e conflito', () {
      final original = Usuario(
        id: 'uid',
        nome: 'Teste',
        email: 'teste@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        ativoFirestore: true,
        conflitoAtivacao: true,
      );

      final copia = original.copyWith(nome: 'Outro');

      expect(copia.ativo, isTrue);
      expect(copia.conflitoAtivacao, isTrue);
      expect(copia.podeAcessar, isFalse);
      expect(copia.nome, 'Outro');
    });
  });
}
