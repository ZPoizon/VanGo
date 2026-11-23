import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/resultado.dart';
import '../core/selecao_grupo_store.dart';
import '../core/store.dart';
import '../models/chamada.dart';
import '../models/grupo.dart';
import '../models/notificacao_entrada.dart';
import '../models/notificacao_resposta.dart';
import '../models/padrao_semanal.dart';
import '../models/presenca.dart';
import '../models/usuario.dart';
import '../models/viagem.dart';
import 'demo_data.dart';

/// Store demonstrativo em memória, usado quando o Firebase não está
/// configurado. Mantém exatamente o mesmo contrato do [FirebaseStore].
class DemoStore extends VanGoStore {
  DemoStore._()
    : _usuarios = DemoData.usuarios(),
      _respostas = DemoData.respostas(),
      _chamada = DemoData.chamadaAmanha(),
      _padrao = DemoData.padraoSemanal().map((k, v) => MapEntry(k, v)),
      _historico = DemoData.historico();

  factory DemoStore.demo() => DemoStore._();

  final List<GrupoVan> _grupos = <GrupoVan>[
    GrupoVan(
      id: DemoData.grupoId,
      nome: 'Van do Roberto (Capão Bonito → Itapetininga)',
      motoristaId: DemoData.motoristaId,
      codigo: '123456',
      cidadeOrigem: 'Capão Bonito',
      cidadeDestino: 'Itapetininga',
      periodoEnum: PeriodoVan.manha,
    ),
  ];

  String? _grupoSelecionadoId;
  final List<Usuario> _solicitacoes = <Usuario>[];

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

  String get _grupoAtivoId {
    final selecionado = grupoSelecionado;
    if (selecionado != null) return selecionado.id;
    final vinculado = _usuarioAtual?.grupoId?.trim();
    if (vinculado != null && vinculado.isNotEmpty) return vinculado;
    return _grupos.isEmpty ? '' : _grupos.first.id;
  }

  /// Estado transitório da van ativa. Ao trocar de van, nada da van anterior
  /// pode continuar visível no painel da nova.
  void _limparEstadoDaVan() {
    _chamada = null;
    _viagemAtual = null;
    _historico.clear();
    _respostas.clear();
    _notificacoesResposta.clear();
    _solicitacoes.clear();
  }

  @override
  List<Usuario> get solicitacoesPendentes => List.unmodifiable(_solicitacoes);

  @override
  bool get modoDemo => true;

  @override
  bool get pronto => true;

  @override
  String? get erro => null;

  @override
  Future<void> inicializar() async {}

  final List<Usuario> _usuarios;
  final Map<String, RespostaPresenca> _respostas;
  final List<NotificacaoResposta> _notificacoesResposta =
      <NotificacaoResposta>[];
  final List<Viagem> _historico;

  Chamada? _chamada;
  Viagem? _viagemAtual;
  Map<int, PadraoSemanalDia> _padrao;
  Usuario? _usuarioAtual;

  String? _conviteToken;
  Turno _conviteTurno = Turno.matutino;

  // ---------------------------------------------------------------- sessão

  @override
  Usuario? get usuarioAtual => _usuarioAtual;
  @override
  bool get autenticado => _usuarioAtual != null;
  @override
  bool get ehMotorista => _usuarioAtual?.perfil == PerfilUsuario.motorista;
  @override
  bool get ehAluno => _usuarioAtual?.perfil == PerfilUsuario.aluno;

  @override
  Usuario? get motorista => _usuarios.firstWhere(
    (u) => u.perfil == PerfilUsuario.motorista,
    orElse: () => _usuarios.first,
  );

  @override
  Future<LoginResultado> entrar({
    required String email,
    required String senha,
  }) async {
    final normalizado = email.trim().toLowerCase();

    if (normalizado.contains('offline')) return LoginResultado.offline;
    if (normalizado.contains('erro')) {
      return LoginResultado.credenciaisInvalidas;
    }
    if (senha.trim().length < 6) return LoginResultado.credenciaisInvalidas;
    if (normalizado.contains('pendente')) return LoginResultado.pendente;
    if (normalizado.contains('bloqueada') ||
        normalizado.contains('desativad')) {
      return LoginResultado.desativado;
    }

    Usuario? encontrado;
    if (normalizado.contains('motorista')) {
      encontrado = motorista;
    } else {
      encontrado = _usuarios.cast<Usuario?>().firstWhere(
        (u) =>
            u!.perfil == PerfilUsuario.aluno &&
            u.email.toLowerCase() == normalizado,
        orElse: () => null,
      );
      encontrado ??= _usuarios.firstWhere(
        (u) => u.id == DemoData.alunoLogadoId,
      );
    }

    if (encontrado == null || !encontrado.ativo) {
      return LoginResultado.desativado;
    }

    _usuarioAtual = encontrado;
    notifyListeners();
    return LoginResultado.sucesso;
  }

