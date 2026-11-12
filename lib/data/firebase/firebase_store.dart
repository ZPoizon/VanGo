import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/notifications/push_notifications.dart';
import '../../core/resultado.dart';
import '../../core/store.dart';
import '../../models/chamada.dart';
import '../../models/padrao_semanal.dart';
import '../../models/presenca.dart';
import '../../models/usuario.dart';
import '../../models/viagem.dart';
import 'firestore_mappers.dart';

/// Store real: Firebase Auth + Cloud Firestore + Storage + FCM.
///
/// A interface é reativa: listeners do Firestore mantêm o estado local
/// sincronizado e chamam [notifyListeners] para reconstruir a UI.
class FirebaseStore extends VanGoStore {
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _padraoSub;

  List<Usuario> _usuarios = <Usuario>[];
  final Map<String, RespostaPresenca> _respostas = <String, RespostaPresenca>{};
  List<Viagem> _historico = <Viagem>[];
  Chamada? _chamada;
  Viagem? _viagemAtual;
  Map<int, PadraoSemanalDia> _padrao = <int, PadraoSemanalDia>{};
  Usuario? _usuarioAtual;

  String _grupoId = kGrupoIdPadrao;
  String? _uid;
  String? _conviteToken;
  Turno _conviteTurno = Turno.matutino;
  String? _erro;
  bool _pronto = false;
  bool _ignorarAuth = false;
  bool _descartado = false;

  @override
  bool get modoDemo => false;

  @override
  bool get pronto => _pronto;

  @override
  String? get erro => _erro;

  String get _grupoAtual => _grupoId;

