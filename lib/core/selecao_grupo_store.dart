import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persiste somente o ID da van selecionada. Não é uma base de dados e não
/// duplica dados do Firestore: é apenas a preferência local da última van usada.
abstract final class SelecaoGrupoStore {
  static String? _memoria;
  static bool _carregado = false;

  static Future<File> _arquivo() async {
    final diretorio = await getApplicationSupportDirectory();
    return File('${diretorio.path}/vango_grupo_selecionado.txt');
  }

  static Future<String?> carregar() async {
    if (_carregado) return _memoria;
    _carregado = true;
    if (kIsWeb) return _memoria;
    try {
      final arquivo = await _arquivo();
      if (await arquivo.exists()) {
        final texto = (await arquivo.readAsString()).trim();
        if (texto.isNotEmpty) _memoria = texto;
      }
    } catch (error) {
      debugPrint('[SelecaoGrupoStore] falha ao carregar: $error');
    }
    return _memoria;
  }

  static Future<void> salvar(String? grupoId) async {
    final limpo = grupoId?.trim();
    _memoria = limpo == null || limpo.isEmpty ? null : limpo;
    _carregado = true;
    if (kIsWeb) return;
    try {
      final arquivo = await _arquivo();
      if (_memoria == null) {
        if (await arquivo.exists()) await arquivo.delete();
      } else {
        await arquivo.writeAsString(_memoria!);
      }
    } catch (error) {
      debugPrint('[SelecaoGrupoStore] falha ao salvar: $error');
    }
  }
}
