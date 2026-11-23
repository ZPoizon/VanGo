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
  vespertino,
  noturno,
  outro;

  String get label {
    switch (this) {
      case Turno.matutino:
        return 'Matutino';
      case Turno.vespertino:
        return 'Vespertino';
      case Turno.noturno:
        return 'Noturno';
      case Turno.outro:
        return 'Outro';
    }
  }
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
    this.turnoPersonalizado,
    this.enderecoEmbarque,
    this.cep,
    this.referenciaEndereco,
    this.grupoId,
    this.motivoRecusa,
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

  /// Descrição livre quando [turno] é [Turno.outro]. Documentos antigos não
  /// possuem este campo e continuam válidos.
  final String? turnoPersonalizado;
  final String? enderecoEmbarque;

  /// CEP do ponto de embarque, no formato `00000-000`.
  /// Ausente em contas criadas antes desta versão.
  final String? cep;

  /// Complemento do ponto de embarque (referência, portão, ponto de encontro).
  final String? referenciaEndereco;
  final String? grupoId;

  /// Motivo informado pelo motorista quando a solicitação é recusada.
  ///
  /// O campo é opcional e pode existir em documentos gravados por versões
  /// anteriores ou por processos externos; as regras atuais não permitem que o
  /// app escreva este campo no Firestore.
  final String? motivoRecusa;
  final DateTime? criadoEm;

  /// Campo oficial de ativação no Firestore, com fallback para documentos
  /// antigos que só possuem `status`.
  bool get ativo => ativoFirestore ?? (status == StatusConta.ativo);

  /// `true` somente quando não há conflito entre `ativo` e `status`.
  bool get podeAcessar => ativo && !conflitoAtivacao;

  bool get pendente => status == StatusConta.pendente;

  String? get faculdade => instituicao;

  /// Texto exibido para o turno. Para [Turno.outro], usa a descrição informada
  /// pelo aluno; documentos antigos com turnos conhecidos seguem inalterados.
  String? get periodo {
    if (turno != Turno.outro) return turno?.label;
    final personalizado = turnoPersonalizado?.trim();
    return personalizado != null && personalizado.isNotEmpty
        ? personalizado
        : Turno.outro.label;
  }

  String? get endereco => enderecoEmbarque;
  String? get referencia => referenciaEndereco;

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
    bool limparFotoUrl = false,
    String? instituicao,
    Turno? turno,
    String? turnoPersonalizado,
    bool limparTurnoPersonalizado = false,
    String? enderecoEmbarque,
    String? cep,
    bool limparCep = false,
    String? referenciaEndereco,
    String? grupoId,
    String? motivoRecusa,
    bool limparMotivoRecusa = false,
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
      fotoUrl: limparFotoUrl ? null : (fotoUrl ?? this.fotoUrl),
      instituicao: instituicao ?? this.instituicao,
      turno: turno ?? this.turno,
      turnoPersonalizado: limparTurnoPersonalizado
          ? null
          : (turnoPersonalizado ?? this.turnoPersonalizado),
      enderecoEmbarque: enderecoEmbarque ?? this.enderecoEmbarque,
      cep: limparCep ? null : (cep ?? this.cep),
      referenciaEndereco: referenciaEndereco ?? this.referenciaEndereco,
      grupoId: grupoId ?? this.grupoId,
      motivoRecusa: limparMotivoRecusa
          ? null
          : (motivoRecusa ?? this.motivoRecusa),
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