  @override
  Future<void> entrarComo(PerfilUsuario perfil) async {
    _usuarioAtual = perfil == PerfilUsuario.motorista
        ? motorista
        : _usuarios.firstWhere((u) => u.id == DemoData.alunoLogadoId);
    notifyListeners();
  }

  @override
  Future<void> sair() async {
    _usuarioAtual = null;
    _grupoSelecionadoId = null;
    unawaited(SelecaoGrupoStore.salvar(null));
    notifyListeners();
  }

  @override
  Future<OperacaoResultado> enviarRecuperacaoSenha(String email) async {
    return const OperacaoResultado.ok(
      'Se o e-mail existir, o link de redefinição será enviado.',
    );
  }

  // ---------------------------------------------------------------- cadastro

  @override
  Future<OperacaoResultado> cadastrarMotorista({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    final normalizado = email.trim().toLowerCase();
    if (_usuarios.any((u) => u.email.toLowerCase() == normalizado)) {
      return const OperacaoResultado.erro(
        'Já existe uma conta com este e-mail.',
      );
    }
    final agora = DateTime.now();
    final motorista = Usuario(
      id: 'motorista-${agora.microsecondsSinceEpoch}',
      nome: nome.trim(),
      email: normalizado,
      perfil: PerfilUsuario.motorista,
      status: StatusConta.ativo,
      ativoFirestore: true,
      telefone: telefone.trim(),
      criadoEm: agora,
    );
    _usuarios.add(motorista);
    _usuarioAtual = motorista;
    notifyListeners();
    return const OperacaoResultado.ok(
      'Conta de motorista criada (demonstração).',
    );
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
    String? cep,
    String? turnoPersonalizado,
  }) async {
    final normalizado = email.trim().toLowerCase();
    if (_usuarios.any((u) => u.email.toLowerCase() == normalizado)) {
      return const OperacaoResultado.erro(
        'Já existe uma conta com este e-mail.',
      );
    }
    final agora = DateTime.now();
    final aluno = Usuario(
      id: 'aluno-${agora.microsecondsSinceEpoch}',
      nome: nome.trim(),
      email: normalizado,
      perfil: PerfilUsuario.aluno,
      status: StatusConta.pendente,
      ativoFirestore: false,
      telefone: telefone.trim(),
      instituicao: instituicao.trim(),
      turno: turno,
      turnoPersonalizado: turnoPersonalizado?.trim(),
      enderecoEmbarque: endereco.trim(),
      cep: cep?.trim().isNotEmpty == true ? cep!.trim() : null,
      criadoEm: agora,
    );
    _usuarios.add(aluno);
    _respostas.putIfAbsent(aluno.id, () => RespostaPresenca(alunoId: aluno.id));
    _usuarioAtual = aluno;
    notifyListeners();
    return const OperacaoResultado.ok(
      'Conta criada! Você já pode acessar seu painel.',
    );
  }

  // ------------------------------------------------------------------ alunos

