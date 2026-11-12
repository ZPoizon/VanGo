enum StatusChamada {
  aberta,
  encerrada;

  String get label => this == StatusChamada.aberta ? 'Aberta' : 'Encerrada';
}

class Chamada {
  const Chamada({
    required this.id,
    required this.grupoId,
    required this.motoristaId,
    required this.dataServico,
    required this.status,
    required this.criadaEm,
    this.abertaEm,
    this.encerradaEm,
  });

  final String id;
  final String grupoId;
  final String motoristaId;
  final DateTime dataServico;
  final StatusChamada status;
  final DateTime criadaEm;
  final DateTime? abertaEm;
  final DateTime? encerradaEm;

  bool get aberta => status == StatusChamada.aberta;

  Chamada copyWith({
    StatusChamada? status,
    DateTime? abertaEm,
    DateTime? encerradaEm,
  }) {
    return Chamada(
      id: id,
      grupoId: grupoId,
      motoristaId: motoristaId,
      dataServico: dataServico,
      status: status ?? this.status,
      criadaEm: criadaEm,
      abertaEm: abertaEm ?? this.abertaEm,
      encerradaEm: encerradaEm ?? this.encerradaEm,
    );
  }
}
