import '../models/chamada.dart';
import '../models/padrao_semanal.dart';
import '../models/presenca.dart';
import '../models/usuario.dart';
import '../models/viagem.dart';

/// Dados de demonstração da Etapa 1 (sem Firebase).
abstract final class DemoData {
  static const String grupoId = 'grupo-capao-itape';
  static const String motoristaId = 'motorista-1';
  static const String alunoLogadoId = 'aluno-1';

  static const String instituicaoPadrao = 'Fatec';

  static const List<String> instituicoes = <String>[
    'Fatec',
    'ETEC',
    'UNIP',
    'Uniesp',
    'Outra',
  ];

  static List<Usuario> usuarios() {
    final agora = DateTime.now();
    return <Usuario>[
      Usuario(
        id: motoristaId,
        nome: 'Roberto Silva',
        email: 'roberto@motorista.com',
        perfil: PerfilUsuario.motorista,
        status: StatusConta.ativo,
        telefone: '(15) 99888-7766',
        criadoEm: agora.subtract(const Duration(days: 400)),
      ),
      Usuario(
        id: alunoLogadoId,
        nome: 'Lucas Martins',
        email: 'lucas@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99630-8871',
        instituicao: 'UNIP',
        turno: Turno.matutino,
        enderecoEmbarque: 'R. Floriano Peixoto, 522',
        referenciaEndereco: 'Portão 2, ao lado da farmácia',
        criadoEm: agora.subtract(const Duration(days: 120)),
      ),
      Usuario(
        id: 'aluno-2',
        nome: 'Ana Clara Souza',
        email: 'anaclara@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99774-1820',
        instituicao: 'ETEC',
        turno: Turno.matutino,
        enderecoEmbarque: 'Av. Massaichi Kakihara, 91',
        criadoEm: agora.subtract(const Duration(days: 90)),
      ),
      Usuario(
        id: 'aluno-3',
        nome: 'Felipe Santos',
        email: 'felipe@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99207-7134',
        instituicao: 'Fatec',
        turno: Turno.matutino,
        enderecoEmbarque: 'R. Nove de Julho, 332',
        criadoEm: agora.subtract(const Duration(days: 80)),
      ),
      Usuario(
        id: 'aluno-4',
        nome: 'Henrique Almeida',
        email: 'henrique@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99111-2233',
        instituicao: 'Fatec',
        turno: Turno.noturno,
        enderecoEmbarque: 'R. das Flores, 100',
        criadoEm: agora.subtract(const Duration(days: 70)),
      ),
      Usuario(
        id: 'aluno-5',
        nome: 'Marina Rocha',
        email: 'marina@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99555-1020',
        instituicao: 'Fatec',
        turno: Turno.noturno,
        enderecoEmbarque: 'R. Sete de Setembro, 210',
        criadoEm: agora.subtract(const Duration(days: 60)),
      ),
      Usuario(
        id: 'aluno-6',
        nome: 'Beatriz Moreira',
        email: 'beatriz@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99444-5566',
        instituicao: 'Uniesp',
        turno: Turno.noturno,
        enderecoEmbarque: 'Av. Brasil, 450',
        criadoEm: agora.subtract(const Duration(days: 50)),
      ),
      Usuario(
        id: 'aluno-7',
        nome: 'Gabriel Lima',
        email: 'gabriel@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.pendente,
        telefone: '(15) 99777-8899',
        instituicao: 'Fatec',
        turno: Turno.matutino,
        enderecoEmbarque: 'R. XV de Novembro, 88',
        criadoEm: agora.subtract(const Duration(days: 2)),
      ),
      Usuario(
        id: 'aluno-8',
        nome: 'Carla Mendes',
        email: 'carla@aluno.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        grupoId: grupoId,
        telefone: '(15) 99321-4455',
        instituicao: 'UNIP',
        turno: Turno.matutino,
        enderecoEmbarque: 'R. Dom Pedro II, 74',
        criadoEm: agora.subtract(const Duration(days: 40)),
      ),
    ];
  }