  @override
  Future<void> inicializar() async {
    if (_pronto) return;

    await PushNotifications.instance.inicializar();

    _authSub = _auth.authStateChanges().listen((user) {
      if (_ignorarAuth) return;
      unawaited(_aplicarSessao(user));
    });

    await _aplicarSessao(_auth.currentUser);
    _pronto = true;
    _notificar();
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
    try {
      final credencial = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      final user = credencial.user;
      if (user == null) return LoginResultado.credenciaisInvalidas;

      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        return LoginResultado.semPerfil;
      }

      final perfil = usuarioFromDoc(doc);
      if (perfil.status == StatusConta.pendente) {
        await _auth.signOut();
        return LoginResultado.pendente;
      }
      if (!perfil.ativo) {
        await _auth.signOut();
        return LoginResultado.desativado;
      }

      await _aplicarSessao(user);
      return LoginResultado.sucesso;
    } on FirebaseAuthException catch (error) {
      debugPrint('[Auth] ${error.code}: ${error.message}');
      return _mapearErroAuth(error);
    } catch (error) {
      debugPrint('[Auth] falha no login: $error');
      return LoginResultado.offline;
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
      if (error.code == 'network-request-failed') {
        return const OperacaoResultado.erro(
          'Sem conexão. Verifique sua internet e tente novamente.',
        );
      }
      return const OperacaoResultado.ok(
        'Se o e-mail existir, enviaremos um link para redefinir a senha.',
      );
    }
  }

  Future<void> _aplicarSessao(User? user) async {
    if (user == null) {
      await _limparSessao();
      return;
    }

    if (_uid == user.uid && _subs.isNotEmpty) return;
    _uid = user.uid;

    try {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      if (!doc.exists) {
        _erro = 'Perfil não encontrado. Use o convite do motorista.';
        await _auth.signOut();
        return;
      }

      final perfil = usuarioFromDoc(doc);
      if (!perfil.ativo) {
        _erro = perfil.status == StatusConta.pendente
            ? 'Sua solicitação ainda está pendente de aprovação.'
            : 'Esta conta está desativada.';
        await _auth.signOut();
        return;
      }

      _usuarioAtual = perfil;
      _grupoId = (doc.data()?['grupoId'] as String?) ?? kGrupoIdPadrao;
      await _assinarDados();
      await PushNotifications.instance.registrarDispositivo(
        uid: user.uid,
        grupoId: _grupoId,
      );
      _erro = null;
      _notificar();
    } catch (error) {
      debugPrint('[Firestore] falha ao carregar sessão: $error');
      _erro = 'Não foi possível carregar os dados. Verifique sua conexão.';
      _notificar();
    }
  }

  Future<void> _limparSessao() async {
    await _cancelarAssinaturas();
    _uid = null;
    _usuarioAtual = null;
    _usuarios = <Usuario>[];
    _respostas.clear();
    _chamada = null;
    _viagemAtual = null;
    _historico = <Viagem>[];
    _padrao = <int, PadraoSemanalDia>{};
    _conviteToken = null;
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
      case 'too-many-requests':
        return LoginResultado.credenciaisInvalidas;
      default:
        return LoginResultado.credenciaisInvalidas;
    }
  }

  // --------------------------------------------------------------- listeners

  Future<void> _assinarDados() async {
    await _cancelarAssinaturas();
    final grupo = _grupoAtual;

    _subs.add(
      _db
          .collection('usuarios')
          .where('grupoId', isEqualTo: grupo)
          .snapshots()
          .listen(_aoAtualizarUsuarios, onError: _aoFalharStream),
    );

    _subs.add(
      _db
          .collection('chamadas')
          .where('grupoId', isEqualTo: grupo)
          .orderBy('dataServico', descending: true)
          .limit(1)
          .snapshots()
          .listen(_aoAtualizarChamada, onError: _aoFalharStream),
    );

    _subs.add(
      _db
          .collection('viagens')
          .where('grupoId', isEqualTo: grupo)
          .orderBy('dataViagem', descending: true)
          .limit(30)
          .snapshots()
          .listen(_aoAtualizarViagens, onError: _aoFalharStream),
    );

    if (_usuarioAtual?.perfil == PerfilUsuario.aluno) {
      _assinarPadrao(_usuarioAtual!.id);
    }
  }

  void _aoAtualizarUsuarios(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _usuarios = snapshot.docs.map(usuarioFromDoc).toList();
    final atual = _usuarioAtual;
    if (atual != null) {
      for (final usuario in _usuarios) {
        if (usuario.id == atual.id) {
          _usuarioAtual = usuario;
          if (!usuario.ativo) unawaited(_auth.signOut());
          break;
        }
      }
    }
    _notificar();
  }

  void _aoAtualizarChamada(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final anterior = _chamada?.id;
    _chamada = snapshot.docs.isEmpty
        ? null
        : chamadaFromDoc(snapshot.docs.first);
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

    _respostasSub = _db
        .collection('respostas')
        .where('chamadaId', isEqualTo: chamada.id)
        .snapshots()
        .listen((snapshot) {
          _respostas
            ..clear()
            ..addEntries(
              snapshot.docs.map((doc) {
                final resposta = respostaFromDoc(doc);
                return MapEntry(resposta.alunoId, resposta);
              }),
            );
          _notificar();
        }, onError: _aoFalharStream);
  }

  void _assinarPadrao(String uid) {
    unawaited(_padraoSub?.cancel());
    _padraoSub = _db.collection('padroes').doc(uid).snapshots().listen((doc) {
      _padrao = padraoFromDoc(doc);
      _notificar();
    }, onError: _aoFalharStream);
  }

  void _aoFalharStream(Object error) {
    debugPrint('[Firestore] erro em listener: $error');
    _erro = 'Falha de sincronização. Verifique sua conexão.';
    _notificar();
  }

  Future<void> _cancelarAssinaturas() async {
    for (final assinatura in _subs) {
      await assinatura.cancel();
    }
    _subs.clear();
    await _respostasSub?.cancel();
    _respostasSub = null;
    await _padraoSub?.cancel();
    _padraoSub = null;
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
              usuario.perfil == PerfilUsuario.aluno &&
              usuario.status == StatusConta.ativo,
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
              usuario.status == StatusConta.ativo &&
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
  Future<OperacaoResultado> recusarAluno(String id) =>
      _alterarStatusAluno(id, StatusConta.recusado);

  Future<OperacaoResultado> _alterarStatusAluno(
    String id,
    StatusConta status,
  ) async {
    try {
      await _db.collection('usuarios').doc(id).set(<String, dynamic>{
        'status': status.name,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

  @override
  bool get respostaBloqueada {
    final chamada = _chamada;
    if (chamada == null || !chamada.aberta) return true;
    return _viagemAtual?.status == StatusViagem.emAndamento;
  }

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
          grupoId: _grupoAtual,
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
  Future<OperacaoResultado> responderChamada({
    required bool ida,
    required bool volta,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro('Entre como aluno para responder.');
    }
    final chamada = _chamada;
    if (chamada == null) {
      return const OperacaoResultado.erro('Nenhuma chamada aberta.');
    }
    if (!chamada.aberta) {
      return const OperacaoResultado.erro(
        'A chamada já foi encerrada. Não é mais possível alterar a resposta.',
      );
    }

    try {
      await _respostaRef(chamada.id, usuario.id).set(<String, dynamic>{
        'chamadaId': chamada.id,
        'alunoId': usuario.id,
        'grupoId': _grupoAtual,
        'ida': ida ? RespostaSentido.vai.name : RespostaSentido.naoVai.name,
        'volta': volta ? RespostaSentido.vai.name : RespostaSentido.naoVai.name,
        'respondidoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _respostas[usuario.id] = respostaDe(usuario.id).copyWith(
        ida: ida ? RespostaSentido.vai : RespostaSentido.naoVai,
        volta: volta ? RespostaSentido.vai : RespostaSentido.naoVai,
        respondidoEm: DateTime.now(),
      );
      _notificar();
      return const OperacaoResultado.ok('Presença atualizada.');
    } catch (error) {
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
      await referencia.set(<String, dynamic>{
        'chamadaId': chamada.id,
        'grupoId': _grupoAtual,
        'dataViagem': Timestamp.fromDate(chamada.dataServico),
        'sentido': sentido.name,
        'status': StatusViagem.emAndamento.name,
        'iniciadaEm': FieldValue.serverTimestamp(),
        'confirmacoes': confirmacoes.map(confirmacaoToMap).toList(),
      });

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
        final respostas = await _db
            .collection('respostas')
            .where('chamadaId', isEqualTo: viagem.chamadaId)
            .get();
        final lote = _db.batch();
        for (final resposta in respostas.docs) {
          lote.delete(resposta.reference);
        }
        lote.delete(_db.collection('chamadas').doc(viagem.chamadaId));
        await lote.commit();
        _chamada = null;
        _viagemAtual = null;
        _respostas.clear();
        _notificar();
        return const OperacaoResultado.ok(
          'Viagem de volta encerrada. Uma nova chamada já pode ser aberta.',
        );
      }

      return const OperacaoResultado.ok(
        'Viagem de ida encerrada. A volta pode ser iniciada.',
      );
    } catch (error) {
      return _erroOperacao('encerrar a viagem', error);
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
      for (final alunoId in selecionados) {
        lote.set(_respostaRef(viagem.chamadaId, alunoId), <String, dynamic>{
          'avisadoEm': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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

    try {
      await _respostaRef(chamada.id, usuario.id).set(<String, dynamic>{
        'estouIndo': true,
        'estouIndoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      await _respostaRef(chamada.id, usuario.id).set(<String, dynamic>{
        'liberadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    final chamada = _chamada;
    if (usuario == null || chamada == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }

    try {
      await _respostaRef(chamada.id, usuario.id).set(<String, dynamic>{
        'liberadoEm': FieldValue.delete(),
      }, SetOptions(merge: true));
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
        if (configuracao != null && !resposta.respondido) {
          await _respostaRef(chamada.id, usuario.id).set(<String, dynamic>{
            'chamadaId': chamada.id,
            'alunoId': usuario.id,
            'grupoId': _grupoAtual,
            'ida': configuracao.vaiIda
                ? RespostaSentido.vai.name
                : RespostaSentido.naoVai.name,
            'volta': configuracao.vaiVolta
                ? RespostaSentido.vai.name
                : RespostaSentido.naoVai.name,
            'respondidoEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      _padrao = Map<int, PadraoSemanalDia>.from(novoPadrao);
      _notificar();
      return const OperacaoResultado.ok('Padrão semanal salvo.');
    } catch (error) {
      return _erroOperacao('salvar o padrão semanal', error);
    }
  }

  // ------------------------------------------------------------------ convite

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

    final token = '${turno.name}-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _db.collection('convites').doc(token).set(<String, dynamic>{
        'grupoId': _grupoAtual,
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
      debugPrint('[Firestore] falha ao carregar convite: $error');
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
    if (conviteToken == null || conviteToken.isEmpty) {
      return const OperacaoResultado.erro(
        'Convite inválido. Solicite um novo link ao motorista.',
      );
    }

    _ignorarAuth = true;
    User? criado;
    try {
      final convite = await _db.collection('convites').doc(conviteToken).get();
      if (!convite.exists) {
        return const OperacaoResultado.erro(
          'Convite inválido ou expirado. Solicite um novo link ao motorista.',
        );
      }
      final dadosConvite = convite.data() ?? const <String, dynamic>{};
      final grupoId = (dadosConvite['grupoId'] as String?) ?? kGrupoIdPadrao;
      final turnoConvite = enumDe(Turno.values, dadosConvite['turno'], turno);

      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: senha.trim(),
      );
      criado = credencial.user;

      final aluno = Usuario(
        id: criado!.uid,
        nome: nome.trim(),
        email: email.trim().toLowerCase(),
        perfil: PerfilUsuario.aluno,
        status: StatusConta.pendente,
        telefone: telefone.trim(),
        instituicao: instituicao,
        turno: turnoConvite,
        enderecoEmbarque: endereco.trim(),
        criadoEm: DateTime.now(),
      );

      await _db
          .collection('usuarios')
          .doc(criado.uid)
          .set(usuarioToMap(aluno, grupoId: grupoId));

      await _auth.signOut();
      return const OperacaoResultado.ok(
        'Solicitação enviada. Aguarde a aprovação do motorista.',
      );
    } on FirebaseAuthException catch (error) {
      if (criado != null) {
        try {
          await criado.delete();
        } catch (_) {}
      }
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
          'Sem conexão. Verifique sua internet e tente novamente.',
        );
      }
      return const OperacaoResultado.erro(
        'Não foi possível criar a conta. Tente novamente.',
      );
    } catch (error) {
      if (criado != null) {
        try {
          await criado.delete();
        } catch (_) {}
      }
      return _erroOperacao('enviar a solicitação', error);
    } finally {
      _ignorarAuth = false;
    }
  }

  // ------------------------------------------------------------------ perfil

  @override
  Future<OperacaoResultado> atualizarPerfil({
    required String nome,
    required String telefone,
    String? instituicao,
    String? endereco,
    String? fotoUrl,
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }

    try {
      await _db.collection('usuarios').doc(usuario.id).set(<String, dynamic>{
        'nome': nome.trim(),
        'telefone': telefone.trim(),
        'instituicao': instituicao,
        'enderecoEmbarque': endereco,
        'fotoUrl': fotoUrl ?? usuario.fotoUrl,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _usuarioAtual = usuario.copyWith(
        nome: nome.trim(),
        telefone: telefone.trim(),
        instituicao: instituicao,
        enderecoEmbarque: endereco,
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
        'grupoId': _grupoAtual,
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

  OperacaoResultado _erroOperacao(String acao, Object error) {
    debugPrint('[Firestore] falha ao $acao: $error');
    return OperacaoResultado.erro(
      'Não foi possível $acao. Verifique sua conexão e tente novamente.',
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
