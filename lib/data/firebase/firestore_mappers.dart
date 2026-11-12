import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/chamada.dart';
import '../../models/padrao_semanal.dart';
import '../../models/presenca.dart';
import '../../models/usuario.dart';
import '../../models/viagem.dart';

/// Grupo único desta versão (Capão Bonito → Itapetininga).
///
/// Pode ser sobrescrito por perfil/documento no Firestore. O script
/// `tool/seed_firestore.js` cria o grupo com este mesmo ID.
const String kGrupoIdPadrao = 'grupo-capao-itape';

DateTime? _data(Object? valor) {
  if (valor == null) return null;
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

Timestamp? _timestamp(DateTime? valor) =>
    valor == null ? null : Timestamp.fromDate(valor);

T enumDe<T extends Enum>(List<T> valores, Object? nome, T padrao) {
  if (nome is! String) return padrao;
  for (final valor in valores) {
    if (valor.name == nome) return valor;
  }
  return padrao;
}

// ------------------------------------------------------------------- usuário

Usuario usuarioFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Usuario(
    id: doc.id,
    nome: (data['nome'] as String?)?.trim().isNotEmpty == true
        ? data['nome'] as String
        : 'Sem nome',
    email: (data['email'] as String?) ?? '',
    perfil: enumDe(PerfilUsuario.values, data['perfil'], PerfilUsuario.aluno),
    status: enumDe(StatusConta.values, data['status'], StatusConta.pendente),
    telefone: data['telefone'] as String?,
    fotoUrl: data['fotoUrl'] as String?,
    instituicao: data['instituicao'] as String?,
    turno: data['turno'] == null
        ? null
        : enumDe(Turno.values, data['turno'], Turno.matutino),
    enderecoEmbarque: data['enderecoEmbarque'] as String?,
    criadoEm: _data(data['criadoEm']),
  );
}

Map<String, dynamic> usuarioToMap(Usuario usuario, {required String grupoId}) {
  return <String, dynamic>{
    'nome': usuario.nome,
    'email': usuario.email.toLowerCase(),
    'perfil': usuario.perfil.name,
    'status': usuario.status.name,
    'telefone': usuario.telefone,
    'fotoUrl': usuario.fotoUrl,
    'instituicao': usuario.instituicao,
    'turno': usuario.turno?.name,
    'enderecoEmbarque': usuario.enderecoEmbarque,
    'grupoId': grupoId,
    'criadoEm': _timestamp(usuario.criadoEm) ?? FieldValue.serverTimestamp(),
    'atualizadoEm': FieldValue.serverTimestamp(),
  };
}

// ------------------------------------------------------------------- chamada

Chamada chamadaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Chamada(
    id: doc.id,
    grupoId: (data['grupoId'] as String?) ?? kGrupoIdPadrao,
    motoristaId: (data['motoristaId'] as String?) ?? '',
    dataServico: _data(data['dataServico']) ?? DateTime.now(),
    status: enumDe(StatusChamada.values, data['status'], StatusChamada.aberta),
    criadaEm: _data(data['criadaEm']) ?? DateTime.now(),
    abertaEm: _data(data['abertaEm']),
    encerradaEm: _data(data['encerradaEm']),
  );
}

Map<String, dynamic> chamadaToMap({
  required String grupoId,
  required String motoristaId,
  required DateTime dataServico,
  required StatusChamada status,
  DateTime? abertaEm,
  DateTime? encerradaEm,
}) {
  return <String, dynamic>{
    'grupoId': grupoId,
    'motoristaId': motoristaId,
    'dataServico': Timestamp.fromDate(dataServico),
    'status': status.name,
    'criadaEm': FieldValue.serverTimestamp(),
    'abertaEm': _timestamp(abertaEm) ?? FieldValue.serverTimestamp(),
    'encerradaEm': _timestamp(encerradaEm),
  };
}

// ------------------------------------------------------------------ resposta