  static Map<String, RespostaPresenca> respostas() {
    final agora = DateTime.now();
    return <String, RespostaPresenca>{
      alunoLogadoId: RespostaPresenca(alunoId: alunoLogadoId),
      'aluno-2': RespostaPresenca(
        alunoId: 'aluno-2',
        ida: RespostaSentido.vai,
        volta: RespostaSentido.naoVai,
        respondidoEm: agora.subtract(const Duration(hours: 3)),
      ),
      'aluno-3': RespostaPresenca(
        alunoId: 'aluno-3',
        ida: RespostaSentido.vai,
        volta: RespostaSentido.vai,
        respondidoEm: agora.subtract(const Duration(hours: 4)),
      ),
      'aluno-4': RespostaPresenca(
        alunoId: 'aluno-4',
        ida: RespostaSentido.naoVai,
        volta: RespostaSentido.naoVai,
        respondidoEm: agora.subtract(const Duration(hours: 5)),
      ),
      'aluno-5': RespostaPresenca(
        alunoId: 'aluno-5',
        ida: RespostaSentido.vai,
        volta: RespostaSentido.vai,
        respondidoEm: agora.subtract(const Duration(hours: 2)),
        estouIndo: true,
        estouIndoEm: agora.subtract(const Duration(minutes: 18)),
        avisadoEm: agora.subtract(const Duration(minutes: 20)),
      ),
      'aluno-6': RespostaPresenca(
        alunoId: 'aluno-6',
        ida: RespostaSentido.naoVai,
        volta: RespostaSentido.vai,
        respondidoEm: agora.subtract(const Duration(hours: 6)),
        liberadoEm: agora.subtract(const Duration(minutes: 10)),
        avisadoEm: agora.subtract(const Duration(minutes: 25)),
      ),
      'aluno-7': RespostaPresenca(alunoId: 'aluno-7'),
      'aluno-8': RespostaPresenca(
        alunoId: 'aluno-8',
        ida: RespostaSentido.vai,
        volta: RespostaSentido.vai,
        respondidoEm: agora.subtract(const Duration(hours: 1)),
      ),
    };
  }

  static Chamada chamadaAmanha() {
    final agora = DateTime.now();
    return Chamada(
      id: 'chamada-${agora.millisecondsSinceEpoch}',
      grupoId: grupoId,
      motoristaId: motoristaId,
      dataServico: DateTime(agora.year, agora.month, agora.day + 1),
      status: StatusChamada.aberta,
      criadaEm: agora.subtract(const Duration(hours: 8)),
      abertaEm: agora.subtract(const Duration(hours: 8)),
    );
  }

  static Map<int, PadraoSemanalDia> padraoSemanal() {
    return <int, PadraoSemanalDia>{
      for (var dia = DateTime.monday; dia <= DateTime.sunday; dia++)
        dia: PadraoSemanalDia(
          diaSemana: dia,
          vaiIda: dia <= DateTime.friday,
          vaiVolta: dia <= DateTime.friday,
          entraAs: dia <= DateTime.friday ? '06:30' : null,
          saiAs: dia <= DateTime.friday ? '22:10' : null,
        ),
    };
  }

  static List<Viagem> historico() {
    final hoje = DateTime.now();
    final alunos = usuarios()
        .where((u) => u.perfil == PerfilUsuario.aluno && u.ativo)
        .toList();

    Viagem criar({
      required DateTime data,
      required SentidoViagem sentido,
      required int confirmados,
      required bool liberado,
    }) {
      final selecionados = alunos.take(confirmados).toList();
      return Viagem(
        id: 'hist-${data.millisecondsSinceEpoch}-${sentido.name}',
        chamadaId: 'hist-chamada-${data.millisecondsSinceEpoch}',
        grupoId: grupoId,
        dataViagem: data,
        sentido: sentido,
        status: StatusViagem.encerrada,
        iniciadaEm: sentido == SentidoViagem.ida
            ? DateTime(data.year, data.month, data.day, 6, 35)
            : DateTime(data.year, data.month, data.day, 22, 8),
        encerradaEm: sentido == SentidoViagem.ida
            ? DateTime(data.year, data.month, data.day, 8, 2)
            : DateTime(data.year, data.month, data.day, 23, 34),
        confirmacoes: selecionados
            .map(
              (aluno) => ConfirmacaoViagem(
                alunoId: aluno.id,
                status: RespostaSentido.vai,
                estouIndo: true,
                estouIndoEm: DateTime(data.year, data.month, data.day, 6, 20),
                liberadoEm: sentido == SentidoViagem.volta && liberado
                    ? DateTime(data.year, data.month, data.day, 21, 50)
                    : null,
              ),
            )
            .toList(),
      );
    }

    return <Viagem>[
      criar(
        data: DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        ).subtract(const Duration(days: 1)),
        sentido: SentidoViagem.volta,
        confirmados: 5,
        liberado: true,
      ),
      criar(
        data: DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        ).subtract(const Duration(days: 1)),
        sentido: SentidoViagem.ida,
        confirmados: 6,
        liberado: false,
      ),
      criar(
        data: DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        ).subtract(const Duration(days: 2)),
        sentido: SentidoViagem.volta,
        confirmados: 4,
        liberado: true,
      ),
      criar(
        data: DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        ).subtract(const Duration(days: 2)),
        sentido: SentidoViagem.ida,
        confirmados: 5,
        liberado: false,
      ),
      criar(
        data: DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
        ).subtract(const Duration(days: 3)),
        sentido: SentidoViagem.ida,
        confirmados: 6,
        liberado: false,
      ),
    ];
  }
}
