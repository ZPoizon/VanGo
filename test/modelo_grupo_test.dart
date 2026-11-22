import 'package:flutter_test/flutter_test.dart';

import 'package:vango/models/grupo.dart';

void main() {
  test('grupo legado é lido sem campos novos', () {
    final grupo = GrupoVan(
      id: 'grupo-antigo',
      nome: 'Van antiga',
      motoristaId: 'motorista-1',
      codigo: '123456',
    );

    expect(grupo.trajeto, '');
    expect(grupo.periodo, '');
    expect(grupo.horarioSaida ?? '', '');
    expect(grupo.observacoes ?? '', '');
    expect(grupo.periodoOuPadrao, 'Não informado');
  });

  test('grupo novo normaliza trajeto e campos opcionais', () {
    final grupo = GrupoVan(
      id: 'g1',
      nome: 'Van A',
      motoristaId: 'm1',
      codigo: '123456',
      cidadeOrigem: 'Capão Bonito',
      cidadeDestino: 'Itapetininga',
      periodoEnum: PeriodoVan.tarde,
      horarioSaida: '14:30',
      observacoes: 'Portão azul',
    );

    expect(grupo.cidadeOrigem, 'Capão Bonito');
    expect(grupo.cidadeDestino, 'Itapetininga');
    expect(grupo.trajeto, 'Capão Bonito → Itapetininga');
    expect(grupo.periodo, 'Tarde');
    expect(grupo.horarioSaida?.trim(), '14:30');
    expect(grupo.observacoes?.trim(), 'Portão azul');
  });

  test('gerador de códigos gera 6 dígitos e nunca repete em lote', () {
    final codigos = <String>{};
    for (var i = 0; i < 1000; i++) {
      final codigo = gerarCodigoGrupo(usados: codigos, seed: i + 1);
      expect(codigo.length, 6);
      expect(int.tryParse(codigo), isNotNull);
      codigos.add(codigo);
    }
    expect(codigos.length, 1000);
  });
}
