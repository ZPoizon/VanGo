enum PerfilUsuario { aluno, motorista }

enum StatusPresenca {
  idaEVolta,
  soIda,
  soVolta,
  naoVai,
  semResposta;

  String get label {
    switch (this) {
      case StatusPresenca.idaEVolta:
        return 'Ida e volta';
      case StatusPresenca.soIda:
        return 'Só ida';
      case StatusPresenca.soVolta:
        return 'Só volta';
      case StatusPresenca.naoVai:
        return 'Não vai';
      case StatusPresenca.semResposta:
        return 'Sem resposta';
    }
  }
}

class Usuario {
  final String id;
  final String nome;
  final String email;
  final PerfilUsuario perfil;
  final String? faculdade;
  final String? horarioEntrada;
  final String? horarioSaida;
  final String? telefone;
  final String? endereco;
  final String? periodo; // Matutino, Noturno
  final bool pendente;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.faculdade,
    this.horarioEntrada,
    this.horarioSaida,
    this.telefone,
    this.endereco,
    this.periodo,
    this.pendente = false,
  });
}

class AlunoPresenca {
  final Usuario aluno;
  StatusPresenca status;
  String? horarioEstouIndo;
  String? horarioAvisado;

  AlunoPresenca({
    required this.aluno,
    required this.status,
    this.horarioEstouIndo,
    this.horarioAvisado,
  });
}

class ViagemHistorico {
  final String id;
  final String data;
  final String tipo; // IDA ou VOLTA
  final String horario;
  final int confirmados;
  final int total;

  ViagemHistorico({
    required this.id,
    required this.data,
    required this.tipo,
    required this.horario,
    required this.confirmados,
    required this.total,
  });
}
