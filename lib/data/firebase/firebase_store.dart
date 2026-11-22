import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/notifications/push_notifications.dart';
import '../../core/resultado.dart';
import '../../core/selecao_grupo_store.dart';
import '../../core/store.dart';
import '../../models/chamada.dart';
import '../../models/grupo.dart';
import '../../models/notificacao_resposta.dart';
import '../../models/padrao_semanal.dart';
import '../../models/presenca.dart';
import '../../models/usuario.dart';
import '../../models/viagem.dart';
import 'firestore_mappers.dart';

/// Resultado interno da aplicação de uma sessão autenticada.
enum _SessaoResultado {
  aplicada,
  semPerfil,
  pendente,
  desativado,
  dadosInconsistentes,
  permissoesNegadas,
  emailNaoVerificado,
  falha,
}

/// Store real: Firebase Auth + Cloud Firestore + Storage + FCM.
///
/// A interface é reativa: listeners do Firestore mantêm o estado local
/// sincronizado e chamam [notifyListeners] para reconstruir a UI.
class FirebaseStore extends VanGoStore {
  /// Verificação de e-mail DESLIGADA na Fase 1 (contas de teste sem caixa
  /// de entrada acessível). Para habilitar, basta trocar para `true`: o fluxo
  /// de login passa a exigir `emailVerified` antes de consultar o Firestore.
  static const bool exigirEmailVerificado = false;

  FirebaseStore({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _respostasSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificacoesRespostaSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _padraoSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _perfilSub;

  List<Usuario> _usuarios = <Usuario>[];
  final Map<String, RespostaPresenca> _respostas = <String, RespostaPresenca>{};
  final List<NotificacaoResposta> _notificacoesResposta =
      <NotificacaoResposta>[];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _notificacoesRespostaDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<Viagem> _historico = <Viagem>[];
  Chamada? _chamada;
  Viagem? _viagemAtual;
  Map<int, PadraoSemanalDia> _padrao = <int, PadraoSemanalDia>{};
  Usuario? _usuarioAtual;

  /// Grupo do perfil atual. Vazio para contas recém-criadas, que ainda não
  /// possuem van e não podem ler dados de grupo.
  String _grupoId = '';
  List<GrupoVan> _grupos = <GrupoVan>[];
  String? _grupoSelecionadoId;
  final List<Usuario> _solicitacoes = <Usuario>[];
  String? _uid;
  String? _conviteToken;
  Turno _conviteTurno = Turno.matutino;
  String? _erro;
  bool _pronto = false;
  bool _ignorarAuth = false;
  bool _descartado = false;
  Future<_SessaoResultado>? _sessaoEmAndamento;

  @override
  bool get modoDemo => false;

  @override
  bool get pronto => _pronto;

  @override
  String? get erro => _erro;

  String get _grupoAtual => _grupoId;

  bool get _temGrupo => _grupoId.trim().isNotEmpty;

  @override
  List<GrupoVan> get meusGrupos {
    final motorista = _usuarioAtual;
    if (motorista == null || motorista.perfil != PerfilUsuario.motorista) {
      return const <GrupoVan>[];
    }
    return List.unmodifiable(
      _grupos.where((grupo) => grupo.motoristaId == motorista.id),
    );
  }

  @override
  GrupoVan? get grupoSelecionado {
    final id = _grupoSelecionadoId;
    final motorista = _usuarioAtual;
    if (id == null ||
        motorista == null ||
        motorista.perfil != PerfilUsuario.motorista) {
      return null;
    }
    for (final grupo in meusGrupos) {
      if (grupo.id == id) return grupo;
    }
    return null;
  }

  /// Grupo usado nas assinaturas. Para motoristas, respeita a seleção explícita;
  /// para alunos, continua sendo o vínculo do próprio perfil.
  String get _grupoOperacional {
    if (_usuarioAtual?.perfil == PerfilUsuario.motorista) {
      final selecionado = grupoSelecionado;
      if (selecionado != null) return selecionado.id;
    }
    return _grupoId;
  }

  @override
  List<Usuario> get solicitacoesPendentes => List.unmodifiable(_solicitacoes);

  @override
  Future<void> inicializar() async {
    if (_pronto) return;

    try {
      await PushNotifications.instance.inicializar();
    } catch (error) {
      debugPrint('[FCM] falha ao inicializar notificações: $error');
    }

    try {
      _authSub = _auth.authStateChanges().listen((user) {
        if (_ignorarAuth) return;
        unawaited(_aplicarSessao(user));
      });

      await _aplicarSessao(_auth.currentUser);
    } catch (error) {
      debugPrint(
        '[Sessão] falha ao inicializar: ${_descreverErroSeguro(error)}',
      );
      _erro = _descreverErroCarregamento(error);
      _notificar();
    } finally {
      _pronto = true;
      _notificar();
    }
  }

  // ------------------------------------------------------------------ sessão

  @override
  Usuario? get usuarioAtual => _usuarioAtual;

  @override
  bool get autenticado => _usuarioAtual != null;

  @override
  bool get ehMotorista => _usuarioAtual?.perfil == PerfilUsuario.motorista;

  @override
  bool get ehAluno => _usuarioAtual?.perfil == PerfilUsuario.aluno;

  @override
  Usuario? get motorista {
    for (final usuario in _usuarios) {
      if (usuario.perfil == PerfilUsuario.motorista) return usuario;
    }
    return _usuarioAtual?.perfil == PerfilUsuario.motorista
        ? _usuarioAtual
        : null;
  }

  @override
  Future<LoginResultado> entrar({
    required String email,
    required String senha,
  }) async {
    // Resultado de uma tentativa anterior não pode vazar para a nova: sem
    // isso, `invalid-credential` aparecia na UI como erro de internet.
    _erro = null;
    try {
      // As credenciais são enviadas exatamente como digitadas. O validador do
      // formulário já garante o formato do e-mail; a senha nunca é alterada.
      final credencial = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final user = credencial.user;
      if (user == null) return LoginResultado.credenciaisInvalidas;

      // Nenhuma leitura protegida do Firestore antes de confirmar que o
      // próprio Firebase Auth concluiu a autenticação.
      final autenticado = _auth.currentUser;
      if (autenticado == null || autenticado.uid != user.uid) {
        return LoginResultado.credenciaisInvalidas;
      }

      final resultado = await _aplicarSessao(user);
      return _comoLoginResultado(resultado);
    } on FirebaseAuthException catch (error) {
      debugPrint('[Auth] ${error.code}: ${error.message}');
      _erro = null;
      return _mapearErroAuth(error);
    } on FirebaseException catch (error) {
      debugPrint('[Firestore] ${error.code}: ${error.message}');
      _erro = null;
      if (_ehPermissionDenied(error)) {
        return LoginResultado.permissoesNegadas;
      }
      switch (error.code) {
        case 'unauthenticated':
          unawaited(_auth.signOut());
          return LoginResultado.sessaoExpirada;
        case 'not-found':
          return LoginResultado.semPerfil;
        case 'failed-precondition':
          return LoginResultado.configuracaoInvalida;
        case 'invalid-argument':
          return LoginResultado.dadosInvalidos;
        case 'unavailable':
        case 'network-request-failed':
          return LoginResultado.offline;
        default:
          return LoginResultado.erroInterno;
      }
    } catch (error) {
      debugPrint('[Auth] falha no login: $error');
      _erro = null;
      return LoginResultado.erroInterno;
    }
  }

  @override
  Future<void> entrarComo(PerfilUsuario perfil) async {
    // O acesso rápido é exclusivo do modo demonstração.
  }

  @override
  Future<void> sair() async {
    await PushNotifications.instance.removerDispositivo();
    await _auth.signOut();
    await _limparSessao();
  }

  @override
  Future<OperacaoResultado> enviarRecuperacaoSenha(String email) async {
    final normalizado = email.trim().toLowerCase();
    if (normalizado.isEmpty || !normalizado.contains('@')) {
      return const OperacaoResultado.erro('Informe um e-mail válido.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: normalizado);
      return const OperacaoResultado.ok(
        'Se o e-mail existir, enviaremos um link para redefinir a senha.',
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('[Auth] recuperação de senha: ${error.code}');
      if (error.code == 'network-request-failed' ||
          error.code == 'unavailable') {
        return const OperacaoResultado.erro(
          'Sem conexão. Verifique sua internet e tente novamente.',
        );
      }
      if (error.code == 'too-many-requests') {
        return const OperacaoResultado.erro(
          'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.',
        );
      }
      if (error.code == 'invalid-email') {
        return const OperacaoResultado.erro('Informe um e-mail válido.');
      }
      return const OperacaoResultado.ok(
        'Se o e-mail existir, enviaremos um link para redefinir a senha.',
      );
    }
  }

  /// Serializa a aplicação da sessão: o listener de auth e o login podem
  /// disparar ao mesmo tempo e não podem competir pelas mesmas assinaturas.
  Future<_SessaoResultado> _aplicarSessao(User? user) {
    final anterior = _sessaoEmAndamento;
    if (anterior != null) {
      return anterior.then(
        (_) => _aplicarSessao(user),
        onError: (_) => _aplicarSessao(user),
      );
    }

    final futuro = _aplicarSessaoInterno(user).whenComplete(() {
      _sessaoEmAndamento = null;
    });
    _sessaoEmAndamento = futuro;
    return futuro;
  }

  Future<_SessaoResultado> _aplicarSessaoInterno(User? user) async {
    if (user == null) {
      await _limparSessao();
      return _SessaoResultado.falha;
    }

    if (_uid == user.uid && _subs.isNotEmpty && _usuarioAtual != null) {
      return _SessaoResultado.aplicada;
    }

    // Guarda explícita antes de qualquer leitura protegida.
    final autenticado = _auth.currentUser;
    if (autenticado == null || autenticado.uid != user.uid) {
      await _limparSessao();
      return _SessaoResultado.falha;
    }

    if (exigirEmailVerificado) {
      await user.reload();
      if (!user.emailVerified) {
        _erro = 'Confirme seu e-mail antes de entrar.';
        await _limparSessao();
        await _auth.signOut();
        return _SessaoResultado.emailNaoVerificado;
      }
    }

    _uid = user.uid;

    try {
      // Consulta exata do perfil autenticado.
      debugPrint('[Firestore] lendo usuarios/${user.uid}');
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) {
        _erro = 'Perfil não encontrado. Use o convite do motorista.';
        await _limparSessao();
        await _auth.signOut();
        return _SessaoResultado.semPerfil;
      }

      // Perfil ausente ou desconhecido não pode cair no padrão "aluno".
      final perfilValido = enumDeOuNulo(
        PerfilUsuario.values,
        doc.data()?['perfil'],
      );
      if (perfilValido == null) {
        _erro = 'Perfil inválido ou ausente em usuarios/${user.uid}.';
        await _limparSessao();
        await _auth.signOut();
        return _SessaoResultado.dadosInconsistentes;
      }

      final perfil = usuarioFromDoc(doc);
      debugPrint(
        '[Firestore] usuarios/${user.uid}: perfil=${perfilValido.name}, '
        'ativo=${perfil.ativo}, conflito=${perfil.conflitoAtivacao}',
      );
      if (perfil.conflitoAtivacao) {
        _erro =
            'Os campos "ativo" e "status" do seu perfil são contraditórios. '
            'Procure o motorista do grupo para regularizar.';
        await _limparSessao();
        await _auth.signOut();
        return _SessaoResultado.dadosInconsistentes;
      }
      // Pendentes, recusados e contas sem grupo entram, mas com acesso
      // restrito ao próprio perfil e às informações públicas mínimas.
      // Somente desativados são desconectados.
      if (!perfil.podeAcessar &&
          perfil.status != StatusConta.pendente &&
          perfil.status != StatusConta.recusado) {
        _erro = 'Esta conta está desativada. Procure o motorista do grupo.';
        await _limparSessao();
        await _auth.signOut();
        return _SessaoResultado.desativado;
      }

      _usuarioAtual = perfil;
      _grupoId = _grupoIdDe(doc);
      if (perfil.perfil == PerfilUsuario.motorista) {
        await carregarMeusGrupos();
      }
      await _assinarDados();

      // Tanto pendente quanto recusado mantêm sessão para acompanhar a
      // solicitação, ver o motivo e tentar novamente sem fazer logout.
      if (perfil.status == StatusConta.pendente ||
          perfil.status == StatusConta.recusado) {
        _erro = null;
        _notificar();
        return _SessaoResultado.pendente;
      }

      if (_temGrupo) {
        try {
          await PushNotifications.instance.registrarDispositivo(
            uid: user.uid,
            grupoId: _grupoId,
          );
        } catch (error) {
          // Notificação é complementar: uma falha no FCM/token não pode impedir
          // o login nem a leitura dos dados do Firestore.
          debugPrint('[FCM] falha ao registrar dispositivo: $error');
        }
      }
      _erro = null;
      _notificar();
      return _SessaoResultado.aplicada;
    } on FirebaseException catch (error) {
      debugPrint(
        '[Firestore] falha ao carregar sessão: ${error.code}: ${error.message}',
      );
      await _limparSessao();
      if (_ehPermissionDenied(error)) {
        // Mensagem técnica fica no diagnóstico; a UI usa uma mensagem própria.
        _erro = '${error.code}: ${error.message}';
        _notificar();
        return _SessaoResultado.permissoesNegadas;
      }
      _erro = _descreverErroCarregamento(error);
      _notificar();
      return _SessaoResultado.falha;
    } catch (error) {
      debugPrint('[Firestore] falha ao carregar sessão: $error');
      await _limparSessao();
      _erro =
          'Não foi possível carregar os dados do servidor. Tente novamente.';
      _notificar();
      return _SessaoResultado.falha;
    }
  }

  LoginResultado _comoLoginResultado(_SessaoResultado resultado) {
    switch (resultado) {
      case _SessaoResultado.aplicada:
        return LoginResultado.sucesso;
      case _SessaoResultado.semPerfil:
        return LoginResultado.semPerfil;
      case _SessaoResultado.pendente:
        return LoginResultado.pendente;
      case _SessaoResultado.desativado:
        return LoginResultado.desativado;
      case _SessaoResultado.dadosInconsistentes:
        return LoginResultado.dadosInconsistentes;
      case _SessaoResultado.permissoesNegadas:
        return LoginResultado.permissoesNegadas;
      case _SessaoResultado.emailNaoVerificado:
        return LoginResultado.emailNaoVerificado;
      case _SessaoResultado.falha:
        return LoginResultado.offline;
    }
  }

  Future<void> _limparSessao() async {
    await _cancelarAssinaturas();
    _uid = null;
    _usuarioAtual = null;
    _usuarios = <Usuario>[];
    _respostas.clear();
    _notificacoesResposta.clear();
    _notificacoesRespostaDocs.clear();
    _chamada = null;
    _viagemAtual = null;
    _historico = <Viagem>[];
    _padrao = <int, PadraoSemanalDia>{};
    _conviteToken = null;
    _grupoId = '';
    _grupos = <GrupoVan>[];
    _grupoSelecionadoId = null;
    _solicitacoes.clear();
    unawaited(SelecaoGrupoStore.salvar(null));
    _notificar();
  }

  LoginResultado _mapearErroAuth(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return LoginResultado.offline;
      case 'user-disabled':
        return LoginResultado.desativado;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return LoginResultado.credenciaisInvalidas;
      case 'too-many-requests':
        return LoginResultado.dadosInvalidos;
      case 'unauthenticated':
        return LoginResultado.sessaoExpirada;
      default:
        return LoginResultado.erroInterno;
    }
  }

  /// Reconhece o erro de regras do Firestore tanto pelo código do plugin
  /// (`cloud_firestore/permission-denied`) quanto pela mensagem do servidor.
  bool _ehPermissionDenied(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return true;
    }
    final texto = error.toString().toLowerCase();
    return texto.contains('permission-denied') ||
        texto.contains('insufficient permissions');
  }

  /// Nunca aplica o grupo padrão a quem não tem vínculo real com uma van.
  String _grupoIdDe(DocumentSnapshot<Map<String, dynamic>> doc) =>
      (doc.data()?['grupoId'] as String?)?.trim() ?? '';

  // --------------------------------------------------------------- listeners

  Future<void> _assinarDados() async {
    await _cancelarAssinaturas();
    // Guarda explícita: listener nenhum é criado sem sessão confirmada.
    final uidAutenticado = _auth.currentUser?.uid;
    if (_uid == null || uidAutenticado == null || uidAutenticado != _uid) {
      return;
    }
    final grupo = _grupoOperacional;

    // Sem vínculo real com uma van, ou com solicitação pendente/recusada,
    // apenas o próprio perfil é observado. Nenhuma listagem de usuários,
    // chamadas ou viagens é assinada nesses casos.
    final status = _usuarioAtual?.status;
    if (grupo.isEmpty ||
        status == StatusConta.pendente ||
        status == StatusConta.recusado) {
      _assinarPerfil(uidAutenticado);
      return;
    }

    if (_usuarioAtual?.perfil == PerfilUsuario.motorista) {
      // O filtro por grupo é obrigatório para que a consulta seja compatível
      // com as regras: o motorista nunca lista usuários de outras vans.
      _subs.add(
        _db
            .collection('usuarios')
            .where('grupoId', isEqualTo: grupo)
            .snapshots()
            .listen(
              _aoAtualizarUsuarios,
              onError: (Object e) => _aoFalharStream(e, 'usuarios:list'),
            ),
      );
      _assinarNotificacoesResposta(grupo);
    } else {
      _assinarPerfil(uidAutenticado);
    }

    _subs.add(
      _db
          .collection('chamadas')
          .where('grupoId', isEqualTo: grupo)
          .snapshots()
          .listen(
            _aoAtualizarChamada,
            onError: (Object e) => _aoFalharStream(e, 'chamadas:list'),
          ),
    );

    _subs.add(
      _db
          .collection('viagens')
          .where('grupoId', isEqualTo: grupo)
          .orderBy('dataViagem', descending: true)
          .limit(30)
          .snapshots()
          .listen(
            _aoAtualizarViagens,
            onError: (Object e) => _aoFalharStream(e, 'viagens:list'),
          ),
    );

    if (_usuarioAtual?.perfil == PerfilUsuario.aluno) {
      _assinarPadrao(_usuarioAtual!.id);
    }
  }

  /// Observa somente o documento do próprio usuário. Usado por pendentes e
  /// por contas sem van, que não podem ler dados do grupo.
  void _assinarPerfil(String uidAutenticado) {
    _perfilSub = _db
        .collection('usuarios')
        .doc(uidAutenticado)
        .snapshots()
        .listen(
          _aoAtualizarPerfil,
          onError: (Object e) => _aoFalharStream(e, 'usuarios:get(uid)'),
        );
  }

  void _aoAtualizarPerfil(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) {
      unawaited(_auth.signOut());
      return;
    }

    final atualizado = usuarioFromDoc(doc);
    final grupo = _grupoIdDe(doc);
    final grupoAntes = _grupoId;
    final statusAntes = _usuarioAtual?.status;
    final eraRestrito =
        statusAntes == StatusConta.pendente ||
        statusAntes == StatusConta.recusado;
    _grupoId = grupo;

    // Pendente/recusado jamais são desconectados pelo listener: precisam
    // acompanhar a solicitação, ver eventual motivo e tentar novamente.
    if (atualizado.status == StatusConta.pendente ||
        atualizado.status == StatusConta.recusado) {
      _usuarioAtual = atualizado;
      _notificar();
      return;
    }

    if (!atualizado.podeAcessar) {
      unawaited(_auth.signOut());
      return;
    }

    _usuarioAtual = atualizado;
    _notificar();

    // Aprovação ou criação da van passa a liberar as assinaturas do grupo.
    if (grupo.isNotEmpty && (eraRestrito || grupoAntes.isEmpty)) {
      if (atualizado.perfil == PerfilUsuario.motorista) {
        unawaited(carregarMeusGrupos());
      }
      unawaited(_assinarDados());
    }
  }