  @override
  List<Usuario> get alunosAtivos {
    final grupo = _grupoAtivoId;
    final lista = _usuarios
        .where(
          (u) =>
              u.perfil == PerfilUsuario.aluno &&
              u.status == StatusConta.ativo &&
              (grupo.isEmpty || u.grupoId == grupo),
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  List<Usuario> get alunosPendentes {
    final grupo = _grupoAtivoId;
    return _usuarios
        .where(
          (u) =>
              u.perfil == PerfilUsuario.aluno &&
              u.status == StatusConta.pendente &&
              (grupo.isEmpty || u.grupoId == grupo),
        )
        .toList()
      ..sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
  }

  @override
  List<Usuario> alunosDoTurno(Turno turno, {String busca = ''}) {
    final termo = _normalizar(busca);
    final grupo = _grupoAtivoId;
    final lista = _usuarios
        .where(
          (u) =>
              u.perfil == PerfilUsuario.aluno &&
              u.status == StatusConta.ativo &&
              (grupo.isEmpty || u.grupoId == grupo) &&
              u.turno == turno &&
              (termo.isEmpty ||
                  _normalizar(u.nome).contains(termo) ||
                  _normalizar(u.instituicao ?? '').contains(termo)),
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
    final indice = _usuarios.indexWhere((u) => u.id == aluno.id);
    if (indice >= 0) {
      _usuarios[indice] = aluno;
    } else {
      _usuarios.add(aluno);
      _respostas.putIfAbsent(
        aluno.id,
        () => RespostaPresenca(alunoId: aluno.id),
      );
    }
    notifyListeners();
    return const OperacaoResultado.ok('Aluno salvo.');
  }

  @override
  Future<OperacaoResultado> desativarAluno(String id) async {
    final indice = _usuarios.indexWhere((u) => u.id == id);
    if (indice < 0) {
      return const OperacaoResultado.erro('Aluno não encontrado.');
    }
    final atualizado = _usuarios[indice].copyWith(
      status: StatusConta.desativado,
      ativoFirestore: false,
      limparMotivoRecusa: true,
    );
    _usuarios[indice] = atualizado;
    if (_usuarioAtual?.id == id) _usuarioAtual = atualizado;
    notifyListeners();
    return const OperacaoResultado.ok(
      'Aluno desativado. O histórico foi preservado.',
    );
  }

  @override
  Future<OperacaoResultado> aprovarAluno(String id) async {
    final indice = _usuarios.indexWhere(
      (u) =>
          u.id == id &&
          u.perfil == PerfilUsuario.aluno &&
          u.grupoId == _grupoAtivoId &&
          u.status == StatusConta.pendente,
    );
    if (indice < 0) {
      return const OperacaoResultado.erro('Solicitação não encontrada.');
    }
    final atualizado = _usuarios[indice].copyWith(
      status: StatusConta.ativo,
      ativoFirestore: true,
      limparMotivoRecusa: true,
    );
    _usuarios[indice] = atualizado;
    _solicitacoes.removeWhere((aluno) => aluno.id == id);
    if (_usuarioAtual?.id == id) _usuarioAtual = atualizado;
    _respostas.putIfAbsent(id, () => RespostaPresenca(alunoId: id));
    notifyListeners();
    return const OperacaoResultado.ok('Solicitação aprovada.');
  }

  @override
  Future<OperacaoResultado> recusarAluno(String id, {String? motivo}) async {
    final indice = _usuarios.indexWhere(
      (u) =>
          u.id == id &&
          u.perfil == PerfilUsuario.aluno &&
          u.grupoId == _grupoAtivoId &&
          u.status == StatusConta.pendente,
    );
    if (indice < 0) {
      return const OperacaoResultado.erro('Solicitação não encontrada.');
    }
    final motivoLimpo = motivo?.trim();
    final atualizado = _usuarios[indice].copyWith(
      status: StatusConta.recusado,
      ativoFirestore: false,
      motivoRecusa: motivoLimpo?.isNotEmpty == true ? motivoLimpo : null,
      limparMotivoRecusa: motivoLimpo == null || motivoLimpo.isEmpty,
    );
    _usuarios[indice] = atualizado;
    _solicitacoes.removeWhere((aluno) => aluno.id == id);
    if (_usuarioAtual?.id == id) _usuarioAtual = atualizado;
    notifyListeners();
    return const OperacaoResultado.ok('Solicitação recusada.');
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
    if (chamada == null) return true;
    if (!chamada.aberta) return true;
    return _viagemAtual?.status == StatusViagem.emAndamento;
  }

  @override
  List<NotificacaoResposta> get notificacoesResposta =>
      List<NotificacaoResposta>.unmodifiable(_notificacoesResposta);

  // O modo demonstração não participa da Fase 5B: os avisos persistidos e o
  // contador reativo são exclusivos do FirebaseStore/emulador.
  @override
  List<NotificacaoEntrada> get notificacoesEntrada =>
      const <NotificacaoEntrada>[];

  @override
  Map<String, int> get pendentesPorGrupo => <String, int>{
    for (final grupo in meusGrupos) grupo.id: 0,
  };

  @override
  Future<OperacaoResultado> abrirChamada() async {
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Encerre a viagem em andamento antes de abrir uma nova chamada.',
      );
    }
    if (_chamada?.aberta ?? false) {
      return const OperacaoResultado.erro('Já existe uma chamada aberta.');
    }
    final grupoId = _grupoAtivoId;
    if (grupoId.isEmpty) {
      return const OperacaoResultado.erro(
        'Crie uma van antes de abrir uma chamada.',
      );
    }
    _notificacoesResposta.clear();
    final agora = DateTime.now();
    _chamada = Chamada(
      id: 'chamada-${agora.millisecondsSinceEpoch}',
      grupoId: grupoId,
      motoristaId: _usuarioAtual?.id ?? DemoData.motoristaId,
      dataServico: dataAmanha,
      status: StatusChamada.aberta,
      criadaEm: agora,
      abertaEm: agora,
    );
    notifyListeners();
    return const OperacaoResultado.ok('Chamada de amanhã aberta.');
  }

  @override
  Future<OperacaoResultado> encerrarChamada() async {
    final chamada = _chamada;
    if (chamada == null || !chamada.aberta) {
      return const OperacaoResultado.erro(
        'Nenhuma chamada aberta para encerrar.',
      );
    }
    _chamada = chamada.copyWith(
      status: StatusChamada.encerrada,
      encerradaEm: DateTime.now(),
    );
    notifyListeners();
    return const OperacaoResultado.ok(
      'Chamada encerrada. As respostas estão bloqueadas.',
    );
  }

  @override
  Future<OperacaoResultado> cancelarChamada({String? motivo}) async {
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode cancelar a chamada.',
      );
    }
    final chamada = _chamada;
    if (chamada == null) {
      return const OperacaoResultado.erro('Nenhuma chamada para cancelar.');
    }
    if (chamada.status == StatusChamada.cancelada) {
      return const OperacaoResultado.erro('A chamada já foi cancelada.');
    }
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Encerre ou cancele a viagem em andamento antes de cancelar a chamada.',
      );
    }
    _chamada = chamada.copyWith(
      status: StatusChamada.cancelada,
      canceladaEm: DateTime.now(),
      motivoCancelamento: motivo?.trim(),
    );
    notifyListeners();
    return const OperacaoResultado.ok('Chamada cancelada.');
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
    if (!chamada.aberta || respostaBloqueada) {
      return const OperacaoResultado.erro(
        'A chamada foi encerrada ou a viagem já começou. '
        'Não é mais possível alterar a resposta.',
      );
    }
    final anterior = respostaDe(usuario.id);
    final novaIda = ida == null
        ? null
        : (ida ? RespostaSentido.vai : RespostaSentido.naoVai);
    final novaVolta = volta == null
        ? null
        : (volta ? RespostaSentido.vai : RespostaSentido.naoVai);
    final mudouIda = novaIda != null && novaIda != anterior.ida;
    final mudouVolta = novaVolta != null && novaVolta != anterior.volta;

    if (!mudouIda && !mudouVolta) {
      return const OperacaoResultado.ok('Presença já registrada.');
    }

    if (mudouIda && anterior.ida != RespostaSentido.semResposta) {
      _registrarNotificacaoResposta(
        usuario.id,
        usuario.nome,
        SentidoViagem.ida,
        anterior.ida,
        novaIda,
      );
    }
    if (mudouVolta && anterior.volta != RespostaSentido.semResposta) {
      _registrarNotificacaoResposta(
        usuario.id,
        usuario.nome,
        SentidoViagem.volta,
        anterior.volta,
        novaVolta,
      );
    }

    _respostas[usuario.id] = anterior.copyWith(
      ida: mudouIda ? novaIda : null,
      volta: mudouVolta ? novaVolta : null,
      respondidoEm: DateTime.now(),
    );
    notifyListeners();
    return const OperacaoResultado.ok('Presença atualizada.');
  }

  void _registrarNotificacaoResposta(
    String alunoId,
    String alunoNome,
    SentidoViagem sentido,
    RespostaSentido anterior,
    RespostaSentido? atual,
  ) {
    if (atual == null || atual == RespostaSentido.semResposta) return;
    final agora = DateTime.now();
    _notificacoesResposta.insert(
      0,
      NotificacaoResposta(
        id: '${alunoId}_${sentido.name}_${agora.microsecondsSinceEpoch}',
        alunoId: alunoId,
        alunoNome: alunoNome,
        sentido: sentido,
        anterior: anterior,
        atual: atual,
        criadoEm: agora,
      ),
    );
    if (_notificacoesResposta.length > 20) {
      _notificacoesResposta.removeRange(20, _notificacoesResposta.length);
    }
  }

  void _atualizarRespostaDoAluno(
    String alunoId,
    RespostaPresenca Function(RespostaPresenca atual) atualizar,
  ) {
    final atual = respostaDe(alunoId);
    _respostas[alunoId] = atualizar(atual);
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
    if (chamada == null) {
      return const OperacaoResultado.erro(
        'Nenhuma chamada criada para amanhã.',
      );
    }
    if (chamada.status == StatusChamada.cancelada) {
      return const OperacaoResultado.erro(
        'Não é possível iniciar viagem de uma chamada cancelada.',
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

    final viagemRegistradaAnterior = _historico.any(
      (v) =>
          v.chamadaId == chamada.id &&
          v.sentido == sentido &&
          (v.concluida || v.cancelada),
    );
    if (viagemRegistradaAnterior) {
      return OperacaoResultado.erro(
        'A viagem de ${sentido.label.toLowerCase()} desta chamada já foi registrada e não pode ser iniciada novamente.',
      );
    }
    if (sentido == SentidoViagem.volta &&
        !_historico.any(
          (v) =>
              v.chamadaId == chamada.id &&
              v.sentido == SentidoViagem.ida &&
              v.concluida,
        )) {
      return const OperacaoResultado.erro(
        'Conclua a viagem de ida antes de iniciar a volta.',
      );
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

    final agora = DateTime.now();
    _viagemAtual = Viagem(
      id: 'viagem-${sentido.name}-${agora.millisecondsSinceEpoch}',
      chamadaId: chamada.id,
      grupoId: chamada.grupoId,
      dataViagem: chamada.dataServico,
      sentido: sentido,
      status: StatusViagem.emAndamento,
      iniciadaEm: agora,
      confirmacoes: confirmacoes,
    );
    notifyListeners();
    return OperacaoResultado.ok(
      'Viagem de ${sentido.label.toLowerCase()} iniciada com '
      '${confirmacoes.length} aluno(s) confirmado(s).',
    );
  }

  @override
  Future<OperacaoResultado> encerrarViagem() async {
    final viagem = _viagemAtual;
    if (viagem == null || viagem.status != StatusViagem.emAndamento) {
      return const OperacaoResultado.erro('Nenhuma viagem em andamento.');
    }
    final agora = DateTime.now();
    final encerrada = viagem.copyWith(
      status: StatusViagem.encerrada,
      encerradaEm: agora,
    );
    _historico.insert(0, encerrada);
    _viagemAtual = null;

    if (viagem.sentido == SentidoViagem.volta) {
      _chamada = null;
      for (final aluno in alunosAtivos) {
        _respostas[aluno.id] = RespostaPresenca(alunoId: aluno.id);
      }
    }

    notifyListeners();
    return OperacaoResultado.ok(
      viagem.sentido == SentidoViagem.volta
          ? 'Viagem de volta concluída com sucesso. Uma nova chamada já pode ser aberta.'
          : 'Viagem de ida concluída com sucesso. A volta pode ser iniciada.',
    );
  }

  @override
  Future<OperacaoResultado> cancelarViagem({String? motivo}) async {
    if (!ehMotorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode cancelar a viagem.',
      );
    }
    final viagem = _viagemAtual;
    if (viagem == null || viagem.status != StatusViagem.emAndamento) {
      return const OperacaoResultado.erro('Nenhuma viagem em andamento.');
    }
    final cancelada = viagem.copyWith(
      status: StatusViagem.cancelada,
      canceladaEm: DateTime.now(),
      motivoCancelamento: motivo?.trim(),
    );
    _historico.insert(0, cancelada);
    _viagemAtual = null;
    if (viagem.sentido == SentidoViagem.volta) {
      _chamada = null;
      for (final aluno in alunosAtivos) {
        _respostas[aluno.id] = RespostaPresenca(alunoId: aluno.id);
      }
    }
    notifyListeners();
    return const OperacaoResultado.ok('Viagem cancelada.');
  }

  @override
  Future<OperacaoResultado> avisarAlunos(Iterable<String> alunoIds) async {
    final viagem = _viagemAtual;
    if (viagem == null || viagem.status != StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Inicie uma viagem antes de avisar os alunos.',
      );
    }

    final agora = DateTime.now();
    var avisados = 0;
    final confirmacoes = <ConfirmacaoViagem>[];
    for (final confirmacao in viagem.confirmacoes) {
      final selecionado = alunoIds.contains(confirmacao.alunoId);
      if (selecionado && confirmacao.status == RespostaSentido.vai) {
        confirmacoes.add(confirmacao.copyWith(avisadoEm: agora));
        _atualizarRespostaDoAluno(
          confirmacao.alunoId,
          (atual) => atual.copyWith(avisadoEm: agora),
        );
        avisados++;
      } else {
        confirmacoes.add(confirmacao);
      }
    }

    if (avisados == 0) {
      return const OperacaoResultado.erro(
        'Selecione pelo menos um aluno ainda não avisado.',
      );
    }

    _viagemAtual = viagem.copyWith(confirmacoes: confirmacoes);
    notifyListeners();
    return OperacaoResultado.ok(
      'Aviso enviado para $avisados aluno(s) (simulação FCM).',
    );
  }

  @override
  Future<OperacaoResultado> registrarEstouIndo() async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.aluno) {
      return const OperacaoResultado.erro('Entre como aluno para avisar.');
    }
    final agora = DateTime.now();
    _atualizarRespostaDoAluno(
      usuario.id,
      (atual) => atual.copyWith(estouIndo: true, estouIndoEm: agora),
    );

    final viagem = _viagemAtual;
    if (viagem != null) {
      _viagemAtual = viagem.copyWith(
        confirmacoes: viagem.confirmacoes
            .map(
              (c) => c.alunoId == usuario.id
                  ? c.copyWith(estouIndo: true, estouIndoEm: agora)
                  : c,
            )
            .toList(),
      );
    }
    notifyListeners();
    return const OperacaoResultado.ok(
      'O motorista foi avisado que você está indo.',
    );
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
    final agora = DateTime.now();
    _atualizarRespostaDoAluno(
      usuario.id,
      (atual) => atual.copyWith(liberadoEm: agora),
    );

    final viagem = _viagemAtual;
    if (viagem != null) {
      _viagemAtual = viagem.copyWith(
        confirmacoes: viagem.confirmacoes
            .map(
              (c) =>
                  c.alunoId == usuario.id ? c.copyWith(liberadoEm: agora) : c,
            )
            .toList(),
      );
    }
    notifyListeners();
    return const OperacaoResultado.ok(
      'O motorista foi avisado que você está liberado.',
    );
  }

  @override
  Future<OperacaoResultado> cancelarLiberacao() async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }
    _atualizarRespostaDoAluno(
      usuario.id,
      (atual) => atual.copyWith(limparLiberacao: true),
    );
    notifyListeners();
    return const OperacaoResultado.ok('Aviso de liberação cancelado.');
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
    _padrao = Map<int, PadraoSemanalDia>.from(novoPadrao);

    final usuario = _usuarioAtual;
    final chamada = _chamada;
    if (usuario != null &&
        usuario.perfil == PerfilUsuario.aluno &&
        chamada != null &&
        chamada.aberta) {
      final dia = chamada.dataServico.weekday;
      final configuracao = _padrao[dia];
      final resposta = respostaDe(usuario.id);
      if (configuracao != null && resposta.respondidoEm == null) {
        _respostas[usuario.id] = resposta.copyWith(
          ida: configuracao.vaiIda
              ? RespostaSentido.vai
              : RespostaSentido.naoVai,
          volta: configuracao.vaiVolta
              ? RespostaSentido.vai
              : RespostaSentido.naoVai,
          respondidoEm: DateTime.now(),
        );
      }
    }

    notifyListeners();
    return const OperacaoResultado.ok('Padrão semanal salvo.');
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
    _conviteTurno = turno;
    _conviteToken = '${turno.name}-${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();
    return _conviteToken;
  }

  @override
  Future<Turno?> carregarConvite(String token) async {
    _conviteToken = token;
    notifyListeners();
    return _conviteTurno;
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
    String? cep,
    String? turnoPersonalizado,
    String? conviteToken,
  }) async {
    final normalizado = email.trim().toLowerCase();
    if (_usuarios.any((u) => u.email.toLowerCase() == normalizado)) {
      return const OperacaoResultado.erro(
        'Já existe uma conta com este e-mail.',
      );
    }
    final agora = DateTime.now();
    final aluno = Usuario(
      id: 'solicitacao-${agora.millisecondsSinceEpoch}',
      nome: nome.trim(),
      email: normalizado,
      perfil: PerfilUsuario.aluno,
      status: StatusConta.pendente,
      telefone: telefone.trim(),
      instituicao: instituicao,
      turno: turno,
      turnoPersonalizado: turnoPersonalizado?.trim(),
      enderecoEmbarque: endereco.trim(),
      cep: cep?.trim().isNotEmpty == true ? cep!.trim() : null,
      criadoEm: agora,
    );
    _usuarios.add(aluno);
    _respostas.putIfAbsent(aluno.id, () => RespostaPresenca(alunoId: aluno.id));
    notifyListeners();
    return const OperacaoResultado.ok(
      'Solicitação enviada. Aguarde a aprovação do motorista.',
    );
  }

  // ------------------------------------------------------------------ grupos

  @override
  Future<List<GrupoVan>> carregarMeusGrupos() async {
    final motorista = _usuarioAtual;
    final permitidos = motorista == null
        ? _grupos
        : _grupos.where((grupo) => grupo.motoristaId == motorista.id).toList();
    if (permitidos.isEmpty && motorista != null) {
      // Motorista recém-cadastrado: nenhuma van pertence a ele ainda.
      return <GrupoVan>[];
    }
    final preferido = await SelecaoGrupoStore.carregar();

    final escolhido = permitidos.cast<GrupoVan?>().firstWhere(
      (grupo) => grupo?.id == preferido,
      orElse: () => null,
    );
    _grupoSelecionadoId =
        (escolhido ?? (permitidos.isEmpty ? null : permitidos.first))?.id;
    notifyListeners();
    return List.unmodifiable(permitidos);
  }

  @override
  Future<int> contarAlunosGrupo(String grupoId) async {
    return _usuarios
        .where(
          (aluno) =>
              aluno.perfil == PerfilUsuario.aluno &&
              aluno.status == StatusConta.ativo &&
              aluno.grupoId == grupoId,
        )
        .length;
  }

  @override
  Future<int?> contarSolicitacoesGrupo(String grupoId) async {
    final motorista = _usuarioAtual;
    if (motorista == null || motorista.perfil != PerfilUsuario.motorista) {
      return null;
    }
    final grupo = await buscarGrupoPorId(grupoId);
    if (grupo == null || grupo.motoristaId != motorista.id) return null;
    // Não altera _solicitacoes: a contagem de várias vans não pode sobrescrever
    // o snapshot compartilhado usado pelo painel operacional.
    return _usuarios
        .where(
          (aluno) =>
              aluno.perfil == PerfilUsuario.aluno &&
              aluno.status == StatusConta.pendente &&
              aluno.grupoId == grupoId,
        )
        .length;
  }

  @override
  Future<OperacaoResultado> selecionarGrupo(String grupoId) async {
    final permitido = _grupos.any(
      (grupo) => grupo.id == grupoId && grupo.motoristaId == _usuarioAtual?.id,
    );
    if (!permitido) {
      return const OperacaoResultado.erro(
        'Van não encontrada para este usuário.',
      );
    }
    if (_grupoSelecionadoId == grupoId) {
      return const OperacaoResultado.ok('Van já selecionada.');
    }
    _limparEstadoDaVan();
    _grupoSelecionadoId = grupoId;
    await SelecaoGrupoStore.salvar(grupoId);
    notifyListeners();
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
    final motorista = _usuarioAtual;
    if (motorista == null || motorista.perfil != PerfilUsuario.motorista) {
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
    final usados = _grupos.map((g) => g.codigo).toSet();
    final codigo = gerarCodigoGrupo(usados: usados);
    final grupo = GrupoVan(
      id: 'grupo_demo_${codigo}_${_grupos.length + 1}',
      nome: nomeLimpo,
      motoristaId: motorista.id,
      codigo: codigo,
      cidadeOrigem: cidadeOrigem?.trim(),
      cidadeDestino: cidadeDestino?.trim(),
      periodoEnum: periodo,
      periodoPersonalizado: periodoPersonalizado?.trim(),
      horarioSaida: horarioSaida?.trim(),
      observacoes: observacoes?.trim(),
      criadoEm: DateTime.now(),
      atualizadoEm: DateTime.now(),
    );
    _grupos.add(grupo);
    _limparEstadoDaVan();
    _grupoSelecionadoId = grupo.id;
    await SelecaoGrupoStore.salvar(grupo.id);
    notifyListeners();
    return OperacaoResultado.ok(
      'Van “${grupo.nome}” criada. Código: ${grupo.codigo}',
    );
  }

  @override
  Future<GrupoVan?> buscarGrupoPorCodigo(String codigo) async {
    final codigoLimpo = codigo.trim();
    if (codigoLimpo.isEmpty) return null;
    for (final grupo in _grupos) {
      if (grupo.codigo == codigoLimpo) return grupo;
    }
    return null;
  }

  @override
  Future<GrupoVan?> buscarGrupoPorId(String grupoId) async {
    final idLimpo = grupoId.trim();
    if (idLimpo.isEmpty) return null;
    for (final grupo in _grupos) {
      if (grupo.id == idLimpo) return grupo;
    }
    return null;
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

    final grupo = await buscarGrupoPorId(grupoId);
    if (grupo == null) {
      return const OperacaoResultado.erro('Van não encontrada.');
    }

    // Atualiza o aluno para vincular ao grupo (status continua pendente)
    final indice = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (indice >= 0) {
      _usuarios[indice] = _usuarios[indice].copyWith(
        grupoId: grupoId,
        status: StatusConta.pendente,
        ativoFirestore: false,
        limparMotivoRecusa: true,
      );
      _usuarioAtual = _usuarios[indice];
    }
    notifyListeners();

    return const OperacaoResultado.ok(
      'Solicitação enviada! Aguarde a aprovação do motorista.',
    );
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
    final indice = _grupos.indexWhere(
      (grupo) => grupo.id == grupoId && grupo.motoristaId == usuario.id,
    );
    if (indice < 0) {
      return const OperacaoResultado.erro(
        'Você só pode alterar o código das suas próprias vans.',
      );
    }
    if (novoCodigo.trim().length != 6 ||
        int.tryParse(novoCodigo.trim()) == null) {
      return const OperacaoResultado.erro(
        'O código deve ter exatamente 6 dígitos numéricos.',
      );
    }
    if (_grupos.any(
      (grupo) => grupo.codigo == novoCodigo.trim() && grupo.id != grupoId,
    )) {
      return const OperacaoResultado.erro('Este código já está em uso.');
    }

    final anterior = _grupos[indice];
    _grupos[indice] = anterior.copyWith(
      codigo: novoCodigo.trim(),
      atualizadoEm: DateTime.now(),
    );
    notifyListeners();
    return const OperacaoResultado.ok('Código da van atualizado.');
  }

  @override
  Future<OperacaoResultado> gerarNovoCodigoGrupo(String grupoId) async {
    final usuario = _usuarioAtual;
    if (usuario == null || usuario.perfil != PerfilUsuario.motorista) {
      return const OperacaoResultado.erro(
        'Apenas o motorista pode gerar um novo código.',
      );
    }
    final indice = _grupos.indexWhere(
      (grupo) => grupo.id == grupoId && grupo.motoristaId == usuario.id,
    );
    if (indice < 0) {
      return const OperacaoResultado.erro('Van não encontrada.');
    }
    final codigo = gerarCodigoGrupo(
      usados: _grupos.map((g) => g.codigo).toSet(),
    );
    return atualizarCodigoGrupo(grupoId, codigo);
  }

  @override
  Future<List<Usuario>> carregarSolicitacoes(String grupoId) async {
    if (_usuarioAtual?.perfil != PerfilUsuario.motorista) {
      return <Usuario>[];
    }
    final grupo = await buscarGrupoPorId(grupoId);
    if (grupo == null || grupo.motoristaId != _usuarioAtual?.id) {
      return <Usuario>[];
    }
    _solicitacoes
      ..clear()
      ..addAll(
        _usuarios.where(
          (aluno) =>
              aluno.perfil == PerfilUsuario.aluno &&
              aluno.grupoId == grupoId &&
              aluno.status == StatusConta.pendente,
        ),
      );
    notifyListeners();
    return List.unmodifiable(_solicitacoes);
  }

  // ------------------------------------------------------------------ perfil

  @override
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
  }) async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }
    final atualizado = usuario.copyWith(
      nome: nome.trim(),
      telefone: telefone.trim(),
      instituicao: instituicao?.trim(),
      enderecoEmbarque: endereco?.trim(),
      cep: cep?.trim(),
      limparCep: cep != null && cep.trim().isEmpty,
      referenciaEndereco: referencia?.trim(),
      turno: turno,
      turnoPersonalizado: turnoPersonalizado?.trim(),
      limparTurnoPersonalizado: turno != null && turno != Turno.outro,
      fotoUrl: fotoUrl,
    );
    final indice = _usuarios.indexWhere((u) => u.id == usuario.id);
    _usuarios[indice] = atualizado;
    _usuarioAtual = atualizado;
    notifyListeners();
    return const OperacaoResultado.ok('Perfil atualizado.');
  }

  @override
  Future<OperacaoResultado> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    if (senhaAtual.trim().length < 6) {
      return const OperacaoResultado.erro('Informe a senha atual.');
    }
    if (novaSenha.trim().length < 6) {
      return const OperacaoResultado.erro(
        'A nova senha deve ter ao menos 6 caracteres.',
      );
    }
    return const OperacaoResultado.ok(
      'Senha alterada (simulação). Em produção o Firebase Auth exige reautenticação.',
    );
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
    // Modo demo: apenas prévia em memória. Nada é gravado no Firestore.
    final atualizado = usuario.copyWith(
      fotoUrl: 'data:image/jpeg;base64,${base64Encode(bytes)}',
    );
    final indice = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (indice >= 0) _usuarios[indice] = atualizado;
    _usuarioAtual = atualizado;
    notifyListeners();
    return const OperacaoResultado.ok('Foto atualizada (modo demonstração).');
  }

  @override
  Future<OperacaoResultado> removerFotoPerfil() async {
    final usuario = _usuarioAtual;
    if (usuario == null) {
      return const OperacaoResultado.erro('Sessão expirada.');
    }
    final atualizado = usuario.copyWith(limparFotoUrl: true);
    final indice = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (indice >= 0) _usuarios[indice] = atualizado;
    _usuarioAtual = atualizado;
    notifyListeners();
    return const OperacaoResultado.ok('Foto removida.');
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
      presencasChamada.where((p) => p.resposta.respondido).length;

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
}
