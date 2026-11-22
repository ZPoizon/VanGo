enum StatusChamada {
  aberta,
  encerrada,
  cancelada;

  String get label {
    switch (this) {
      case StatusChamada.aberta:
        return 'Aberta';
      case StatusChamada.encerrada:
        return 'Encerrada';
      case StatusChamada.cancelada:
        return 'Cancelada';
    }
  }
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
    this.canceladaEm,
    this.motivoCancelamento,
  });

  final String id;
  final String grupoId;
  final String motoristaId;
  final DateTime dataServico;
  final StatusChamada status;
  final DateTime criadaEm;
  final DateTime? abertaEm;
  final DateTime? encerradaEm;
  final DateTime? canceladaEm;
  final String? motivoCancelamento;

  bool get aberta => status == StatusChamada.aberta;
  bool get cancelada => status == StatusChamada.cancelada;

  Chamada copyWith({
    StatusChamada? status,
    DateTime? abertaEm,
    DateTime? encerradaEm,
    DateTime? canceladaEm,
    String? motivoCancelamento,
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
      canceladaEm: canceladaEm ?? this.canceladaEm,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
    );
  }
}
