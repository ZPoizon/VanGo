import 'package:flutter_test/flutter_test.dart';

import 'package:vango/core/selecao_grupo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ID da van selecionada permanece disponível entre sessões', () async {
    await SelecaoGrupoStore.salvar('grupo_teste_selecionado');
    final carregado = await SelecaoGrupoStore.carregar();
    expect(carregado, 'grupo_teste_selecionado');

    await SelecaoGrupoStore.salvar(null);
    expect(await SelecaoGrupoStore.carregar(), isNull);
  });
}
