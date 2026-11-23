import 'package:flutter/foundation.dart';

import '../models/chamada.dart';
import '../models/grupo.dart';
import '../models/notificacao_entrada.dart';
import '../models/notificacao_resposta.dart';
import '../models/padrao_semanal.dart';
import '../models/presenca.dart';
import '../models/usuario.dart';
import '../models/viagem.dart';
import 'resultado.dart';

/// Contrato único consumido pela interface.
///
/// A aplicação pode rodar em dois modos:
/// * [DemoStore] — dados em memória (quando o Firebase não está configurado);
/// * [FirebaseStore] — Firebase Auth + Cloud Firestore + Storage + FCM.
///
/// Os métodos de escrita são assíncronos para refletir operações de rede.
abstract class VanGoStore extends ChangeNotifier {
  /// `true` quando a aplicação está usando os dados de demonstração.
  bool get modoDemo;

  /// `true` quando a sessão inicial terminou de ser carregada.
  bool get pronto;

  /// Último erro de sincronização (útil para telas de diagnóstico).
  String? get erro;

  /// Inicializa listeners/sessão. Deve ser chamado uma única vez.
  Future<void> inicializar();

  // ------------------------------------------------------------------ sessão

  Usuario? get usuarioAtual;
  bool get autenticado;
  bool get ehMotorista;
  bool get ehAluno;
  Usuario? get motorista;

  Future<LoginResultado> entrar({required String email, required String senha});

  /// Acesso rápido apenas no modo demonstração.
  Future<void> entrarComo(PerfilUsuario perfil);

  Future<void> sair();

  Future<OperacaoResultado> enviarRecuperacaoSenha(String email);

  // ------------------------------------------------------------------ alunos

  List<Usuario> get alunosAtivos;
  List<Usuario> get alunosPendentes;

  List<Usuario> alunosDoTurno(Turno turno, {String busca = ''});

  Usuario? alunoPorId(String id);

  Future<OperacaoResultado> salvarAluno(Usuario aluno);
  Future<OperacaoResultado> desativarAluno(String id);
  Future<OperacaoResultado> aprovarAluno(String id);

  /// Recusa a solicitação de um aluno.
  ///
  /// [motivo] é exibido ao aluno quando disponível. No Firebase as regras atuais
  /// limitam a escrita do motorista a `status`, `ativo` e `atualizadoEm`; por
  /// isso o motivo só aparece quando já existe no documento do aluno.
  Future<OperacaoResultado> recusarAluno(String id, {String? motivo});

  // --------------------------------------------------------------- chamadas

  Chamada? get chamadaAmanha;
  DateTime get dataAmanha;
  List<PresencaAluno> get presencasChamada;
  RespostaPresenca respostaDe(String alunoId);
  bool get respostaBloqueada;

  /// Avisos de alterações de resposta já registradas, em ordem do mais recente
  /// para o mais antigo. Usado pelo motorista; alunos não exibem esta lista.
  List<NotificacaoResposta> get notificacoesResposta;

  /// Avisos persistentes de novas solicitações de entrada, do mais recente para
  /// o mais antigo. Já exclui solicitações aprovadas/recusadas e cobre todas
  /// as vans administradas pelo motorista, não apenas a van ativa.
  List<NotificacaoEntrada> get notificacoesEntrada;

  /// Contagem reativa de solicitações pendentes por van, usada para atualizar
  /// o dashboard em tempo real sem consultas globais.
  Map<String, int> get pendentesPorGrupo;

  Future<OperacaoResultado> abrirChamada();
  Future<OperacaoResultado> encerrarChamada();
  Future<OperacaoResultado> cancelarChamada({String? motivo});

  /// Registra ou altera a resposta de presença do aluno.
  ///
  /// [ida] e [volta] são opcionais para permitir alteração independente:
  /// o sentido omitido é preservado no documento.
  Future<OperacaoResultado> responderChamada({bool? ida, bool? volta});

  // ---------------------------------------------------------------- viagens

  Viagem? get viagemAtual;
  List<Viagem> get historico;
  Viagem? viagemPorId(String id);
  List<ConfirmacaoViagem> get confirmacoesViagemAtual;
  List<PresencaAluno> get presencasViagemAtual;

  Future<OperacaoResultado> iniciarViagem(SentidoViagem sentido);
  Future<OperacaoResultado> encerrarViagem();
  Future<OperacaoResultado> cancelarViagem({String? motivo});
  Future<OperacaoResultado> avisarAlunos(Iterable<String> alunoIds);
  Future<OperacaoResultado> registrarEstouIndo();
  Future<OperacaoResultado> liberarAluno();
  Future<OperacaoResultado> cancelarLiberacao();

  // ------------------------------------------------------------ padrão semanal

  Map<int, PadraoSemanalDia> get padraoSemanal;
  PadraoSemanalDia padraoDoDia(int diaSemana);
  Future<OperacaoResultado> salvarPadraoSemanal(
    Map<int, PadraoSemanalDia> novoPadrao,
  );

