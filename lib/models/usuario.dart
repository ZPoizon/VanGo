enum PerfilUsuario {
  aluno,
  motorista;

  String get label => this == PerfilUsuario.aluno ? 'Aluno' : 'Motorista';
}

enum StatusConta {
  pendente,
  ativo,
  desativado,
  recusado;

  String get label {
    switch (this) {
      case StatusConta.pendente:
        return 'Pendente';
      case StatusConta.ativo:
        return 'Ativo';
      case StatusConta.desativado:
        return 'Desativado';
      case StatusConta.recusado:
        return 'Recusado';
    }
  }

  bool get podeAcessar => this == StatusConta.ativo;
}

enum Turno {
  matutino,
  noturno;

  String get label => this == Turno.matutino ? 'Matutino' : 'Noturno';
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    required this.status,
    this.ativoFirestore,
    this.conflitoAtivacao = false,
    this.telefone,
    this.fotoUrl,
    this.instituicao,
    this.turno,
    this.enderecoEmbarque,
    this.criadoEm,
  });

  final String id;
  final String nome;
  final String email;
  final PerfilUsuario perfil;
  final StatusConta status;

  /// Valor do campo `ativo` lido diretamente do Firestore.
  ///
  /// Quando o documento é antigo e não possui esse campo, permanece `null` e
  /// [ativo] continua sendo derivado de [status] para manter compatibilidade.
  final bool? ativoFirestore;

  /// `true` quando `ativo` e `status` existem mas se contradizem.
  ///
  /// Nesse caso o acesso é bloqueado por segurança, independentemente do valor
  /// de [ativo].
  final bool conflitoAtivacao;
  final String? telefone;
  final String? fotoUrl;
  final String? instituicao;
  final Turno? turno;
  final String? enderecoEmbarque;
  final DateTime? criadoEm;

  /// Campo oficial de ativação no Firestore, com fallback para documentos
  /// antigos que só possuem `status`.
  bool get ativo => ativoFirestore ?? (status == StatusConta.ativo);

  /// `true` somente quando não há conflito entre `ativo` e `status`.
  bool get podeAcessar => ativo && !conflitoAtivacao;

  bool get pendente => status == StatusConta.pendente;

  String? get faculdade => instituicao;
  String? get periodo => turno?.label;
  String? get endereco => enderecoEmbarque;

  String get primeiroNome {
    final partes = nome.trim().split(RegExp(r'\s+'));
    return partes.isEmpty ? nome : partes.first;
  }

  Usuario copyWith({
    String? nome,
    String? email,
    PerfilUsuario? perfil,
    StatusConta? status,
    bool? ativoFirestore,
    bool? conflitoAtivacao,
    String? telefone,
    String? fotoUrl,
    String? instituicao,
    Turno? turno,
    String? enderecoEmbarque,
    DateTime? criadoEm,
  }) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      perfil: perfil ?? this.perfil,
      status: status ?? this.status,
      ativoFirestore: ativoFirestore ?? this.ativoFirestore,
      conflitoAtivacao: conflitoAtivacao ?? this.conflitoAtivacao,
      telefone: telefone ?? this.telefone,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      instituicao: instituicao ?? this.instituicao,
      turno: turno ?? this.turno,
      enderecoEmbarque: enderecoEmbarque ?? this.enderecoEmbarque,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
