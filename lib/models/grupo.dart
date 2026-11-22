import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _data(Object? valor) {
  if (valor == null) return null;
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

String? _texto(Object? valor) {
  if (valor is! String) return null;
  final limpo = valor.trim();
  return limpo.isEmpty ? null : limpo;
}

/// Período habitual da van.
enum PeriodoVan {
  manha('Manhã'),
  tarde('Tarde'),
  noite('Noite'),
  personalizado('Personalizado');

  const PeriodoVan(this.label);

  final String label;

  static PeriodoVan? deTexto(Object? valor) {
    final texto = _texto(valor)?.toLowerCase();
    if (texto == null) return null;
    for (final periodo in values) {
      if (periodo.name == texto ||
          periodo.label.toLowerCase() == texto ||
          (periodo == PeriodoVan.manha && texto == 'matutino') ||
          (periodo == PeriodoVan.noite && texto == 'noturno')) {
        return periodo;
      }
    }
    return null;
  }
}

/// Gera um código de 6 dígitos. [usados] evita colisão com códigos já
/// reservados no mesmo processo; a reserva atômica no Firestore é a garantia
/// definitiva de unicidade entre dispositivos.
String gerarCodigoGrupo({required Set<String> usados, int? seed}) {
  final random = seed == null ? math.Random.secure() : math.Random(seed);
  for (var tentativa = 0; tentativa < 1000; tentativa++) {
    final codigo = (100000 + random.nextInt(900000)).toString();
    if (!usados.contains(codigo)) return codigo;
  }
  throw StateError('Não foi possível gerar um código único.');
}

class GrupoVan {
  const GrupoVan({
    required this.id,
    required this.nome,
    required this.motoristaId,
    required this.codigo,
    this.cidadeOrigem,
    this.cidadeDestino,
    this.periodoEnum,
    this.periodoPersonalizado,
    this.horarioSaida,
    this.observacoes,
    this.criadoEm,
    this.atualizadoEm,
  });

  final String id;
  final String nome;
  final String motoristaId;
  final String codigo;
  final String? cidadeOrigem;
  final String? cidadeDestino;
  final PeriodoVan? periodoEnum;
  final String? periodoPersonalizado;
  final String? horarioSaida;
  final String? observacoes;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  String get trajeto {
    final origem = cidadeOrigem?.trim();
    final destino = cidadeDestino?.trim();
    if (origem != null &&
        origem.isNotEmpty &&
        destino != null &&
        destino.isNotEmpty) {
      return '$origem → $destino';
    }
    if (destino != null && destino.isNotEmpty) return destino;
    if (origem != null && origem.isNotEmpty) return origem;
    return '';
  }

  String get periodo {
    if (periodoEnum == PeriodoVan.personalizado) {
      final personalizado = periodoPersonalizado?.trim();
      return personalizado == null || personalizado.isEmpty
          ? 'Personalizado'
          : personalizado;
    }
    return periodoEnum?.label ?? '';
  }

  String get periodoOuPadrao {
    final valor = periodo;
    return valor.isEmpty ? 'Não informado' : valor;
  }

  GrupoVan copyWith({
    String? nome,
    String? codigo,
    String? cidadeOrigem,
    String? cidadeDestino,
    PeriodoVan? periodoEnum,
    String? periodoPersonalizado,
    String? horarioSaida,
    String? observacoes,
    DateTime? atualizadoEm,
    bool limparOrigem = false,
    bool limparDestino = false,
    bool limparPeriodoPersonalizado = false,
    bool limparHorarioSaida = false,
    bool limparObservacoes = false,
  }) {
    return GrupoVan(
      id: id,
      nome: nome ?? this.nome,
      motoristaId: motoristaId,
      codigo: codigo ?? this.codigo,
      cidadeOrigem: limparOrigem ? null : cidadeOrigem ?? this.cidadeOrigem,
      cidadeDestino: limparDestino ? null : cidadeDestino ?? this.cidadeDestino,
      periodoEnum: periodoEnum ?? this.periodoEnum,
      periodoPersonalizado: limparPeriodoPersonalizado
          ? null
          : periodoPersonalizado ?? this.periodoPersonalizado,
      horarioSaida: limparHorarioSaida
          ? null
          : horarioSaida ?? this.horarioSaida,
      observacoes: limparObservacoes ? null : observacoes ?? this.observacoes,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm ?? DateTime.now(),
    );
  }
}

GrupoVan grupoFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return GrupoVan(
    id: doc.id,
    nome: _texto(data['nome']) ?? 'Sem nome',
    motoristaId: (data['motoristaId'] as String?) ?? '',
    codigo: (data['codigo'] as String?) ?? '',
    cidadeOrigem: _texto(data['cidadeOrigem']),
    cidadeDestino: _texto(data['cidadeDestino']),
    periodoEnum: PeriodoVan.deTexto(data['periodo']),
    periodoPersonalizado: _texto(data['periodoPersonalizado']),
    horarioSaida: _texto(data['horarioSaida']),
    observacoes: _texto(data['observacoes']),
    criadoEm: _data(data['criadoEm']),
    atualizadoEm: _data(data['atualizadoEm']),
  );
}

Map<String, dynamic> grupoToMap({
  required String id,
  required String nome,
  required String motoristaId,
  required String codigo,
  String? cidadeOrigem,
  String? cidadeDestino,
  PeriodoVan? periodoEnum,
  String? periodoPersonalizado,
  String? horarioSaida,
  String? observacoes,
}) {
  final campos = <String, dynamic>{
    'nome': nome.trim(),
    'motoristaId': motoristaId,
    'codigo': codigo,
    'atualizadoEm': FieldValue.serverTimestamp(),
  };

  void definir(String campo, String? valor) {
    final limpo = valor?.trim();
    campos[campo] = limpo == null || limpo.isEmpty ? null : limpo;
  }

  void definirPeriodoPersonalizado() {
    if (periodoEnum == PeriodoVan.personalizado) {
      definir('periodoPersonalizado', periodoPersonalizado);
    } else {
      campos['periodoPersonalizado'] = null;
    }
  }

  definir('cidadeOrigem', cidadeOrigem);
  definir('cidadeDestino', cidadeDestino);
  if (periodoEnum != null) campos['periodo'] = periodoEnum.name;
  definirPeriodoPersonalizado();
  definir('horarioSaida', horarioSaida);
  definir('observacoes', observacoes);
  return campos;
}