RespostaPresenca respostaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return RespostaPresenca(
    alunoId: (data['alunoId'] as String?) ?? doc.id,
    ida: enumDe(
      RespostaSentido.values,
      data['ida'],
      RespostaSentido.semResposta,
    ),
    volta: enumDe(
      RespostaSentido.values,
      data['volta'],
      RespostaSentido.semResposta,
    ),
    respondidoEm: _data(data['respondidoEm']),
    estouIndo: (data['estouIndo'] as bool?) ?? false,
    estouIndoEm: _data(data['estouIndoEm']),
    liberadoEm: _data(data['liberadoEm']),
    avisadoEm: _data(data['avisadoEm']),
  );
}

// -------------------------------------------------------------------- viagem

Viagem viagemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final confirmacoes = <ConfirmacaoViagem>[];
  final bruto = data['confirmacoes'];
  if (bruto is List) {
    for (final item in bruto) {
      if (item is! Map) continue;
      final mapa = item.cast<String, dynamic>();
      final alunoId = mapa['alunoId'] as String?;
      if (alunoId == null) continue;
      confirmacoes.add(
        ConfirmacaoViagem(
          alunoId: alunoId,
          status: enumDe(
            RespostaSentido.values,
            mapa['status'],
            RespostaSentido.vai,
          ),
          avisadoEm: _data(mapa['avisadoEm']),
          estouIndo: (mapa['estouIndo'] as bool?) ?? false,
          estouIndoEm: _data(mapa['estouIndoEm']),
          liberadoEm: _data(mapa['liberadoEm']),
        ),
      );
    }
  }

  return Viagem(
    id: doc.id,
    chamadaId: (data['chamadaId'] as String?) ?? '',
    grupoId: (data['grupoId'] as String?) ?? kGrupoIdPadrao,
    dataViagem: _data(data['dataViagem']) ?? DateTime.now(),
    sentido: enumDe(SentidoViagem.values, data['sentido'], SentidoViagem.ida),
    status: enumDe(StatusViagem.values, data['status'], StatusViagem.encerrada),
    iniciadaEm: _data(data['iniciadaEm']),
    encerradaEm: _data(data['encerradaEm']),
    confirmacoes: confirmacoes,
  );
}

Map<String, dynamic> confirmacaoToMap(ConfirmacaoViagem confirmacao) {
  return <String, dynamic>{
    'alunoId': confirmacao.alunoId,
    'status': confirmacao.status.name,
    'avisadoEm': _timestamp(confirmacao.avisadoEm),
    'estouIndo': confirmacao.estouIndo,
    'estouIndoEm': _timestamp(confirmacao.estouIndoEm),
    'liberadoEm': _timestamp(confirmacao.liberadoEm),
  };
}

// ------------------------------------------------------------ padrão semanal

Map<int, PadraoSemanalDia> padraoFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? const <String, dynamic>{};
  final dias = data['dias'];
  if (dias is! Map) return <int, PadraoSemanalDia>{};

  final resultado = <int, PadraoSemanalDia>{};
  for (final entrada in dias.entries) {
    final dia = int.tryParse(entrada.key.toString());
    if (dia == null || entrada.value is! Map) continue;
    final mapa = (entrada.value as Map).cast<String, dynamic>();
    resultado[dia] = PadraoSemanalDia(
      diaSemana: dia,
      vaiIda: (mapa['vaiIda'] as bool?) ?? false,
      vaiVolta: (mapa['vaiVolta'] as bool?) ?? false,
      entraAs: mapa['entraAs'] as String?,
      saiAs: mapa['saiAs'] as String?,
    );
  }
  return resultado;
}

Map<String, dynamic> padraoToMap(
  Map<int, PadraoSemanalDia> padrao, {
  required String grupoId,
}) {
  return <String, dynamic>{
    'grupoId': grupoId,
    'dias': <String, dynamic>{
      for (final entrada in padrao.entries)
        '${entrada.key}': <String, dynamic>{
          'vaiIda': entrada.value.vaiIda,
          'vaiVolta': entrada.value.vaiVolta,
          'entraAs': entrada.value.entraAs,
          'saiAs': entrada.value.saiAs,
        },
    },
    'atualizadoEm': FieldValue.serverTimestamp(),
  };
}