  void _aoAtualizarUsuarios(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _usuarios = snapshot.docs.map(usuarioFromDoc).toList();
    final atual = _usuarioAtual;
    if (atual != null) {
      for (final usuario in _usuarios) {
        if (usuario.id == atual.id) {
          _usuarioAtual = usuario;
          if (!usuario.podeAcessar) unawaited(_auth.signOut());
          break;
        }
      }
    }
    if (_notificacoesRespostaDocs.isNotEmpty) {
      _reconstruirNotificacoesResposta();
    }
    _notificar();
  }

  void _aoAtualizarChamada(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final anterior = _chamada?.id;
    final chamadas = snapshot.docs.map(chamadaFromDoc).toList()
      ..sort((a, b) => b.dataServico.compareTo(a.dataServico));
    _chamada = chamadas.isEmpty ? null : chamadas.first;
    if (_chamada?.id != anterior) _assinarRespostas();
    _notificar();
  }

  void _aoAtualizarViagens(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final viagens = snapshot.docs.map(viagemFromDoc).toList();
    Viagem? atual;
    for (final viagem in viagens) {
      if (viagem.status == StatusViagem.emAndamento) {
        atual = viagem;
        break;
      }
    }
    _viagemAtual = atual;
    _historico = viagens
        .where((viagem) => viagem.status == StatusViagem.encerrada)
        .toList();
    _notificar();
  }

  void _assinarRespostas() {
    unawaited(_respostasSub?.cancel());
    _respostas.clear();
    final chamada = _chamada;
    if (chamada == null) {
      _notificar();
      return;
    }

    Query<Map<String, dynamic>> consulta = _db
        .collection('respostas')
        // O filtro por grupo é exigido pela regra `mesmoGrupo(resource.data)`;
        // sem ele a listagem é recusada e as respostas não reaparecem ao abrir
        // o app novamente.
        .where('grupoId', isEqualTo: _grupoOperacional)
        .where('chamadaId', isEqualTo: chamada.id);

    // O aluno só tem permissão para ler a própria resposta. Filtrar também por
    // alunoId mantém a consulta compatível com as regras de segurança; o
    // motorista continua vendo todas as respostas da chamada.
    if (_usuarioAtual?.perfil == PerfilUsuario.aluno) {
      consulta = consulta.where('alunoId', isEqualTo: _uid);
    }

    _respostasSub = consulta.snapshots().listen((snapshot) {
      final atuais = <String, RespostaPresenca>{};
      for (final doc in snapshot.docs) {
        final resposta = respostaFromDoc(doc);
        atuais[resposta.alunoId] = resposta;
      }
      _respostas
        ..clear()
        ..addAll(atuais);
      _notificar();
    }, onError: (Object e) => _aoFalharStream(e, 'respostas:list'));
  }

