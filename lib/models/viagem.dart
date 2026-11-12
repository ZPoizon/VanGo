import 'presenca.dart';

enum SentidoViagem {
  ida,
  volta;

  String get label => this == SentidoViagem.ida ? 'IDA' : 'VOLTA';
}

enum StatusViagem {
  agendada,
  emAndamento,
  encerrada;

  String get label {
    switch (this) {
      case StatusViagem.agendada:
        return 'Agendada';
      case StatusViagem.emAndamento:
        return 'Em andamento';
      case StatusViagem.encerrada:
        return 'Encerrada';
    }
  }
}

class ConfirmacaoViagem {
  const ConfirmacaoViagem({
    required this.alunoId,
    required this.status,
    this.avisadoEm,
    this.estouIndo = false,
    this.estouIndoEm,
    this.liberadoEm,
  });

  final String alunoId;
  final RespostaSentido status;
  final DateTime? avisadoEm;
  final bool estouIndo;
  final DateTime? estouIndoEm;
  final DateTime? liberadoEm;

  ConfirmacaoViagem copyWith({
    RespostaSentido? status,
    DateTime? avisadoEm,
    bool? estouIndo,
    DateTime? estouIndoEm,
    DateTime? liberadoEm,
  }) {
    return ConfirmacaoViagem(
      alunoId: alunoId,
      status: status ?? this.status,
      avisadoEm: avisadoEm ?? this.avisadoEm,
      estouIndo: estouIndo ?? this.estouIndo,
      estouIndoEm: estouIndoEm ?? this.estouIndoEm,
      liberadoEm: liberadoEm ?? this.liberadoEm,
    );
  }
}

class Viagem {
  const Viagem({
    required this.id,
    required this.chamadaId,
    required this.grupoId,
    required this.dataViagem,
    required this.sentido,
    required this.status,
    this.iniciadaEm,
    this.encerradaEm,
    this.confirmacoes = const <ConfirmacaoViagem>[],
  });

  final String id;
  final String chamadaId;
  final String grupoId;
  final DateTime dataViagem;
  final SentidoViagem sentido;
  final StatusViagem status;
  final DateTime? iniciadaEm;
  final DateTime? encerradaEm;
  final List<ConfirmacaoViagem> confirmacoes;

  int get totalConfirmados => confirmacoes.length;
  int get totalEmbarcados =>
      confirmacoes.where((c) => c.status == RespostaSentido.vai).length;
  int get totalEstouIndo => confirmacoes.where((c) => c.estouIndo).length;

  Viagem copyWith({
    StatusViagem? status,
    DateTime? iniciadaEm,
    DateTime? encerradaEm,
    List<ConfirmacaoViagem>? confirmacoes,
  }) {
    return Viagem(
      id: id,
      chamadaId: chamadaId,
      grupoId: grupoId,
      dataViagem: dataViagem,
      sentido: sentido,
      status: status ?? this.status,
      iniciadaEm: iniciadaEm ?? this.iniciadaEm,
      encerradaEm: encerradaEm ?? this.encerradaEm,
      confirmacoes: confirmacoes ?? this.confirmacoes,
    );
  }
}
