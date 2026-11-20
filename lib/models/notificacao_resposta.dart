import 'presenca.dart';
import 'viagem.dart';

/// Aviso em tempo real exibido ao motorista quando um aluno altera uma
/// resposta de presença já registrada na chamada.
///
/// O aviso é derivado no cliente do motorista a partir do listener de
/// `respostas`: não é um novo registro de presença nem uma segunda fonte da
/// verdade. A resposta continua em `respostas/{chamadaId}_{alunoId}`.
class NotificacaoResposta {
  const NotificacaoResposta({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    required this.sentido,
    required this.anterior,
    required this.atual,
    required this.criadoEm,
  });

  final String id;
  final String alunoId;
  final String alunoNome;
  final SentidoViagem sentido;
  final RespostaSentido anterior;
  final RespostaSentido atual;
  final DateTime criadoEm;

  String get titulo =>
      sentido == SentidoViagem.ida ? 'Ida alterada' : 'Volta alterada';

  /// Ex.: `Volta: Não vai → Vai`.
  String get mudanca =>
      '${sentido == SentidoViagem.ida ? 'Ida' : 'Volta'}: '
      '${anterior.label} → ${atual.label}';
}