  /// Avisos de alteração ficam persistidos em `notificacoes`. O listener cobre
  /// a van ativa e também repovoa a lista quando o aplicativo é reaberto.
  void _assinarNotificacoesResposta(String grupo) {
    unawaited(_notificacoesRespostaSub?.cancel());
    _notificacoesRespostaDocs.clear();
    _notificacoesResposta.clear();
    _notificacoesRespostaSub = _db
        .collection('notificacoes')
        .where('grupoId', isEqualTo: grupo)
        .snapshots()
        .listen((snapshot) {
          _notificacoesRespostaDocs
            ..clear()
            ..addAll(snapshot.docs);
          _reconstruirNotificacoesResposta();
        }, onError: (Object e) => _aoFalharStream(e, 'notificacoes:list'));
  }

  /// Projeta os documentos persistidos no modelo já usado pela UI. O nome vem
  /// sempre do perfil carregado do Firestore, nunca do documento de aviso.
  void _reconstruirNotificacoesResposta() {
    final projetados = <NotificacaoResposta>[];
    for (final doc in _notificacoesRespostaDocs) {
      final data = doc.data();
      if (data['tipo'] != 'resposta_alterada') continue;
      final dados = data['dados'];
      if (dados is! Map<String, dynamic>) continue;
      final alunoId = dados['alunoId'] as String?;
      final chamadaId = dados['chamadaId'] as String?;
      final sentido = enumDeOuNulo(SentidoViagem.values, dados['sentido']);
      final anterior = enumDeOuNulo(
        RespostaSentido.values,
        dados['respostaAnterior'],
      );
      final atual = enumDeOuNulo(
        RespostaSentido.values,
        dados['respostaAtual'],
      );
      final criadoEm = (data['criadoEm'] as Timestamp?)?.toDate();
      if (alunoId == null ||
          chamadaId == null ||
          sentido == null ||
          anterior == null ||
          atual == null ||
          criadoEm == null) {
        continue;
      }
      projetados.add(
        NotificacaoResposta(
          id: doc.id,
          alunoId: alunoId,
          alunoNome: alunoPorId(alunoId)?.nome ?? 'Aluno',
          sentido: sentido,
          anterior: anterior,
          atual: atual,
          criadoEm: criadoEm,
        ),
      );
    }
    projetados.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    _notificacoesResposta
      ..clear()
      ..addAll(projetados.take(20));
    _notificar();
  }

  void _assinarPadrao(String uid) {
    unawaited(_padraoSub?.cancel());
    _padraoSub = _db.collection('padroes').doc(uid).snapshots().listen((doc) {
      _padrao = padraoFromDoc(doc);
      _notificar();
    }, onError: (Object e) => _aoFalharStream(e, 'padroes:get(uid)'));
  }

  void _aoFalharStream(Object error, String origem) {
    debugPrint(
      '[Firestore] erro em listener ($origem): ${_descreverErroSeguro(error)}',
    );
    _erro = _descreverErroCarregamento(error);
    _notificar();
  }

  Future<void> _cancelarAssinaturas() async {
    for (final assinatura in _subs) {
      await assinatura.cancel();
    }
    _subs.clear();
    await _respostasSub?.cancel();
    _respostasSub = null;
    await _notificacoesRespostaSub?.cancel();
    _notificacoesRespostaSub = null;
    await _padraoSub?.cancel();
    _padraoSub = null;
    await _perfilSub?.cancel();
    _perfilSub = null;
  }

  /// Remove da memória tudo que pertence à van anterior. Os snapshots da nova
  /// van são assinados logo em seguida e preenchem apenas os dados dela.
  void _limparEstadoDaVan() {
    _usuarios = <Usuario>[];
    _chamada = null;
    _viagemAtual = null;
    _historico = <Viagem>[];
    _respostas.clear();
    _notificacoesResposta.clear();
    _notificacoesRespostaDocs.clear();
    _solicitacoes.clear();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  // ------------------------------------------------------------------ alunos

  @override
  List<Usuario> get alunosAtivos {
    final lista = _usuarios
        .where(
          (usuario) =>
              usuario.perfil == PerfilUsuario.aluno && usuario.podeAcessar,
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  List<Usuario> get alunosPendentes {
    final lista = _usuarios
        .where(
          (usuario) =>
              usuario.perfil == PerfilUsuario.aluno &&
              !usuario.podeAcessar &&
              usuario.status == StatusConta.pendente,
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  List<Usuario> alunosDoTurno(Turno turno, {String busca = ''}) {
    final termo = _normalizar(busca);
    final lista = _usuarios
        .where(
          (usuario) =>
              usuario.perfil == PerfilUsuario.aluno &&
              usuario.podeAcessar &&
              usuario.turno == turno &&
              (termo.isEmpty ||
                  _normalizar(usuario.nome).contains(termo) ||
                  _normalizar(usuario.instituicao ?? '').contains(termo)),
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  Usuario? alunoPorId(String id) {
    for (final usuario in _usuarios) {
      if (usuario.id == id) return usuario;
    }
    return null;
  }

  @override
  Future<OperacaoResultado> salvarAluno(Usuario aluno) async {
    try {
      await _db.collection('usuarios').doc(aluno.id).set(<String, dynamic>{
        'nome': aluno.nome.trim(),
        'telefone': aluno.telefone?.trim(),
        'instituicao': aluno.instituicao,
        'turno': aluno.turno?.name,
        'enderecoEmbarque': aluno.enderecoEmbarque?.trim(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return const OperacaoResultado.ok('Aluno salvo.');
    } catch (error) {
      return _erroOperacao('salvar o aluno', error);
    }
  }

  @override
  Future<OperacaoResultado> desativarAluno(String id) =>
      _alterarStatusAluno(id, StatusConta.desativado);

  @override
  Future<OperacaoResultado> aprovarAluno(String id) =>
      _alterarStatusAluno(id, StatusConta.ativo);

  @override
  Future<OperacaoResultado> recusarAluno(String id, {String? motivo}) =>
      _alterarStatusAluno(id, StatusConta.recusado, motivo: motivo);

  Future<OperacaoResultado> _alterarStatusAluno(
    String id,
    StatusConta status, {
    String? motivo,
  }) async {
    final grupo = _grupoOperacional;
    if (grupo.isEmpty) {
      return const OperacaoResultado.erro(
        'Selecione uma van antes de continuar.',
      );
    }
    final motivoLimpo = motivo?.trim();
    try {
      // Perfil do aluno e status da solicitação mudam juntos. Sem o lote, uma
      // recusa deixava a solicitação `pendente` e o aluno ficava preso.
      final lote = _db.batch();
      lote.set(_db.collection('usuarios').doc(id), <String, dynamic>{
        'status': status.name,
        // Mantém o campo oficial sincronizado para não gerar contradição.
        'ativo': status == StatusConta.ativo,
        if (status == StatusConta.recusado && motivoLimpo != null)
          'motivoRecusa': motivoLimpo,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      lote.update(_db.collection('solicitacoes').doc(id), <String, dynamic>{
        'status': status == StatusConta.ativo ? 'aprovado' : 'recusado',
      });
      await lote.commit();
      switch (status) {
        case StatusConta.ativo:
          return const OperacaoResultado.ok('Solicitação aprovada.');
        case StatusConta.recusado:
          return const OperacaoResultado.ok('Solicitação recusada.');
        case StatusConta.desativado:
          return const OperacaoResultado.ok(
            'Aluno desativado. O histórico foi preservado.',
          );
        case StatusConta.pendente:
          return const OperacaoResultado.ok('Status atualizado.');
      }
    } catch (error) {
      return _erroOperacao('atualizar o aluno', error);
    }
  }

  // --------------------------------------------------------------- chamadas

  @override
  Chamada? get chamadaAmanha => _chamada;

  @override
  DateTime get dataAmanha {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day + 1);
  }

  @override
  List<PresencaAluno> get presencasChamada {
    final lista = alunosAtivos
        .map(
          (aluno) => PresencaAluno(
            aluno: aluno,
            resposta:
                _respostas[aluno.id] ?? RespostaPresenca(alunoId: aluno.id),
          ),
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  RespostaPresenca respostaDe(String alunoId) =>
      _respostas[alunoId] ?? RespostaPresenca(alunoId: alunoId);

  String? get _motivoBloqueio {
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return 'Respostas bloqueadas: a viagem já começou.';
    }
    final chamada = _chamada;
    if (chamada == null) return 'Nenhuma chamada aberta.';
    if (!chamada.aberta)
      return 'Respostas bloqueadas: a chamada foi encerrada.';
    return null;
  }

  @override
  bool get respostaBloqueada {
    final chamada = _chamada;
    if (chamada == null || !chamada.aberta) return true;
    return _viagemAtual?.status == StatusViagem.emAndamento;
  }

  @override
  List<NotificacaoResposta> get notificacoesResposta =>
      List<NotificacaoResposta>.unmodifiable(_notificacoesResposta);

  @override
  Future<OperacaoResultado> abrirChamada() async {
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode abrir a chamada.',
      );
    }
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Encerre a viagem em andamento antes de abrir uma nova chamada.',
      );
    }
    if (_chamada?.aberta ?? false) {
      return const OperacaoResultado.erro('Já existe uma chamada aberta.');
    }

    try {
      final referencia = _db.collection('chamadas').doc();
      await referencia.set(
        chamadaToMap(
          grupoId: _grupoOperacional,
          motoristaId: _uid ?? '',
          dataServico: dataAmanha,
          status: StatusChamada.aberta,
          abertaEm: DateTime.now(),
        ),
      );

      await _criarNotificacao(
        titulo: 'Chamada aberta!',
        corpo: 'Confirme sua presença de amanhã na van.',
        alunoIds: alunosAtivos.map((aluno) => aluno.id).toList(),
        tipo: 'chamada_aberta',
        dados: <String, dynamic>{'chamadaId': referencia.id},
      );

      return const OperacaoResultado.ok('Chamada de amanhã aberta.');
    } catch (error) {
      return _erroOperacao('abrir a chamada', error);
    }
  }

  @override
  Future<OperacaoResultado> encerrarChamada() async {
    final chamada = _chamada;
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode encerrar a chamada.',
      );
    }
    if (chamada == null || !chamada.aberta) {
      return const OperacaoResultado.erro(
        'Nenhuma chamada aberta para encerrar.',
      );
    }

    try {
      await _db.collection('chamadas').doc(chamada.id).update(<String, dynamic>{
        'status': StatusChamada.encerrada.name,
        'encerradaEm': FieldValue.serverTimestamp(),
      });
      return const OperacaoResultado.ok(
        'Chamada encerrada. As respostas estão bloqueadas.',
      );
    } catch (error) {
      return _erroOperacao('encerrar a chamada', error);
    }
  }

  @override
  Future<OperacaoResultado> cancelarChamada({String? motivo}) async {
    final chamada = _chamada;
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode cancelar a chamada.',
      );
    }
    if (chamada == null || !chamada.aberta) {
      return const OperacaoResultado.erro(
        'Nenhuma chamada aberta para cancelar.',
      );
    }
    final agora = DateTime.now();
    final motivoLimpo = motivo?.trim();
    try {
      await _db.collection('chamadas').doc(chamada.id).update(<String, dynamic>{
        'status': StatusChamada.cancelada.name,
        'canceladaEm': Timestamp.fromDate(agora),
        'motivoCancelamento': motivoLimpo,
      });
      _chamada = chamada.copyWith(
        status: StatusChamada.cancelada,
        canceladaEm: agora,
        motivoCancelamento: motivoLimpo,
      );
      _notificar();
      return const OperacaoResultado.ok('Chamada cancelada.');
    } catch (error) {
      return _erroOperacao('cancelar a chamada', error);
    }
  }

  @override
  Future<OperacaoResultado> responderChamada({bool? ida, bool? volta}) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro('Entre como aluno para responder.');
    }
    if (ida == null && volta == null) {
      return const OperacaoResultado.erro(
        'Selecione ida ou volta para responder.',
      );
    }
    final chamada = _chamada;
    if (chamada == null) {
      return const OperacaoResultado.erro('Nenhuma chamada aberta.');
    }
    // O bloqueio aparece duas vezes por camadas diferentes: a interface usa
    // `respostaBloqueada` e as regras leem `status`/`viagemBloqueada` da
    // chamada, que é marcada quando a viagem começa.
    if (!chamada.aberta || respostaBloqueada) {
      return const OperacaoResultado.erro(
        'A chamada foi encerrada ou a viagem já começou. '
        'Não é mais possível alterar a resposta.',
      );
    }

    final chamadaId = chamada.id;
    final grupoId = chamada.grupoId;
    final respostaRef = _respostaRef(chamadaId, usuario.id);
    late RespostaPresenca respostaFinal;
    late bool houveAlteracao;

    try {
      // A resposta e o aviso entram na mesma transação: o motorista nunca vê
      // uma notificação sem a resposta correspondente (ou vice-versa).
      await _db.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(respostaRef);
        final gravada = snapshot.exists
            ? respostaFromDoc(snapshot)
            : RespostaPresenca(alunoId: usuario.id);
        final novaIda = ida == null
            ? null
            : (ida ? RespostaSentido.vai : RespostaSentido.naoVai);
        final novaVolta = volta == null
            ? null
            : (volta ? RespostaSentido.vai : RespostaSentido.naoVai);
        final mudouIda = novaIda != null && novaIda != gravada.ida;
        final mudouVolta = novaVolta != null && novaVolta != gravada.volta;

        houveAlteracao = mudouIda || mudouVolta;
        respostaFinal = gravada.copyWith(
          ida: mudouIda ? novaIda : null,
          volta: mudouVolta ? novaVolta : null,
          respondidoEm: DateTime.now(),
        );
        if (!houveAlteracao) return;

        final versao = (snapshot.data()?['versao'] as int?) ?? 0;
        final novaVersao = versao + 1;
        final dados = <String, dynamic>{
          'chamadaId': chamadaId,
          'alunoId': usuario.id,
          'grupoId': grupoId,
          'respondidoEm': FieldValue.serverTimestamp(),
          'versao': novaVersao,
        };
        if (mudouIda) dados['ida'] = novaIda.name;
        if (mudouVolta) dados['volta'] = novaVolta.name;
        transaction.set(respostaRef, dados, SetOptions(merge: true));

        // Primeira resposta não é alteração de uma confirmação já registrada.
        if (!snapshot.exists) return;

        void registrar(
          SentidoViagem sentido,
          RespostaSentido anterior,
          RespostaSentido atual,
        ) {
          if (anterior == atual || !anterior.respondido || !atual.respondido) {
            return;
          }
          transaction.set(
            _db
                .collection('notificacoes')
                .doc('${chamadaId}_${usuario.id}_${sentido.name}_v$novaVersao'),
            <String, dynamic>{
              'grupoId': grupoId,
              'titulo': 'Presença alterada',
              'corpo': 'Aluno alterou uma resposta de presença.',
              'alunoIds': <String>[],
              'tipo': 'resposta_alterada',
              'dados': <String, dynamic>{
                'alunoId': usuario.id,
                'chamadaId': chamadaId,
                'sentido': sentido.name,
                'respostaAnterior': anterior.name,
                'respostaAtual': atual.name,
              },
              'criadoEm': FieldValue.serverTimestamp(),
            },
          );
        }

        registrar(SentidoViagem.ida, gravada.ida, novaIda ?? gravada.ida);
        registrar(
          SentidoViagem.volta,
          gravada.volta,
          novaVolta ?? gravada.volta,
        );
      });

      if (!houveAlteracao) {
        return const OperacaoResultado.ok('Presença já registrada.');
      }
      _respostas[usuario.id] = respostaFinal;
      _notificar();
      return const OperacaoResultado.ok('Presença atualizada.');
    } catch (error) {
      if (_ehPermissionDenied(error)) {
        return const OperacaoResultado.erro(
          'A chamada foi encerrada ou a viagem já começou. '
          'Não é mais possível alterar a resposta.',
        );
      }
      return _erroOperacao('salvar a resposta', error);
    }
  }

