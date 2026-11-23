/// Aviso persistido para o motorista quando um aluno solicita entrada em uma
/// van. O documento em `notificacoes` é a fonte do evento; o status atual da
/// solicitação continua em `solicitacoes/{alunoId}` e decide se o aviso ainda
/// aparece como pendente.
class NotificacaoEntrada {
  const NotificacaoEntrada({
    required this.id,
    required this.grupoId,
    required this.grupoNome,
    required this.solicitacaoId,
    required this.alunoNome,
    required this.criadoEm,
  });

  final String id;
  final String grupoId;
  final String grupoNome;
  final String solicitacaoId;
  final String alunoNome;
  final DateTime criadoEm;

  /// Ex.: `Pedro solicitou entrada na van Manhã Centro.`
  String get mensagem =>
      '$alunoNome solicitou entrada na van $grupoNome.';
}
