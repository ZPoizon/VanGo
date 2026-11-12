import 'package:flutter/foundation.dart';

import '../models/chamada.dart';
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
  Future<OperacaoResultado> recusarAluno(String id);

  // --------------------------------------------------------------- chamadas

  Chamada? get chamadaAmanha;
  DateTime get dataAmanha;
  List<PresencaAluno> get presencasChamada;
  RespostaPresenca respostaDe(String alunoId);
  bool get respostaBloqueada;

  Future<OperacaoResultado> abrirChamada();
  Future<OperacaoResultado> encerrarChamada();
  Future<OperacaoResultado> responderChamada({
    required bool ida,
    required bool volta,
  });

  // ---------------------------------------------------------------- viagens

  Viagem? get viagemAtual;
  List<Viagem> get historico;
  Viagem? viagemPorId(String id);
  List<ConfirmacaoViagem> get confirmacoesViagemAtual;
  List<PresencaAluno> get presencasViagemAtual;

  Future<OperacaoResultado> iniciarViagem(SentidoViagem sentido);
  Future<OperacaoResultado> encerrarViagem();
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
    String? conviteToken,
  });

  // ------------------------------------------------------------------ perfil

  Future<OperacaoResultado> atualizarPerfil({
    required String nome,
    required String telefone,
    String? instituicao,
    String? endereco,
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

  // ------------------------------------------------------------------ extras

  List<PresencaAluno> confirmadosNoSentido(SentidoViagem sentido);
  int get totalRespostas;
}