  // ------------------------------------------------------------------ cadastro

  /// Cria somente a conta de motorista e seu perfil, sem vincular uma van.
  ///
  /// A criação de vans acontece depois, no painel "Minhas vans".
  Future<OperacaoResultado> cadastrarMotorista({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  });

  /// Cria uma conta de aluno pendente, ainda sem vínculo com nenhuma van.
  ///
  /// O vínculo com o grupo é feito depois, pela entrada com código e aprovação
  /// do motorista (Fase B).
  Future<OperacaoResultado> cadastrarAluno({
    required String nome,
    required String email,
    required String telefone,
    required String instituicao,
    required Turno turno,
    required String endereco,
    required String senha,
    String? cep,
    String? turnoPersonalizado,
  });

  // ------------------------------------------------------------------ grupos

  /// Vans pertencentes ao motorista autenticado, incluindo o grupo legado.
  List<GrupoVan> get meusGrupos;

  /// Van atualmente selecionada para operação (chamadas, alunos, viagens).
  GrupoVan? get grupoSelecionado;

  /// Lista as vans do motorista e restaura a última seleção persistida.
  Future<List<GrupoVan>> carregarMeusGrupos();

  /// Quantidade de alunos aprovados de uma van, sem trocar a van ativa.
  Future<int> contarAlunosGrupo(String grupoId);

  /// Quantidade de solicitações pendentes de uma van, sem trocar a van ativa
  /// nem sobrescrever a lista compartilhada [solicitacoesPendentes].
  ///
  /// Retorna `null` quando a consulta não pôde ser concluída com segurança:
  /// o dashboard exibe "indisponível" em vez de inventar um número.
  /// A consulta é sempre filtrada pelo `grupoId` de uma van do motorista.
  Future<int?> contarSolicitacoesGrupo(String grupoId);

  /// Seleciona a van ativa; a escolha persiste entre sessões.
  Future<OperacaoResultado> selecionarGrupo(String grupoId);

  /// Cria uma van com código numérico único de 6 dígitos.
  Future<OperacaoResultado> criarGrupo({
    required String nome,
    String? cidadeOrigem,
    String? cidadeDestino,
    PeriodoVan? periodo,
    String? periodoPersonalizado,
    String? horarioSaida,
    String? observacoes,
  });

  /// Busca um grupo pelo código de entrada numérico.
  ///
  /// Retorna null se o código não existir ou for inválido.
  Future<GrupoVan?> buscarGrupoPorCodigo(String codigo);

  /// Busca um grupo pelo seu ID de documento.
  ///
  /// Retorna null se o grupo não existir.
  Future<GrupoVan?> buscarGrupoPorId(String grupoId);

  /// Solicita entrada em um grupo pelo aluno autenticado.
  ///
  /// O aluno deve ter conta criada (status pendente) sem grupoId.
  /// A solicitação fica pendente até aprovação do motorista.
  Future<OperacaoResultado> solicitarEntradaGrupo({required String grupoId});

  /// Atualiza o código de entrada do grupo (apenas motorista dono do grupo).
  Future<OperacaoResultado> atualizarCodigoGrupo(
    String grupoId,
    String novoCodigo,
  );

  /// Gera e reserva um novo código para o grupo, invalidando o anterior.
  Future<OperacaoResultado> gerarNovoCodigoGrupo(String grupoId);

  /// Solicitações pendentes da van selecionada.
  List<Usuario> get solicitacoesPendentes;

  /// Lista atualizada de solicitações da van selecionada.
  Future<List<Usuario>> carregarSolicitacoes(String grupoId);

  // ------------------------------------------------------------------ convite

  Turno get conviteTurno;
  String? get conviteToken;
  String? get linkConvite;

  Future<String?> gerarConvite(Turno turno);
  Future<Turno?> carregarConvite(String token);

  Future<OperacaoResultado> enviarSolicitacao({
    required String nome,
    required String email,
    required String telefone,
    required String instituicao,
    required String endereco,
    required String senha,
    required Turno turno,
    String? cep,
    String? turnoPersonalizado,
    String? conviteToken,
  });

  // ------------------------------------------------------------------ perfil

  /// Atualiza somente os campos efetivamente informados. Campos omitidos
  /// permanecem intactos no Firestore.
  Future<OperacaoResultado> atualizarPerfil({
    required String nome,
    required String telefone,
    String? instituicao,
    String? endereco,
    String? cep,
    String? referencia,
    Turno? turno,
    String? turnoPersonalizado,
    String? fotoUrl,
  });

  Future<OperacaoResultado> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  });

  Future<OperacaoResultado> atualizarFotoPerfil({
    required Uint8List bytes,
    required String extensao,
  });

  /// Remove a foto de perfil e o arquivo correspondente no Storage.
  Future<OperacaoResultado> removerFotoPerfil();

  // ------------------------------------------------------------------ extras

  List<PresencaAluno> confirmadosNoSentido(SentidoViagem sentido);
  int get totalRespostas;
}
