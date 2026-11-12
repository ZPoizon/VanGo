import 'dart:typed_data';

import '../core/resultado.dart';
import '../core/store.dart';
import '../models/chamada.dart';
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
    notifyListeners();
  }

  @override
  Future<OperacaoResultado> enviarRecuperacaoSenha(String email) async {
    return const OperacaoResultado.ok(
      'Se o e-mail existir, o link de redefinição será enviado.',
    );
  }

  // ------------------------------------------------------------------ alunos

  @override
  List<Usuario> get alunosAtivos {
    final lista = _usuarios
        .where(
          (u) =>
              u.perfil == PerfilUsuario.aluno && u.status == StatusConta.ativo,
        )
        .toList();
    lista.sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));
    return lista;
  }

  @override
  List<Usuario> get alunosPendentes =>
      _usuarios
          .where(
            (u) =>
                u.perfil == PerfilUsuario.aluno &&
                u.status == StatusConta.pendente,
          )
          .toList()
        ..sort((a, b) => _normalizar(a.nome).compareTo(_normalizar(b.nome)));

  @override
  List<Usuario> alunosDoTurno(Turno turno, {String busca = ''}) {
    final termo = _normalizar(busca);
    final lista = _usuarios
        .where(
          (u) =>
              u.perfil == PerfilUsuario.aluno &&
              u.status == StatusConta.ativo &&
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
    _usuarios[indice] = _usuarios[indice].copyWith(
      status: StatusConta.desativado,
    );
    notifyListeners();
    return const OperacaoResultado.ok(
      'Aluno desativado. O histórico foi preservado.',
    );
  }

  @override
  Future<OperacaoResultado> aprovarAluno(String id) async {
    final indice = _usuarios.indexWhere((u) => u.id == id);
    if (indice < 0) {
      return const OperacaoResultado.erro('Solicitação não encontrada.');
    }
    _usuarios[indice] = _usuarios[indice].copyWith(status: StatusConta.ativo);
    _respostas.putIfAbsent(id, () => RespostaPresenca(alunoId: id));
    notifyListeners();
    return const OperacaoResultado.ok('Solicitação aprovada.');
  }

  @override
  Future<OperacaoResultado> recusarAluno(String id) async {
    final indice = _usuarios.indexWhere((u) => u.id == id);
    if (indice < 0) {
      return const OperacaoResultado.erro('Solicitação não encontrada.');
    }
    _usuarios[indice] = _usuarios[indice].copyWith(
      status: StatusConta.recusado,
    );
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
  Future<OperacaoResultado> abrirChamada() async {
    if (_viagemAtual?.status == StatusViagem.emAndamento) {
      return const OperacaoResultado.erro(
        'Encerre a viagem em andamento antes de abrir uma nova chamada.',
      );
    }
    if (_chamada?.aberta ?? false) {
      return const OperacaoResultado.erro('Já existe uma chamada aberta.');
    }
    final agora = DateTime.now();
    _chamada = Chamada(
      id: 'chamada-${agora.millisecondsSinceEpoch}',
      grupoId: DemoData.grupoId,
      motoristaId: DemoData.motoristaId,
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
    final atual = respostaDe(usuario.id);
    _respostas[usuario.id] = atual.copyWith(
      ida: ida ? RespostaSentido.vai : RespostaSentido.naoVai,
      volta: volta ? RespostaSentido.vai : RespostaSentido.naoVai,
      respondidoEm: DateTime.now(),
    );
    notifyListeners();
    return const OperacaoResultado.ok('Presença atualizada.');
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
          ? 'Viagem de volta encerrada. Uma nova chamada já pode ser aberta.'
          : 'Viagem de ida encerrada. A volta pode ser iniciada.',
    );
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
      enderecoEmbarque: endereco.trim(),
      criadoEm: agora,
    );
    _usuarios.add(aluno);
    _respostas.putIfAbsent(aluno.id, () => RespostaPresenca(alunoId: aluno.id));
    notifyListeners();
    return const OperacaoResultado.ok(
      'Solicitação enviada. Aguarde a aprovação do motorista.',
    );
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
    final atualizado = usuario.copyWith(
      nome: nome.trim(),
      telefone: telefone.trim(),
      instituicao: instituicao,
      enderecoEmbarque: endereco,
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
    return const OperacaoResultado.ok(
      'Foto atualizada (simulação). No Firebase a imagem vai para o Storage.',
    );
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
