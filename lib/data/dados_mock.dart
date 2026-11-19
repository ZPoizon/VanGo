import '../models/presenca.dart';
import '../models/usuario.dart';

class AlunoPresenca {
  final Usuario aluno;
  final StatusPresenca status;
  final String? horarioAvisado;
  final String? horarioEstouIndo;

  const AlunoPresenca({
    required this.aluno,
    required this.status,
    this.horarioAvisado,
    this.horarioEstouIndo,
  });
}

class ViagemHistorico {
  final String id;
  final String data;
  final String tipo;
  final String horario;
  final int confirmados;
  final int total;

  const ViagemHistorico({
    required this.id,
    required this.data,
    required this.tipo,
    required this.horario,
    required this.confirmados,
    required this.total,
  });
}

class DadosMock {
  static final Usuario usuarioAlunoLogado = Usuario(
    id: 'u1',
    nome: 'Lucas Martins',
    email: 'lucas@aluno.com',
    perfil: PerfilUsuario.aluno,
    status: StatusConta.ativo,
    instituicao: 'UNIP',
    telefone: '(15) 99630-8871',
    enderecoEmbarque: 'R. Floriano Peixoto, 522',
    turno: Turno.matutino,
  );

  static final Usuario usuarioMotoristaLogado = Usuario(
    id: 'm1',
    nome: 'Roberto Silva',
    email: 'roberto@motorista.com',
    perfil: PerfilUsuario.motorista,
    status: StatusConta.ativo,
    telefone: '(15) 99888-7766',
  );

  // Lista de alunos da lista do dia (Image 3 do Figma)
  static List<AlunoPresenca> getListaDoDia() {
    return [
      AlunoPresenca(
        aluno: Usuario(
          id: '1',
          nome: 'Henrique Almeida',
          email: 'henrique@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'Fatec',
          turno: Turno.noturno,
        ),
        status: StatusPresenca.idaEVolta,
        horarioAvisado: '06:32',
        horarioEstouIndo: '06:42',
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '2',
          nome: 'Ana Clara Souza',
          email: 'anaclara@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'ETEC',
          telefone: '(15) 99774-1820',
          enderecoEmbarque: 'Av. Massaichi Kakihara, 91',
          turno: Turno.matutino,
        ),
        status: StatusPresenca.soIda,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '3',
          nome: 'Lucas Martins',
          email: 'lucas@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'Unip',
          telefone: '(15) 99630-8871',
          enderecoEmbarque: 'R. Floriano Peixoto, 522',
          turno: Turno.matutino,
        ),
        status: StatusPresenca.naoVai,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '4',
          nome: 'Marina Rocha',
          email: 'marina@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'Fatec',
          turno: Turno.noturno,
        ),
        status: StatusPresenca.semResposta,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '5',
          nome: 'Beatriz Moreira',
          email: 'beatriz@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'Uniesp',
          turno: Turno.noturno,
        ),
        status: StatusPresenca.soVolta,
        horarioEstouIndo: '06:45',
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '6',
          nome: 'Felipe Santos',
          email: 'felipe@email.com',
          perfil: PerfilUsuario.aluno,
          status: StatusConta.ativo,
          instituicao: 'Fatec',
          telefone: '(15) 99207-7134',
          enderecoEmbarque: 'R. Nove de Julho, 332',
          turno: Turno.matutino,
        ),
        status: StatusPresenca.idaEVolta,
      ),
    ];
  }

  // Lista cadastral de Alunos (Image 4 do Figma)
  static List<Usuario> getTodosAlunos() {
    return [
      Usuario(
        id: 'a1',
        nome: 'Ana Clara Souza',
        email: 'anaclara@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        instituicao: 'ETEC',
        turno: Turno.matutino,
        telefone: '(15) 99774-1820',
        enderecoEmbarque: 'Av. Massaichi Kakihara, 91',
      ),
      Usuario(
        id: 'a2',
        nome: 'Lucas Martins',
        email: 'lucas@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        instituicao: 'Unip',
        turno: Turno.matutino,
        telefone: '(15) 99630-8871',
        enderecoEmbarque: 'R. Floriano Peixoto, 522',
      ),
      Usuario(
        id: 'a3',
        nome: 'Felipe Santos',
        email: 'felipe@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        instituicao: 'Fatec',
        turno: Turno.matutino,
        telefone: '(15) 99207-7134',
        enderecoEmbarque: 'R. Nove de Julho, 332',
      ),
      Usuario(
        id: 'a4',
        nome: 'Henrique Almeida',
        email: 'henrique@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        instituicao: 'Fatec',
        turno: Turno.noturno,
        telefone: '(15) 99111-2233',
        enderecoEmbarque: 'R. das Flores, 100',
      ),
      Usuario(
        id: 'a5',
        nome: 'Beatriz Moreira',
        email: 'beatriz@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.ativo,
        instituicao: 'Uniesp',
        turno: Turno.noturno,
        telefone: '(15) 99444-5566',
        enderecoEmbarque: 'Av. Brasil, 450',
      ),
      Usuario(
        id: 'a6',
        nome: 'Gabriel Lima',
        email: 'gabriel@email.com',
        perfil: PerfilUsuario.aluno,
        status: StatusConta.pendente,
        instituicao: 'Fatec',
        telefone: '(15) 99777-8899',
        enderecoEmbarque: 'R. XV de Novembro, 88',
      ),
    ];
  }

  // Histórico de viagens (Image 5 do Figma)
  static List<ViagemHistorico> getHistoricoViagens() {
    return [
      ViagemHistorico(
        id: 'h1',
        data: '18 JUN',
        tipo: 'IDA',
        horario: '06:35 — 08:02',
        confirmados: 10,
        total: 12,
      ),
      ViagemHistorico(
        id: 'h2',
        data: '17 JUN',
        tipo: 'VOLTA',
        horario: '22:10 — 23:34',
        confirmados: 11,
        total: 12,
      ),
      ViagemHistorico(
        id: 'h3',
        data: '17 JUN',
        tipo: 'IDA',
        horario: '06:38 — 08:05',
        confirmados: 9,
        total: 12,
      ),
      ViagemHistorico(
        id: 'h4',
        data: '16 JUN',
        tipo: 'VOLTA',
        horario: '22:08 — 23:31',
        confirmados: 12,
        total: 12,
      ),
    ];
  }
}
