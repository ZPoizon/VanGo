import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Limites compartilhados entre cliente e Storage Rules.
///
/// O limite final de 5 MB é o mesmo aplicado nas regras do Storage; o limite
/// do arquivo original existe para evitar decodificar imagens absurdamente
/// grandes antes do redimensionamento.
abstract final class ProfilePhoto {
  static const int maxOriginalBytes = 15 * 1024 * 1024;
  static const int maxUploadBytes = 5 * 1024 * 1024;
  static const int maxDimension = 1080;
  static const Set<String> formatosPermitidos = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Extensão normalizada a partir do nome/mimeType escolhido no dispositivo.
  static String? extensaoDe(XFile arquivo) {
    final nome = arquivo.name.toLowerCase();
    final ponto = nome.lastIndexOf('.');
    if (ponto >= 0) {
      final ext = nome.substring(ponto + 1);
      // Extensão explícita e inválida não é ignorada em favor do mimeType:
      // isso impediria burlar a validação renomeando um arquivo qualquer.
      return formatosPermitidos.contains(ext) ? ext : null;
    }
    final mime = (arquivo.mimeType ?? '').toLowerCase();
    final mapa = <String, String>{
      'image/jpeg': 'jpg',
      'image/jpg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
    };
    return mapa[mime];
  }

  /// Valida, redimensiona e comprime a imagem escolhida.
  ///
  /// Sempre devolve JPEG: o avatar é uma foto circular, sem transparência, e
  /// assim o payload enviado ao Storage fica previsível e abaixo do limite.
  static Future<ProfilePhotoProcessada> preparar(XFile arquivo) async {
    final extensao = extensaoDe(arquivo);
    if (extensao == null) {
      return const ProfilePhotoProcessada.erro(
        'Use uma imagem JPG, PNG ou WebP.',
      );
    }

    final bytes = await arquivo.readAsBytes();
    if (bytes.isEmpty) {
      return const ProfilePhotoProcessada.erro('Arquivo de imagem vazio.');
    }
    if (bytes.length > maxOriginalBytes) {
      return const ProfilePhotoProcessada.erro(
        'Imagem muito grande. Escolha um arquivo de até 15 MB.',
      );
    }

    img.Image? decodificada;
    try {
      decodificada = img.decodeImage(bytes);
    } catch (_) {
      decodificada = null;
    }
    if (decodificada == null) {
      return const ProfilePhotoProcessada.erro(
        'Não foi possível ler a imagem. Tente outro arquivo.',
      );
    }

    var imagem = decodificada;
    final maiorLado = decodificada.width > decodificada.height
        ? decodificada.width
        : decodificada.height;
    if (maiorLado > maxDimension) {
      final fator = maxDimension / maiorLado;
      imagem = img.copyResize(
        decodificada,
        width: (decodificada.width * fator).round().clamp(1, maxDimension),
        height: (decodificada.height * fator).round().clamp(1, maxDimension),
      );
    }

    // Reduz a qualidade aos poucos apenas quando o JPEG ainda ultrapassa o
    // limite aceito pelas regras do Storage.
    var qualidade = 85;
    List<int> processada = img.encodeJpg(imagem, quality: qualidade);
    while (processada.length > maxUploadBytes && qualidade > 45) {
      qualidade -= 10;
      processada = img.encodeJpg(imagem, quality: qualidade);
    }
    if (processada.length > maxUploadBytes) {
      return const ProfilePhotoProcessada.erro(
        'Não foi possível reduzir a imagem ao tamanho permitido (5 MB).',
      );
    }

    return ProfilePhotoProcessada(
      bytes: Uint8List.fromList(processada),
      extensao: 'jpg',
    );
  }
}

class ProfilePhotoProcessada {
  const ProfilePhotoProcessada({
    required this.bytes,
    required this.extensao,
    this.erro,
  });

  const ProfilePhotoProcessada.erro(String mensagem)
    : bytes = null,
      extensao = '',
      erro = mensagem;

  final Uint8List? bytes;
  final String extensao;
  final String? erro;

  bool get sucesso => erro == null && bytes != null;
}
