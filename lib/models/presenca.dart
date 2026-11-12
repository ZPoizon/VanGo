import 'usuario.dart';

/// Estado combinado exibido na interface (derivado de ida + volta).
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

/// Resposta individual de um sentido (modelo recomendado na especificação).
enum RespostaSentido {
  vai,
  naoVai,
  semResposta;

  String get label {
    switch (this) {
      case RespostaSentido.vai:
        return 'Vai';
      case RespostaSentido.naoVai:
        return 'Não vai';
      case RespostaSentido.semResposta:
        return 'Sem resposta';
    }
  }

  bool get confirmado => this == RespostaSentido.vai;
  bool get respondido => this != RespostaSentido.semResposta;
}

class RespostaPresenca {
  const RespostaPresenca({
    required this.alunoId,
    this.ida = RespostaSentido.semResposta,
    this.volta = RespostaSentido.semResposta,
    this.respondidoEm,
    this.estouIndo = false,
    this.estouIndoEm,
    this.liberadoEm,
    this.avisadoEm,
  });

  final String alunoId;
  final RespostaSentido ida;
  final RespostaSentido volta;
  final DateTime? respondidoEm;
  final bool estouIndo;
  final DateTime? estouIndoEm;
  final DateTime? liberadoEm;
  final DateTime? avisadoEm;

  bool get respondido => ida.respondido || volta.respondido;
  bool get liberado => liberadoEm != null;

  StatusPresenca get statusCombinado {
    final vaiIda = ida == RespostaSentido.vai;
    final vaiVolta = volta == RespostaSentido.vai;
    if (vaiIda && vaiVolta) return StatusPresenca.idaEVolta;
    if (vaiIda) return StatusPresenca.soIda;
    if (vaiVolta) return StatusPresenca.soVolta;
    if (ida == RespostaSentido.naoVai && volta == RespostaSentido.naoVai) {
      return StatusPresenca.naoVai;
    }
    return StatusPresenca.semResposta;
  }

  RespostaPresenca copyWith({
    RespostaSentido? ida,
    RespostaSentido? volta,
    DateTime? respondidoEm,
    bool? estouIndo,
    DateTime? estouIndoEm,
    DateTime? liberadoEm,
    DateTime? avisadoEm,
    bool limparLiberacao = false,
    bool limparAviso = false,
  }) {
    return RespostaPresenca(
      alunoId: alunoId,
      ida: ida ?? this.ida,
      volta: volta ?? this.volta,
      respondidoEm: respondidoEm ?? this.respondidoEm,
      estouIndo: estouIndo ?? this.estouIndo,
      estouIndoEm: estouIndoEm ?? this.estouIndoEm,
      liberadoEm: limparLiberacao ? null : (liberadoEm ?? this.liberadoEm),
      avisadoEm: limparAviso ? null : (avisadoEm ?? this.avisadoEm),
    );
  }
}

/// Linha pronta para a interface: aluno + resposta do dia.
class PresencaAluno {
  const PresencaAluno({required this.aluno, required this.resposta});

  final Usuario aluno;
  final RespostaPresenca resposta;

  StatusPresenca get status => resposta.statusCombinado;
  String get nome => aluno.nome;
}