  // ---------------------------------------------------------------- viagens

  @override
  Viagem? get viagemAtual => _viagemAtual;

  @override
  List<Viagem> get historico => List<Viagem>.unmodifiable(_historico);

  @override
  Viagem? viagemPorId(String id) {
    if (_viagemAtual?.id == id) return _viagemAtual;
    for (final viagem in _historico) {
      if (viagem.id == id) return viagem;
    }
    return null;
  }

  @override
  List<ConfirmacaoViagem> get confirmacoesViagemAtual =>
      _viagemAtual?.confirmacoes ?? const <ConfirmacaoViagem>[];

  @override
  Future<OperacaoResultado> iniciarViagem(SentidoViagem sentido) async {
    final chamada = _chamada;
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode iniciar a viagem.',
      );
    }
    if (chamada == null) {
      return const OperacaoResultado.erro(
        'Nenhuma chamada criada para amanhã.',
      );
    }
    if (chamada.aberta) {
      return const OperacaoResultado.erro(
        'Encerre a chamada antes de iniciar a viagem.',
      );
    }
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return const OperacaoResultado.erro('Já existe uma viagem em andamento.');
    }

    final confirmacoes = <ConfirmacaoViagem>[];
    for (final aluno in alunosAtivos) {
      final resposta = respostaDe(aluno.id);
      final status = sentido == SentidoViagem.ida
          ? resposta.ida
          : resposta.volta;
      if (status == RespostaSentido.vai) {
        confirmacoes.add(
          ConfirmacaoViagem(
            alunoId: aluno.id,
            status: status,
            estouIndo: resposta.estouIndo,
            estouIndoEm: resposta.estouIndoEm,
            liberadoEm: sentido == SentidoViagem.volta
                ? resposta.liberadoEm
                : null,
          ),
        );
      }
    }

    try {
      final referencia = _db.collection('viagens').doc();
      final lote = _db.batch();
      lote.set(referencia, <String, dynamic>{
        'chamadaId': chamada.id,
        'grupoId': chamada.grupoId,
        'motoristaId': _uid ?? '',
        'dataViagem': Timestamp.fromDate(chamada.dataServico),
        'sentido': sentido.name,
        'status': StatusViagem.emAndamento.name,
        'iniciadaEm': FieldValue.serverTimestamp(),
        'confirmacoes': confirmacoes.map(confirmacaoToMap).toList(),
      });
      // Sinal lido pelas regras de `respostas`: nem uma chamada inconsistente
      // (ainda aberta) aceita mudanças depois que a viagem começou.
      lote.update(_db.collection('chamadas').doc(chamada.id), <String, dynamic>{
        'viagemBloqueada': true,
      });
      await lote.commit();

      return OperacaoResultado.ok(
        'Viagem de ${sentido.label.toLowerCase()} iniciada com '
        '${confirmacoes.length} aluno(s) confirmado(s).',
      );
    } catch (error) {
      return _erroOperacao('iniciar a viagem', error);
    }
  }

  @override
  Future<OperacaoResultado> encerrarViagem() async {
    final viagem = _viagemAtual;
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode encerrar a viagem.',
      );
    }
    if (viagem == null || viagem.status != StatusViagem.emAndamento) {
      return const OperacaoResultado.erro('Nenhuma viagem em andamento.');
    }

    try {
      await _db.collection('viagens').doc(viagem.id).update(<String, dynamic>{
        'status': StatusViagem.encerrada.name,
        'encerradaEm': FieldValue.serverTimestamp(),
      });

      if (viagem.sentido == SentidoViagem.volta) {
        _chamada = null;
        _viagemAtual = null;
        _respostas.clear();
        _notificar();
        return const OperacaoResultado.ok(
          'Viagem de volta encerrada. Uma nova chamada já pode ser aberta.',
        );
      }

      _viagemAtual = null;
      _notificar();
      return const OperacaoResultado.ok(
        'Viagem de ida encerrada. A volta pode ser iniciada.',
      );
    } catch (error) {
      return _erroOperacao('encerrar a viagem', error);
    }
  }

  @override
  Future<OperacaoResultado> cancelarViagem({String? motivo}) async {
    final viagem = _viagemAtual;
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode cancelar a viagem.',
      );
    }
    if (viagem == null) {
      return const OperacaoResultado.erro('Nenhuma viagem para cancelar.');
    }
    if (viagem.status == StatusViagem.cancelada) {
      return const OperacaoResultado.erro('A viagem já foi cancelada.');
    }
    if (viagem.status == StatusViagem.encerrada) {
      return const OperacaoResultado.erro('A viagem já foi encerrada.');
    }

    final agora = DateTime.now();
    final motivoLimpo = motivo?.trim();
    try {
      await _db.collection('viagens').doc(viagem.id).update(<String, dynamic>{
        'status': StatusViagem.cancelada.name,
        'canceladaEm': Timestamp.fromDate(agora),
        'motivoCancelamento': motivoLimpo,
      });

      final cancelada = viagem.copyWith(
        status: StatusViagem.cancelada,
        canceladaEm: agora,
        motivoCancelamento: motivoLimpo,
      );

      _viagemAtual = null;
      _historico.insert(0, cancelada);

      await _criarNotificacao(
        titulo: 'Viagem cancelada',
        corpo: motivoLimpo != null && motivoLimpo.isNotEmpty
            ? 'A viagem de ${viagem.sentido.label.toLowerCase()} foi cancelada. Motivo: $motivoLimpo'
            : 'A viagem de ${viagem.sentido.label.toLowerCase()} foi cancelada pelo motorista.',
        alunoIds: alunosAtivos.map((aluno) => aluno.id).toList(),
        tipo: 'viagem_cancelada',
        dados: <String, dynamic>{'viagemId': viagem.id},
      );

      _notificar();
      return OperacaoResultado.ok(
        'Viagem de ${viagem.sentido.label.toLowerCase()} cancelada.',
      );
    } catch (error) {
      return _erroOperacao('cancelar a viagem', error);
    }
  }

  @override
  Future<OperacaoResultado> avisarAlunos(Iterable<String> alunoIds) async {
    final viagem = _viagemAtual;
    if (viagem == null || viagem.status != StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Inicie uma viagem antes de avisar os alunos.',
      );
    }

    final selecionados = <String>{};
    for (final confirmacao in viagem.confirmacoes) {
      if (alunoIds.contains(confirmacao.alunoId) &&
          confirmacao.status == RespostaSentido.vai &&
          confirmacao.avisadoEm == null) {
        selecionados.add(confirmacao.alunoId);
      }
    }

    if (selecionados.isEmpty) {
      return const OperacaoResultado.erro(
        'Selecione pelo menos um aluno ainda não avisado.',
      );
    }

    try {
      final confirmacoes = viagem.confirmacoes.map((confirmacao) {
        if (!selecionados.contains(confirmacao.alunoId)) {
          return confirmacaoToMap(confirmacao);
        }
        return confirmacaoToMap(
          confirmacao.copyWith(avisadoEm: DateTime.now()),
        );
      }).toList();

      final lote = _db.batch();
      lote.update(_db.collection('viagens').doc(viagem.id), <String, dynamic>{
        'confirmacoes': confirmacoes,
      });
      await lote.commit();

      final nomes = selecionados
          .map((id) => alunoPorId(id)?.primeiroNome)
          .whereType<String>()
          .toList();
      await _criarNotificacao(
        titulo: 'A van está chegando!',
        corpo:
            '${nomes.isEmpty ? 'A van' : nomes.join(', ')}: '
            'vá para a frente de casa.',
        alunoIds: selecionados.toList(),
        tipo: 'chegada',
        dados: <String, dynamic>{'viagemId': viagem.id},
      );

      return OperacaoResultado.ok(
        'Aviso enviado para ${selecionados.length} aluno(s).',
      );
    } catch (error) {
      return _erroOperacao('avisar os alunos', error);
    }
  }

  @override
  Future<OperacaoResultado> registrarEstouIndo() async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro('Entre como aluno para avisar.');
    }
    final chamada = _chamada;
    if (chamada == null) {
      return const OperacaoResultado.erro('Nenhuma chamada ativa.');
    }
    if (respostaBloqueada) {
      return OperacaoResultado.erro(_motivoBloqueio ?? 'Respostas bloqueadas.');
    }

    try {
      await _atualizarConfirmacao(usuario.id, <String, dynamic>{
        'estouIndo': true,
        'estouIndoEm': Timestamp.now(),
      });
      _respostas[usuario.id] = respostaDe(usuario.id)
          .copyWith(estouIndo: true, estouIndoEm: DateTime.now());
      _notificar();
      return const OperacaoResultado.ok(
        'O motorista foi avisado que você está indo.',
      );
    } catch (error) {
      return _erroOperacao('registrar o aviso', error);
    }
  }

  @override
  Future<OperacaoResultado> liberarAluno() async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro('Entre como aluno para avisar.');
    }
    if (respostaBloqueada) {
      return OperacaoResultado.erro(_motivoBloqueio ?? 'Respostas bloqueadas.');
    }
    if (respostaDe(usuario.id).volta != RespostaSentido.vai) {
      return const OperacaoResultado.erro(
        'Confirme a volta na chamada antes de avisar que está liberado.',
      );
    }
    final chamada = _chamada;
    if (chamada == null) {
      return const OperacaoResultado.erro('Nenhuma chamada ativa.');
    }

    try {
      await _atualizarConfirmacao(usuario.id, <String, dynamic>{
        'liberadoEm': Timestamp.now(),
      });
      _respostas[usuario.id] = respostaDe(usuario.id)
          .copyWith(liberadoEm: DateTime.now());
      _notificar();
      return const OperacaoResultado.ok(
        'O motorista foi avisado que você está liberado.',
      );
    } catch (error) {
      return _erroOperacao('registrar a liberação', error);
    }
  }

  @override
  Future<OperacaoResultado> cancelarLiberacao() async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }
    if (respostaBloqueada) {
      return OperacaoResultado.erro(_motivoBloqueio ?? 'Respostas bloqueadas.');
    }

    try {
      await _atualizarConfirmacao(usuario.id, <String, dynamic>{
        'liberadoEm': null,
      });
      _respostas[usuario.id] = respostaDe(usuario.id)
          .copyWith(limparLiberacao: true);
      _notificar();
      return const OperacaoResultado.ok('Aviso de liberação cancelado.');
    } catch (error) {
      return _erroOperacao('cancelar a liberação', error);
    }
  }

  Future<void> _atualizarConfirmacao(
    String alunoId,
    Map<String, dynamic> mudancas,
  ) async {
    final viagem = _viagemAtual;
    if (viagem == null) return;

    final confirmacoes = viagem.confirmacoes.map((confirmacao) {
      final mapa = confirmacaoToMap(confirmacao);
      if (confirmacao.alunoId == alunoId) mapa.addAll(mudancas);
      return mapa;
    }).toList();

    await _db.collection('viagens').doc(viagem.id).update(<String, dynamic>{
      'confirmacoes': confirmacoes,
    });
  }

  // ------------------------------------------------------------ padrão semanal

  @override
  Map<int, PadraoSemanalDia> get padraoSemanal =>
      Map<int, PadraoSemanalDia>.unmodifiable(_padrao);

  @override
  PadraoSemanalDia padraoDoDia(int diaSemana) =>
      _padrao[diaSemana] ?? PadraoSemanalDia(diaSemana: diaSemana);

  @override
  Future<OperacaoResultado> salvarPadraoSemanal(
    Map<int, PadraoSemanalDia> novoPadrao,
  ) async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }

    try {
      if (_grupoAtual.isEmpty) {
        return const OperacaoResultado.erro(
          'Entre em uma van antes de salvar o padrão semanal.',
        );
      }
      await _db
          .collection('padroes')
          .doc(usuario.id)
          .set(
            padraoToMap(novoPadrao, grupoId: _grupoAtual),
            SetOptions(merge: true),
          );

      final chamada = _chamada;
      if (chamada != null && chamada.aberta) {
        final configuracao = novoPadrao[chamada.dataServico.weekday];
        final resposta = respostaDe(usuario.id);
        if (configuracao != null &&
            !resposta.respondido &&
            !respostaBloqueada) {
          await responderChamada(
            ida: configuracao.vaiIda,
            volta: configuracao.vaiVolta,
          );
        }
      }

      _padrao = Map<int, PadraoSemanalDia>.from(novoPadrao);
      _notificar();
      return const OperacaoResultado.ok('Padrão semanal salvo.');
    } catch (error) {
      return _erroOperacao('salvar o padrão semanal', error);
    }
  }

  // ---------------------------------------------------------------- cadastro

  /// Cria somente a conta de motorista e seu perfil, sem grupo de van.
  /// A criação da van acontece depois, no painel "Minhas vans".
  @override
  Future<OperacaoResultado> cadastrarMotorista({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    if (_auth.currentUser != null) {
      return const OperacaoResultado.erro(
        'Saia da conta atual antes de criar uma nova conta.',
      );
    }
    if (nome.trim().length < 3) {
      return const OperacaoResultado.erro('Informe o nome completo.');
    }

    _ignorarAuth = true;
    User? criado;

    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: senha,
      );
      criado = credencial.user;
      if (criado == null) {
        return const OperacaoResultado.erro(
          'Não foi possível criar a conta de motorista.',
        );
      }

      // Sem `grupoId`: nenhum grupo nem código é criado nesta fase.
      final motorista = Usuario(
        id: criado.uid,
        nome: nome.trim(),
        email: email.trim().toLowerCase(),
        perfil: PerfilUsuario.motorista,
        status: StatusConta.ativo,
        ativoFirestore: true,
        telefone: telefone.trim(),
        criadoEm: DateTime.now(),
      );

      await _db
          .collection('usuarios')
          .doc(criado.uid)
          .set(usuarioToMap(motorista));

      // Perfil gravado: a sessão pode ser aplicada sem assinaturas de grupo.
      _ignorarAuth = false;
      final sessao = await _aplicarSessao(criado);
      if (sessao != _SessaoResultado.aplicada) {
        await _auth.signOut();
        await _limparSessao();
        return const OperacaoResultado.erro(
          'Conta criada, mas não foi possível abrir o painel. '
          'Entre novamente com seu e-mail e senha.',
        );
      }

      return const OperacaoResultado.ok(
        'Conta de motorista criada com sucesso!',
      );
    } on FirebaseAuthException catch (error) {
      await _recuperarCadastroParcial(criado);
      debugPrint('[Auth] cadastro motorista: ${error.code}');
      switch (error.code) {
        case 'email-already-in-use':
          return const OperacaoResultado.erro(
            'Já existe uma conta com este e-mail.',
          );
        case 'weak-password':
          return const OperacaoResultado.erro(
            'A senha deve ter ao menos 6 caracteres.',
          );
        case 'invalid-email':
          return const OperacaoResultado.erro('Informe um e-mail válido.');
        case 'network-request-failed':
          return const OperacaoResultado.erro(
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
          );
        default:
          return const OperacaoResultado.erro(
            'Não foi possível criar a conta de motorista.',
          );
      }
    } catch (error) {
      final contaRemovida = await _recuperarCadastroParcial(criado);
      final resultado = _erroGravacaoCadastro(error);
      if (!contaRemovida && criado != null && resultado.mensagem != null) {
        return OperacaoResultado.erro(
          '${resultado.mensagem} Sua conta foi preservada: entre com seu '
          'e-mail e senha para continuar.',
        );
      }
      return resultado;
    } finally {
      _ignorarAuth = false;
    }
  }

  @override
  Future<OperacaoResultado> cadastrarAluno({
    required String nome,
    required String email,
    required String telefone,
    required String instituicao,
    required Turno turno,
    required String endereco,
    required String senha,
  }) async {
    if (_auth.currentUser != null) {
      return const OperacaoResultado.erro(
        'Saia da conta atual antes de criar uma nova conta.',
      );
    }

    _ignorarAuth = true;
    User? criado;

    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: senha,
      );
      criado = credencial.user;
      if (criado == null) {
        return const OperacaoResultado.erro(
          'Não foi possível criar a conta de aluno.',
        );
      }

      final aluno = Usuario(
        id: criado.uid,
        nome: nome.trim(),
        email: email.trim().toLowerCase(),
        perfil: PerfilUsuario.aluno,
        status: StatusConta.pendente,
        ativoFirestore: false,
        telefone: telefone.trim(),
        instituicao: instituicao.trim(),
        turno: turno,
        enderecoEmbarque: endereco.trim(),
        criadoEm: DateTime.now(),
      );

      // Sem `grupoId`: o aluno só é vinculado após informar o código da van e
      // ser aprovado pelo motorista. As regras recusam qualquer grupoId aqui.
      await _db.collection('usuarios').doc(criado.uid).set(usuarioToMap(aluno));

      // O aluno permanece autenticado para informar o código da van. A sessão
      // pendente é aplicada com acesso restrito, sem assinaturas do grupo.
      _ignorarAuth = false;
      final sessao = await _aplicarSessao(criado);
      if (sessao != _SessaoResultado.aplicada &&
          sessao != _SessaoResultado.pendente) {
        await _auth.signOut();
        await _limparSessao();
        return const OperacaoResultado.erro(
          'Conta criada, mas não foi possível abrir o painel. '
          'Entre novamente com seu e-mail e senha.',
        );
      }

      return const OperacaoResultado.ok(
        'Conta criada! Agora informe o código da van do seu motorista.',
      );
    } on FirebaseAuthException catch (error) {
      await _recuperarCadastroParcial(criado);
      debugPrint('[Auth] cadastro aluno: ${error.code}');
      switch (error.code) {
        case 'email-already-in-use':
          return const OperacaoResultado.erro(
            'Já existe uma conta com este e-mail.',
          );
        case 'weak-password':
          return const OperacaoResultado.erro(
            'A senha deve ter ao menos 6 caracteres.',
          );
        case 'invalid-email':
          return const OperacaoResultado.erro('Informe um e-mail válido.');
        case 'network-request-failed':
          return const OperacaoResultado.erro(
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
          );
        default:
          return const OperacaoResultado.erro(
            'Não foi possível criar a conta de aluno.',
          );
      }
    } catch (error) {
      final contaRemovida = await _recuperarCadastroParcial(criado);
      final resultado = _erroGravacaoCadastro(error);
      if (!contaRemovida && criado != null && resultado.mensagem != null) {
        return OperacaoResultado.erro(
          '${resultado.mensagem} Sua conta foi preservada: entre com seu '
          'e-mail e senha para continuar.',
        );
      }
      return resultado;
    } finally {
      _ignorarAuth = false;
    }
  }

  /// Desfaz somente a conta Auth criada nesta tentativa, e somente quando o
  /// perfil não chegou a ser gravado. Grupos, códigos e perfis existentes nunca
  /// são apagados por aqui. Retorna `true` quando não sobra conta temporária.
  Future<bool> _cancelarCadastroParcial(User? usuario) async {
    if (usuario == null) return true;

    try {
      final perfil = await _db.collection('usuarios').doc(usuario.uid).get();
      if (perfil.exists) {
        debugPrint(
          '[Auth] rollback preservado: perfil de ${usuario.uid} já existe.',
        );
        return false;
      }
      if (_auth.currentUser?.uid == usuario.uid) {
        await usuario.delete();
      }
      return true;
    } catch (error) {
      // Sem confirmação da leitura, não é seguro apagar a conta: a gravação
      // pode ter chegado ao servidor mesmo com falha na resposta ao cliente.
      debugPrint(
        '[Auth] rollback inconclusivo (${_descreverErroSeguro(error)}): '
        'conta preservada.',
      );
      return false;
    }
  }

  /// Encerra a sessão temporária para que a pessoa possa tentar de novo ou
  /// entrar com a conta preservada. Nunca desconecta uma sessão alheia: os
  /// métodos de cadastro só chegam aqui quando não havia usuário logado.
  Future<bool> _recuperarCadastroParcial(User? usuario) async {
    final contaRemovida = await _cancelarCadastroParcial(usuario);
    try {
      if (_auth.currentUser != null) await _auth.signOut();
    } catch (error) {
      debugPrint(
        '[Auth] signOut após falha de cadastro: ${_descreverErroSeguro(error)}',
      );
    }
    await _limparSessao();
    return contaRemovida;
  }

  @override
  Turno get conviteTurno => _conviteTurno;

  @override
  String? get conviteToken => _conviteToken;

  @override
  String? get linkConvite =>
      _conviteToken == null ? null : 'https://vango.app/convite/$_conviteToken';

  @override
  Future<String?> gerarConvite(Turno turno) async {
    if (!ehMotorista) return null;

    final token =
        '${turno.name}-${DateTime.now().microsecondsSinceEpoch}-'
        '${gerarCodigoGrupo(usados: _codigosSugeridos)}';
    try {
      await _db.collection('convites').doc(token).set(<String, dynamic>{
        'grupoId': _grupoOperacional,
        'motoristaId': _uid ?? '',
        'turno': turno.name,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      _conviteTurno = turno;
      _conviteToken = token;
      _notificar();
      return token;
    } catch (error) {
      debugPrint('[Firestore] falha ao gerar convite: $error');
      return null;
    }
  }

  @override
  Future<Turno?> carregarConvite(String token) async {
    try {
      final doc = await _db.collection('convites').doc(token).get();
      if (!doc.exists) return null;
      final dados = doc.data() ?? const <String, dynamic>{};
      final turno = enumDe(Turno.values, dados['turno'], _conviteTurno);
      _conviteTurno = turno;
      _conviteToken = token;
      _notificar();
      return turno;
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao carregar convite: $_erro');
      return null;
    }
  }

  @override
  Future<OperacaoResultado> enviarSolicitacao({
    required String nome,
    required String email,
    required String telefone,
    required String instituicao,
    required String endereco,
    required String senha,
    required Turno turno,
    String? conviteToken,
  }) async {
    if (_auth.currentUser != null) {
      return const OperacaoResultado.erro(
        'Saia da conta atual antes de criar uma nova conta.',
      );
    }

    _ignorarAuth = true;
    User? criado;
    try {
      // Somente um convite válido e com vínculo real define o grupo. Um token
      // ausente/inválido nunca deve vincular a conta ao grupo legado.
      String? grupoIdConvite;
      Turno turnoConvite = turno;

      if (conviteToken != null &&
          conviteToken.isNotEmpty &&
          conviteToken != 'solicitacao-direta' &&
          conviteToken != 'solicitacao' &&
          conviteToken != 'convite-demo') {
        try {
          final convite = await _db
              .collection('convites')
              .doc(conviteToken)
              .get();
          if (convite.exists) {
            final dadosConvite = convite.data() ?? const <String, dynamic>{};
            final grupoId = (dadosConvite['grupoId'] as String?)?.trim();
            if (grupoId != null && grupoId.isNotEmpty) {
              grupoIdConvite = grupoId;
            }
            turnoConvite = enumDe(Turno.values, dadosConvite['turno'], turno);
          }
        } catch (error) {
          if (_ehPermissionDenied(error) ||
              (error is FirebaseException &&
                  error.code == 'failed-precondition')) {
            _ignorarAuth = false;
            return OperacaoResultado.erro(_descreverErroCarregamento(error));
          }
          debugPrint(
            '[Firestore] convite inválido: ${_descreverErroSeguro(error)}',
          );
        }
      }

      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: senha.trim(),
      );
      criado = credencial.user;
      if (criado == null) {
        return const OperacaoResultado.erro(
          'Não foi possível criar a conta de aluno.',
        );
      }

      final aluno = Usuario(
        id: criado.uid,
        nome: nome.trim(),
        email: email.trim().toLowerCase(),
        perfil: PerfilUsuario.aluno,
        status: StatusConta.pendente,
        ativoFirestore: false,
        telefone: telefone.trim(),
        instituicao: instituicao,
        turno: turnoConvite,
        enderecoEmbarque: endereco.trim(),
        criadoEm: DateTime.now(),
      );

      // O perfil é criado sem grupo. O vínculo com a van acontece
      // exclusivamente pela solicitação, com o aluno já autenticado.
      await _db.collection('usuarios').doc(criado.uid).set(usuarioToMap(aluno));

      _ignorarAuth = false;
      final sessao = await _aplicarSessao(criado);
      if (sessao != _SessaoResultado.aplicada &&
          sessao != _SessaoResultado.pendente) {
        await _auth.signOut();
        await _limparSessao();
        return const OperacaoResultado.erro(
          'Conta criada, mas não foi possível abrir o perfil. '
          'Entre novamente com seu e-mail e senha.',
        );
      }

      if (grupoIdConvite == null) {
        return const OperacaoResultado.ok(
          'Conta criada! Informe o código da van no seu painel para solicitar entrada.',
        );
      }

      final entrada = await solicitarEntradaGrupo(grupoId: grupoIdConvite);
      if (!entrada.sucesso) {
        return OperacaoResultado.erro(
          'Perfil criado, mas a solicitação não foi enviada. '
          '${entrada.mensagem ?? ''} Entre novamente e informe o código da van.',
        );
      }

      return const OperacaoResultado.ok(
        'Solicitação enviada com sucesso! Seu cadastro está pendente e aguarda aprovação pelo motorista.',
      );
    } on FirebaseAuthException catch (error) {
      await _recuperarCadastroParcial(criado);
      debugPrint('[Auth] cadastro: ${error.code}');
      if (error.code == 'email-already-in-use') {
        return const OperacaoResultado.erro(
          'Já existe uma conta com este e-mail.',
        );
      }
      if (error.code == 'weak-password') {
        return const OperacaoResultado.erro(
          'A senha deve ter ao menos 6 caracteres.',
        );
      }
      if (error.code == 'network-request-failed') {
        return const OperacaoResultado.erro(
          'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        );
      }
      return const OperacaoResultado.erro(
        'Não foi possível criar a conta. Tente novamente.',
      );
    } catch (error) {
      final contaRemovida = await _recuperarCadastroParcial(criado);
      final resultado = _erroGravacaoCadastro(error);
      if (!contaRemovida && criado != null && resultado.mensagem != null) {
        return OperacaoResultado.erro(
          '${resultado.mensagem} Sua conta foi preservada: entre com seu '
          'e-mail e senha para continuar.',
        );
      }
      return resultado;
    } finally {
      _ignorarAuth = false;
    }
  }

  // ------------------------------------------------------------------ grupos

  @override
  Future<List<GrupoVan>> carregarMeusGrupos() async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.motorista) {
      _grupos = <GrupoVan>[];
      return <GrupoVan>[];
    }
    _erro = null;
    try {
      // As regras exigem filtro por motoristaId para listar grupos.
      final snapshot = await _db
          .collection('grupos')
          .where('motoristaId', isEqualTo: usuario.id)
          .get();
      final grupos = snapshot.docs.map(grupoFromDoc).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      final preferido = await SelecaoGrupoStore.carregar();
      final escolhido = grupos.cast<GrupoVan?>().firstWhere(
        (grupo) => grupo?.id == preferido,
        orElse: () => null,
      );
      final selecaoAnterior = _grupoSelecionadoId;
      final selecaoAtual =
          (escolhido ?? (grupos.isEmpty ? null : grupos.first))?.id;
      _grupos = grupos;
      _grupoSelecionadoId = selecaoAtual;
      notifyListeners();
      if (selecaoAtual != selecaoAnterior) {
        await SelecaoGrupoStore.salvar(selecaoAtual);
        await _cancelarAssinaturas();
        _limparEstadoDaVan();
        unawaited(_assinarDados());
      }
      return List.unmodifiable(grupos);
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao listar vans do motorista: $_erro');
      return List.unmodifiable(_grupos);
    }
  }

  @override
  Future<int> contarAlunosGrupo(String grupoId) async {
    if (grupoId.trim().isEmpty) return 0;
    _erro = null;
    try {
      final snapshot = await _db
          .collection('usuarios')
          .where('grupoId', isEqualTo: grupoId.trim())
          .get();
      return snapshot.docs
          .map(usuarioFromDoc)
          .where(
            (aluno) => aluno.perfil == PerfilUsuario.aluno && aluno.podeAcessar,
          )
          .length;
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao contar alunos da van: $_erro');
      return 0;
    }
  }

  @override
  Future<OperacaoResultado> selecionarGrupo(String grupoId) async {
    final grupo = _grupos.cast<GrupoVan?>().firstWhere(
      (item) => item?.id == grupoId,
      orElse: () => null,
    );
    if (grupo == null) {
      return const OperacaoResultado.erro(
        'Van não encontrada para este motorista.',
      );
    }
    if (_grupoSelecionadoId == grupoId) {
      return const OperacaoResultado.ok('Van já selecionada.');
    }
    _grupoSelecionadoId = grupoId;
    await SelecaoGrupoStore.salvar(grupoId);
    await _cancelarAssinaturas();
    _limparEstadoDaVan();
    unawaited(_assinarDados());
    _notificar();
    return const OperacaoResultado.ok('Van selecionada.');
  }

  @override
  Future<OperacaoResultado> criarGrupo({
    required String nome,
    String? cidadeOrigem,
    String? cidadeDestino,
    PeriodoVan? periodo,
    String? periodoPersonalizado,
    String? horarioSaida,
    String? observacoes,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.motorista) {
      return const OperacaoResultado.erro(
        'Apenas motoristas podem criar vans.',
      );
    }
    final nomeLimpo = nome.trim();
    if (nomeLimpo.length < 3) {
      return const OperacaoResultado.erro('Informe o nome da van.');
    }
    if (periodo == PeriodoVan.personalizado &&
        (periodoPersonalizado?.trim().isEmpty ?? true)) {
      return const OperacaoResultado.erro('Descreva o período personalizado.');
    }

    try {
      final usados = await _codigosReservados();
      final codigo = gerarCodigoGrupo(usados: usados);
      final expiraEm = Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 10)),
      );
      final grupoRef = _db
          .collection('grupos')
          .doc('grupo_${usuario.id}_$codigo');

      // Transação: a criação do documento de código é atômica. Se outro
      // dispositivo reservar o mesmo código, a transação é repetida com outro.
      String codigoFinal = codigo;
      DocumentReference<Map<String, dynamic>> grupoFinal = grupoRef;
      DocumentReference<Map<String, dynamic>> codigoFinalRef = _db
          .collection('codigos')
          .doc(codigoFinal);
      for (var tentativa = 0; tentativa < 8; tentativa++) {
        try {
          await _db.runTransaction((txn) async {
            final reserva = await txn.get(
              _db.collection('codigos').doc(codigoFinal),
            );
            if (reserva.exists) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'already-exists',
                message: 'Código já reservado',
              );
            }
            txn.set(
              _db.collection('codigos').doc(codigoFinal),
              <String, dynamic>{
                'reservadoEm': FieldValue.serverTimestamp(),
                'expiraEm': expiraEm,
                'reservadoPor': usuario.id,
              },
            );
          });
          break;
        } on FirebaseException catch (error) {
          if (error.code != 'already-exists' || tentativa == 7) rethrow;
          _lembrarCodigo(codigoFinal);
          codigoFinal = gerarCodigoGrupo(usados: usados..add(codigoFinal));
          grupoFinal = _db
              .collection('grupos')
              .doc('grupo_${usuario.id}_$codigoFinal');
          codigoFinalRef = _db.collection('codigos').doc(codigoFinal);
        }
      }

      try {
        // O grupo e o vínculo do código são gravados na mesma transação,
        // porque as regras leem o grupo com get() — ele ainda não existe no
        // estado anterior de um writeBatch.
        await _db.runTransaction((txn) async {
          txn.set(
            grupoFinal,
            grupoToMap(
              id: grupoFinal.id,
              nome: nomeLimpo,
              motoristaId: usuario.id,
              codigo: codigoFinal,
              cidadeOrigem: cidadeOrigem,
              cidadeDestino: cidadeDestino,
              periodoEnum: periodo,
              periodoPersonalizado: periodoPersonalizado,
              horarioSaida: horarioSaida,
              observacoes: observacoes,
            ),
          );
          txn.update(codigoFinalRef, <String, dynamic>{
            'grupoId': grupoFinal.id,
            'motoristaId': usuario.id,
          });
        });
      } catch (error) {
        // Reservas órfãs podem ser apagadas pela própria regra (sem vínculo).
        await codigoFinalRef.delete().catchError((_) {});
        rethrow;
      }

      _lembrarCodigo(codigoFinal);
      await carregarMeusGrupos();
      await selecionarGrupo(grupoFinal.id);
      return OperacaoResultado.ok(
        'Van “$nomeLimpo” criada. Código: $codigoFinal',
      );
    } on FirebaseException catch (error) {
      return _erroOperacao('criar a van', error);
    } catch (error) {
      return _erroOperacao('criar a van', error);
    }
  }

  /// A listagem de `codigos` é proibida pelas regras. Mantemos apenas um
  /// histórico local dos últimos códigos gerados para reduzir colisões; a
  /// transação pontual continua sendo a garantia real de unicidade.
  final Set<String> _codigosSugeridos = <String>{};

  Future<Set<String>> _codigosReservados() async =>
      Set<String>.from(_codigosSugeridos);

  void _lembrarCodigo(String codigo) {
    _codigosSugeridos.add(codigo);
    if (_codigosSugeridos.length > 200) {
      _codigosSugeridos.remove(_codigosSugeridos.first);
    }
  }

  @override
  Future<GrupoVan?> buscarGrupoPorCodigo(String codigo) async {
    _erro = null;
    final codigoLimpo = codigo.trim();
    if (codigoLimpo.length != 6 || int.tryParse(codigoLimpo) == null) {
      return null;
    }

    try {
      // As regras liberam a listagem de grupos somente para motoristas com
      // vínculo real. A busca do aluno usa o mapeamento pontual do código,
      // seguido da leitura do grupo por ID — ambas permitidas a autenticados.
      final codigoDoc = await _db.collection('codigos').doc(codigoLimpo).get();
      final grupoId = (codigoDoc.data()?['grupoId'] as String?)?.trim();
      if (grupoId == null || grupoId.isEmpty) return null;
      return await buscarGrupoPorId(grupoId);
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao buscar grupo por código: $_erro');
      return null;
    }
  }

  @override
  Future<GrupoVan?> buscarGrupoPorId(String grupoId) async {
    final idLimpo = grupoId.trim();
    if (idLimpo.isEmpty) return null;

    try {
      final doc = await _db.collection('grupos').doc(idLimpo).get();
      if (!doc.exists) return null;
      return grupoFromDoc(doc);
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao buscar grupo por ID: $_erro');
      return null;
    }
  }

  @override
  Future<OperacaoResultado> solicitarEntradaGrupo({
    required String grupoId,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro(
        'Apenas alunos podem solicitar entrada em uma van.',
      );
    }
    // Permite solicitar nova van se o aluno foi recusado ou desativado no grupo anterior
    if (usuario.grupoId != null &&
        usuario.grupoId!.isNotEmpty &&
        usuario.status == StatusConta.pendente) {
      return const OperacaoResultado.erro(
        'Você já tem uma solicitação pendente. Aguarde a aprovação do motorista.',
      );
    }

    try {
      final grupoRef = _db.collection('grupos').doc(grupoId);
      final grupoDoc = await grupoRef.get();
      if (!grupoDoc.exists) {
        return const OperacaoResultado.erro('Van não encontrada.');
      }

      // ID determinístico: cada aluno mantém no máximo uma solicitação ativa.
      // Depois de uma recusa, o mesmo documento é reaberto para nova tentativa.
      // Solicitação e vínculo do perfil são gravados no mesmo lote atômico:
      // nunca sobra uma pendente sem o aluno realmente vinculado.
      final lote = _db.batch();
      lote.set(
        _db.collection('solicitacoes').doc(usuario.id),
        <String, dynamic>{
          'grupoId': grupoId,
          'alunoId': usuario.id,
          'status': 'pendente',
          'criadoEm': FieldValue.serverTimestamp(),
        },
      );
      lote.set(_db.collection('usuarios').doc(usuario.id), <String, dynamic>{
        'grupoId': grupoId,
        'status': StatusConta.pendente.name,
        'ativo': false,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await lote.commit();

      return const OperacaoResultado.ok(
        'Solicitação enviada! Aguarde a aprovação do motorista.',
      );
    } catch (error) {
      return _erroOperacao('solicitar entrada no grupo', error);
    }
  }

  @override
  Future<OperacaoResultado> gerarNovoCodigoGrupo(String grupoId) async {
    final grupo = _grupos.cast<GrupoVan?>().firstWhere(
      (item) => item?.id == grupoId,
      orElse: () => null,
    );
    if (grupo == null) {
      return const OperacaoResultado.erro('Van não encontrada.');
    }
    final usados = await _codigosReservados();
    for (var tentativa = 0; tentativa < 5; tentativa++) {
      final codigo = gerarCodigoGrupo(usados: usados);
      _lembrarCodigo(codigo);
      final resultado = await atualizarCodigoGrupo(grupoId, codigo);
      if (resultado.sucesso ||
          (resultado.mensagem?.contains('em uso') ?? false) == false) {
        return resultado;
      }
      _lembrarCodigo(codigo);
    }
    return const OperacaoResultado.erro(
      'Não foi possível gerar um código único. Tente novamente.',
    );
  }

  @override
  Future<List<Usuario>> carregarSolicitacoes(String grupoId) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.motorista) {
      return <Usuario>[];
    }
    final grupo = await buscarGrupoPorId(grupoId);
    if (grupo == null || grupo.motoristaId != usuario.id) {
      return <Usuario>[];
    }
    try {
      final snapshot = await _db
          .collection('solicitacoes')
          .where('grupoId', isEqualTo: grupoId)
          .get();
      final alunos = <Usuario>[];
      for (final doc in snapshot.docs) {
        if (doc.data()['status'] != 'pendente') continue;
        final alunoId = doc.data()['alunoId'] as String?;
        if (alunoId == null) continue;
        final perfilDoc = await _db.collection('usuarios').doc(alunoId).get();
        if (perfilDoc.exists) alunos.add(usuarioFromDoc(perfilDoc));
      }
      _solicitacoes
        ..clear()
        ..addAll(alunos);
      notifyListeners();
      return List.unmodifiable(_solicitacoes);
    } catch (error) {
      _erro = _descreverErroCarregamento(error);
      debugPrint('[Firestore] falha ao carregar solicitações: $_erro');
      return List.unmodifiable(_solicitacoes);
    }
  }

  @override
  Future<OperacaoResultado> atualizarCodigoGrupo(
    String grupoId,
    String novoCodigo,
  ) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.motorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode alterar o código da van.',
      );
    }
    if (!_grupos.any(
      (grupo) => grupo.id == grupoId && grupo.motoristaId == usuario.id,
    )) {
      return const OperacaoResultado.erro(
        'Você só pode alterar o código das suas próprias vans.',
      );
    }
    final codigoLimpo = novoCodigo.trim();
    if (codigoLimpo.length != 6 || int.tryParse(codigoLimpo) == null) {
      return const OperacaoResultado.erro(
        'O código deve ter exatamente 6 dígitos numéricos.',
      );
    }

    try {
      // Lê o código atual do grupo
      final grupoDoc = await _db.collection('grupos').doc(grupoId).get();
      if (!grupoDoc.exists) {
        return const OperacaoResultado.erro('Van não encontrada.');
      }
      final codigoAtual = grupoDoc.data()?['codigo'] as String?;

      // Tenta reservar o novo código na coleção 'codigos'
      final novoCodigoRef = _db.collection('codigos').doc(codigoLimpo);
      await _db.runTransaction((txn) async {
        final snap = await txn.get(novoCodigoRef);
        if (snap.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-exists',
            message: 'Código já em uso',
          );
        }
        txn.set(novoCodigoRef, <String, dynamic>{
          'reservadoEm': FieldValue.serverTimestamp(),
          'expiraEm': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 10)),
          ),
          'reservadoPor': usuario.id,
        });
      });

      // Liberação do código antigo, vinculação do novo e atualização da van
      // acontecem no mesmo lote atômico: nunca fica um código órfão.
      final lote = _db.batch();
      if (codigoAtual != null && codigoAtual.isNotEmpty) {
        lote.delete(_db.collection('codigos').doc(codigoAtual));
      }
      lote.update(novoCodigoRef, <String, dynamic>{
        'grupoId': grupoId,
        'motoristaId': usuario.id,
      });
      lote.update(_db.collection('grupos').doc(grupoId), <String, dynamic>{
        'codigo': codigoLimpo,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
      await lote.commit();
      _lembrarCodigo(codigoLimpo);

      return const OperacaoResultado.ok('Código da van atualizado.');
    } on FirebaseException catch (e) {
      if (e.code == 'already-exists') {
        return const OperacaoResultado.erro(
          'Este código já está em uso. Tente outro.',
        );
      }
      return _erroOperacao('atualizar o código da van', e);
    } catch (error) {
      return _erroOperacao('atualizar o código da van', error);
    }
  }

  // ------------------------------------------------------------------ perfil

  @override
  Future<OperacaoResultado> atualizarPerfil({
    required String nome,
    required String telefone,
    String? instituicao,
    String? endereco,
    String? referencia,
    Turno? turno,
    String? fotoUrl,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }

    final nomeLimpo = nome.trim();
    final telefoneLimpo = telefone.trim();

    // Apenas os campos informados pelo chamador entram no merge: o motorista,
    // por exemplo, nunca grava instituição/endereço/turno do aluno.
    final dados = <String, dynamic>{
      'nome': nomeLimpo,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    // Motorista altera apenas nome/telefone/foto; campos escolares pertencem
    // ao perfil do aluno e são recusados pelas regras do Firestore.
    if (usuario.perfil == PerfilUsuario.aluno || telefoneLimpo.isNotEmpty) {
      dados['telefone'] = telefoneLimpo;
    }
    if (usuario.perfil == PerfilUsuario.aluno) {
      if (instituicao != null) dados['instituicao'] = instituicao.trim();
      if (endereco != null) dados['enderecoEmbarque'] = endereco.trim();
      if (referencia != null) dados['referenciaEndereco'] = referencia.trim();
      if (turno != null) dados['turno'] = turno.name;
      if (fotoUrl != null) dados['fotoUrl'] = fotoUrl;
    }

    try {
      await _db
          .collection('usuarios')
          .doc(usuario.id)
          .set(dados, SetOptions(merge: true));

      _usuarioAtual = usuario.copyWith(
        nome: nomeLimpo,
        telefone: telefoneLimpo,
        instituicao: instituicao?.trim(),
        enderecoEmbarque: endereco?.trim(),
        referenciaEndereco: referencia?.trim(),
        turno: turno,
        fotoUrl: fotoUrl,
      );
      _notificar();
      return const OperacaoResultado.ok('Perfil atualizado.');
    } catch (error) {
      return _erroOperacao('salvar o perfil', error);
    }
  }

  @override
  Future<OperacaoResultado> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }
    if (senhaAtual.trim().length < 6) {
      return const OperacaoResultado.erro('Informe a senha atual.');
    }
    if (novaSenha.trim().length < 6) {
      return const OperacaoResultado.erro(
        'A nova senha deve ter ao menos 6 caracteres.',
      );
    }

    try {
      final credencial = EmailAuthProvider.credential(
        email: email,
        password: senhaAtual,
      );
      await user.reauthenticateWithCredential(credencial);
      await user.updatePassword(novaSenha);
      return const OperacaoResultado.ok('Senha alterada.');
    } on FirebaseAuthException catch (error) {
      debugPrint('[Auth] alterar senha: ${error.code}');
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        return const OperacaoResultado.erro('A senha atual está incorreta.');
      }
      if (error.code == 'weak-password') {
        return const OperacaoResultado.erro(
          'A nova senha deve ter ao menos 6 caracteres.',
        );
      }
      if (error.code == 'requires-recent-login') {
        return const OperacaoResultado.erro(
          'Faça login novamente antes de alterar a senha.',
        );
      }
      return const OperacaoResultado.erro(
        'Não foi possível alterar a senha. Tente novamente.',
      );
    }
  }

  @override
  Future<OperacaoResultado> atualizarFotoPerfil({
    required Uint8List bytes,
    required String extensao,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }

    final ext = extensao.toLowerCase().replaceAll('.', '');
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

    try {
      final referencia = _storage.ref('usuarios/${usuario.id}/foto.$ext');
      await referencia.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await referencia.getDownloadURL();

      await _db.collection('usuarios').doc(usuario.id).set(<String, dynamic>{
        'fotoUrl': url,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _usuarioAtual = usuario.copyWith(fotoUrl: url);
      _notificar();
      return const OperacaoResultado.ok('Foto atualizada.');
    } on FirebaseException catch (error) {
      debugPrint('[Storage] ${error.code}: ${error.message}');
      return const OperacaoResultado.erro(
        'Não foi possível enviar a foto. Tente novamente.',
      );
    } catch (error) {
      return _erroOperacao('enviar a foto', error);
    }
  }

  // ------------------------------------------------------------------ extras

  @override
  List<PresencaAluno> confirmadosNoSentido(SentidoViagem sentido) {
    final lista = presencasChamada.where((presenca) {
      final resposta = presenca.resposta;
      return sentido == SentidoViagem.ida
          ? resposta.ida == RespostaSentido.vai
          : resposta.volta == RespostaSentido.vai;
    }).toList();
    if (sentido == SentidoViagem.volta) {
      lista.sort((a, b) {
        final liberadoA = a.resposta.liberadoEm != null;
        final liberadoB = b.resposta.liberadoEm != null;
        if (liberadoA != liberadoB) return liberadoA ? -1 : 1;
        return _normalizar(a.nome).compareTo(_normalizar(b.nome));
      });
    }
    return lista;
  }

  @override
  List<PresencaAluno> get presencasViagemAtual {
    final viagem = _viagemAtual;
    if (viagem == null) return const <PresencaAluno>[];

    final alunos = <PresencaAluno>[];
    for (final confirmacao in viagem.confirmacoes) {
      final aluno = alunoPorId(confirmacao.alunoId);
      if (aluno == null) continue;
      alunos.add(
        PresencaAluno(
          aluno: aluno,
          resposta: respostaDe(aluno.id).copyWith(
            estouIndo: confirmacao.estouIndo,
            estouIndoEm: confirmacao.estouIndoEm,
            liberadoEm: confirmacao.liberadoEm,
            avisadoEm: confirmacao.avisadoEm,
          ),
        ),
      );
    }
    return alunos;
  }

  @override
  int get totalRespostas =>
      presencasChamada.where((presenca) => presenca.resposta.respondido).length;

  // ------------------------------------------------------------------ helpers

  DocumentReference<Map<String, dynamic>> _respostaRef(
    String chamadaId,
    String alunoId,
  ) {
    return _db.collection('respostas').doc('${chamadaId}_$alunoId');
  }

  Future<void> _criarNotificacao({
    required String titulo,
    required String corpo,
    required List<String> alunoIds,
    required String tipo,
    Map<String, dynamic>? dados,
  }) async {
    if (alunoIds.isEmpty) return;
    try {
      await _db.collection('notificacoes').add(<String, dynamic>{
        'grupoId': _grupoOperacional,
        'titulo': titulo,
        'corpo': corpo,
        'alunoIds': alunoIds,
        'tipo': tipo,
        'dados': dados ?? <String, dynamic>{},
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // A notificação push é opcional: não impede a operação principal.
      debugPrint('[FCM] falha ao enfileirar notificação: $error');
    }
  }

  /// Descreve a falha sem registrar dados sensíveis. A senha nunca entra aqui:
  /// apenas códigos/mensagens de erro do Firebase ou o tipo da exceção.
  /// Classifica uma falha de leitura sincronizada sem confundi-la com rede.
  String _descreverErroCarregamento(Object error) {
    if (_ehPermissionDenied(error)) {
      return 'Sem permissão para sincronizar os dados da van. Solicite ao '
          'motorista que revise o vínculo do seu cadastro.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Sua sessão expirou. Entre novamente para continuar.';
        case 'failed-precondition':
          return 'O servidor não está pronto para esta consulta. Falta um '
              'índice no Firestore. Contate o administrador.';
        case 'not-found':
          return 'Não encontramos este registro no servidor. Atualize a tela '
              'ou solicite um novo convite.';
        case 'invalid-argument':
          return 'O servidor recusou os dados da consulta. Contate o administrador.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Não foi possível sincronizar com o servidor. Verifique sua '
              'conexão e tente novamente.';
      }
    }
    return 'Não foi possível carregar os dados do servidor. Tente novamente.';
  }

  String _descreverErroSeguro(Object error) {
    if (error is FirebaseException) {
      return '${error.code}: ${error.message ?? 'sem mensagem'}';
    }
    if (error is FirebaseAuthException) return error.code;
    return error.runtimeType.toString();
  }

  /// Erro específico da gravação do perfil no cadastro. Não transforma
  /// `permission-denied` em problema genérico de internet.
  OperacaoResultado _erroGravacaoCadastro(Object error) {
    debugPrint(
      '[Cadastro] falha ao gravar perfil: ${_descreverErroSeguro(error)}',
    );

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return const OperacaoResultado.erro(
            'O servidor recusou a criação do perfil. Confira se as regras de '
            'cadastro estão publicadas e tente novamente.',
          );
        case 'unavailable':
        case 'network-request-failed':
          return const OperacaoResultado.erro(
            'Não foi possível gravar o perfil no servidor. Verifique a conexão '
            'e tente novamente.',
          );
        case 'already-exists':
          return const OperacaoResultado.erro(
            'Já existe um perfil para esta conta. Entre com seu e-mail e senha.',
          );
        case 'invalid-argument':
          return const OperacaoResultado.erro(
            'O servidor recusou os dados do perfil. Confira os campos e tente novamente.',
          );
        case 'failed-precondition':
          return const OperacaoResultado.erro(
            'O servidor não aceitou esta operação no estado atual. Tente novamente.',
          );
        default:
          return const OperacaoResultado.erro(
            'Não foi possível gravar o perfil no servidor. Tente novamente.',
          );
      }
    }

    return const OperacaoResultado.erro(
      'Não foi possível gravar o perfil no servidor. Tente novamente.',
    );
  }

  OperacaoResultado _erroOperacao(String acao, Object error) {
    debugPrint('[Firestore] falha ao $acao: ${_descreverErroSeguro(error)}');

    if (error is FirebaseException) {
      debugPrint(
        '[FirebaseException] code: ${error.code}, message: ${error.message}',
      );
      if (error.code == 'permission-denied') {
        return const OperacaoResultado.erro(
          'Acesso negado pelo servidor. Seu cadastro pode estar pendente de '
          'aprovação ou você não tem permissão nesta van.',
        );
      }
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed') {
        return const OperacaoResultado.erro(
          'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
        );
      }
      if (error.code == 'unauthenticated') {
        unawaited(_auth.signOut());
        return const OperacaoResultado.erro(
          'Sessão expirada. Faça login novamente.',
        );
      }
      if (error.code == 'not-found') {
        return const OperacaoResultado.erro(
          'O registro solicitado não foi encontrado.',
        );
      }
      if (error.code == 'failed-precondition') {
        return const OperacaoResultado.erro(
          'O servidor não está pronto para esta consulta. Falta um índice no '
          'Firestore ou a operação é inválida no estado atual. Contate o administrador.',
        );
      }
      if (error.code == 'invalid-argument') {
        return const OperacaoResultado.erro(
          'Dados inválidos: confira os campos informados e tente novamente.',
        );
      }
      if (error.code == 'already-exists') {
        return const OperacaoResultado.erro(
          'Já existe um registro com estes dados. Tente novamente.',
        );
      }
      if (error.code == 'deadline-exceeded') {
        return const OperacaoResultado.erro(
          'O servidor demorou para responder. Tente novamente em instantes.',
        );
      }
    }

    if (error is FirebaseAuthException) {
      debugPrint('[FirebaseAuthException] code: ${error.code}');
      if (error.code == 'user-not-found' ||
          error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        return const OperacaoResultado.erro('E-mail ou senha incorretos.');
      }
      if (error.code == 'user-disabled') {
        return const OperacaoResultado.erro('Esta conta foi desativada.');
      }
      if (error.code == 'email-already-in-use') {
        return const OperacaoResultado.erro(
          'Já existe uma conta com este e-mail.',
        );
      }
      if (error.code == 'network-request-failed') {
        return const OperacaoResultado.erro(
          'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        );
      }
    }

    return OperacaoResultado.erro(
      'Não foi possível $acao. Tente novamente em alguns instantes.',
    );
  }

  static String _normalizar(String valor) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const semAcento = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final caractere in valor.toLowerCase().split('')) {
      final indice = comAcento.indexOf(caractere);
      buffer.write(indice >= 0 ? semAcento[indice] : caractere);
    }
    return buffer.toString().trim();
  }

  @override
  void dispose() {
    _descartado = true;
    unawaited(_authSub?.cancel());
    unawaited(_cancelarAssinaturas());
    super.dispose();
  }
}
