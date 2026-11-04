import '../models/usuario.dart';

class DadosMock {
  static final Usuario usuarioAlunoLogado = Usuario(
    id: 'u1',
    nome: 'Lucas Martins',
    email: 'lucas@aluno.com',
    perfil: PerfilUsuario.aluno,
    faculdade: 'UNIP',
    horarioEntrada: '08:00',
    horarioSaida: '12:10',
    telefone: '(15) 99630-8871',
    endereco: 'R. Floriano Peixoto, 522',
    periodo: 'Matutino',
  );

  static final Usuario usuarioMotoristaLogado = Usuario(
    id: 'm1',
    nome: 'Roberto Silva',
    email: 'roberto@motorista.com',
    perfil: PerfilUsuario.motorista,
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
          faculdade: 'Fatec',
          horarioEntrada: '19:00',
          horarioSaida: '22:10',
          periodo: 'Noturno',
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
          faculdade: 'ETEC',
          horarioEntrada: '07:30',
          horarioSaida: '12:00',
          telefone: '(15) 99774-1820',
          endereco: 'Av. Massaichi Kakihara, 91',
          periodo: 'Matutino',
        ),
        status: StatusPresenca.soIda,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '3',
          nome: 'Lucas Martins',
          email: 'lucas@email.com',
          perfil: PerfilUsuario.aluno,
          faculdade: 'Unip',
          horarioEntrada: '08:00',
          horarioSaida: '12:10',
          telefone: '(15) 99630-8871',
          endereco: 'R. Floriano Peixoto, 522',
          periodo: 'Matutino',
        ),
        status: StatusPresenca.naoVai,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '4',
          nome: 'Marina Rocha',
          email: 'marina@email.com',
          perfil: PerfilUsuario.aluno,
          faculdade: 'Fatec',
          horarioEntrada: '19:00',
          horarioSaida: '22:10',
          periodo: 'Noturno',
        ),
        status: StatusPresenca.semResposta,
      ),
      AlunoPresenca(
        aluno: Usuario(
          id: '5',
          nome: 'Beatriz Moreira',
          email: 'beatriz@email.com',
          perfil: PerfilUsuario.aluno,
          faculdade: 'Uniesp',
          horarioEntrada: '18:50',
          horarioSaida: '22:10',
          periodo: 'Noturno',
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
          faculdade: 'Fatec',
          horarioEntrada: '07:40',
          horarioSaida: '12:00',
          telefone: '(15) 99207-7134',
          endereco: 'R. Nove de Julho, 332',
          periodo: 'Matutino',
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
        faculdade: 'ETEC',
        periodo: 'Matutino',
        telefone: '(15) 99774-1820',
        endereco: 'Av. Massaichi Kakihara, 91',
      ),
      Usuario(
        id: 'a2',
        nome: 'Lucas Martins',
        email: 'lucas@email.com',
        perfil: PerfilUsuario.aluno,
        faculdade: 'Unip',
        periodo: 'Matutino',
        telefone: '(15) 99630-8871',
        endereco: 'R. Floriano Peixoto, 522',
      ),
      Usuario(
        id: 'a3',
        nome: 'Felipe Santos',
        email: 'felipe@email.com',
        perfil: PerfilUsuario.aluno,
        faculdade: 'Fatec',
        periodo: 'Matutino',
        telefone: '(15) 99207-7134',
        endereco: 'R. Nove de Julho, 332',
      ),
      Usuario(
        id: 'a4',
        nome: 'Henrique Almeida',
        email: 'henrique@email.com',
        perfil: PerfilUsuario.aluno,
        faculdade: 'Fatec',
        periodo: 'Noturno',
        telefone: '(15) 99111-2233',
        endereco: 'R. das Flores, 100',
      ),
      Usuario(
        id: 'a5',
        nome: 'Beatriz Moreira',
        email: 'beatriz@email.com',
        perfil: PerfilUsuario.aluno,
        faculdade: 'Uniesp',
        periodo: 'Noturno',
        telefone: '(15) 99444-5566',
        endereco: 'Av. Brasil, 450',
      ),
      Usuario(
        id: 'a6',
        nome: 'Gabriel Lima',
        email: 'gabriel@email.com',
        perfil: PerfilUsuario.aluno,
        faculdade: 'Fatec',
        periodo: 'Pendentes',
        pendente: true,
        telefone: '(15) 99777-8899',
        endereco: 'R. XV de Novembro, 88',
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
