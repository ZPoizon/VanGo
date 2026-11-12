class PadraoSemanalDia {
  const PadraoSemanalDia({
    required this.diaSemana,
    this.vaiIda = false,
    this.vaiVolta = false,
    this.entraAs,
    this.saiAs,
  });

  final int diaSemana; // DateTime.monday (1) .. sunday (7)
  final bool vaiIda;
  final bool vaiVolta;
  final String? entraAs;
  final String? saiAs;

  PadraoSemanalDia copyWith({
    bool? vaiIda,
    bool? vaiVolta,
    String? entraAs,
    String? saiAs,
    bool limparEntrada = false,
    bool limparSaida = false,
  }) {
    return PadraoSemanalDia(
      diaSemana: diaSemana,
      vaiIda: vaiIda ?? this.vaiIda,
      vaiVolta: vaiVolta ?? this.vaiVolta,
      entraAs: limparEntrada ? null : (entraAs ?? this.entraAs),
      saiAs: limparSaida ? null : (saiAs ?? this.saiAs),
    );
  }
}
