const List<String> _diasSemana = <String>[
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const List<String> _meses = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const List<String> _mesesAbrev = <String>[
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];

String capitalizar(String valor) {
  if (valor.isEmpty) return valor;
  return valor[0].toUpperCase() + valor.substring(1);
}

String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

String formatarData(DateTime data) =>
    '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year}';

String formatarDataCurta(DateTime data) =>
    '${doisDigitos(data.day)} ${_mesesAbrev[data.month - 1]}';

String formatarDataLonga(DateTime data) =>
    '${capitalizar(_diasSemana[data.weekday - 1])}, ${data.day} de ${_meses[data.month - 1]}';

String formatarHora(DateTime data) =>
    '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';

String formatarHoraTexto(String? hora) => hora ?? '--:--';

String formatarIntervalo(DateTime? inicio, DateTime? fim) {
  if (inicio == null) return '--:--';
  if (fim == null) return '${formatarHora(inicio)} — em andamento';
  return '${formatarHora(inicio)} — ${formatarHora(fim)}';
}

String nomeDiaSemana(int diaSemana) {
  if (diaSemana < 1 || diaSemana > 7) return '';
  return capitalizar(_diasSemana[diaSemana - 1]);
}

String iniciais(String nome) {
  final partes = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((parte) => parte.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
  return '${partes.first.substring(0, 1)}${partes.last.substring(0, 1)}'
      .toUpperCase();
}

String normalizarBusca(String valor) {
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const semAcento = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final caractere in valor.toLowerCase().split('')) {
    final indice = comAcento.indexOf(caractere);
    buffer.write(indice >= 0 ? semAcento[indice] : caractere);
  }
  return buffer.toString().trim();
}

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime inicioDoDia(DateTime data) =>
    DateTime(data.year, data.month, data.day);

DateTime fimDoDia(DateTime data) =>
    DateTime(data.year, data.month, data.day, 23, 59, 59, 999);
