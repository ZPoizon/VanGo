import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:vango/core/profile_photo.dart';
import 'package:vango/core/resultado.dart';
import 'package:vango/core/widgets/profile_photo_sheet.dart';
import 'package:vango/core/widgets/vango_avatar.dart';
import 'package:vango/demo/demo_store.dart';
import 'package:vango/models/usuario.dart';

import 'support/fake_path_provider.dart';

Uint8List _png({int largura = 40, int altura = 40}) => Uint8List.fromList(
  img.encodePng(img.Image(width: largura, height: altura)),
);

XFile _arquivo(String nome, Uint8List bytes) =>
    XFile.fromData(bytes, path: nome, name: nome, mimeType: 'image/png');

Widget _harness({
  required bool possuiFoto,
  required Future<OperacaoResultado> Function({
    required Uint8List bytes,
    required String extensao,
  })
  salvar,
  required Future<OperacaoResultado> Function() remover,
  required Future<XFile?> Function(ImageSource origem) seletor,
  required ValueNotifier<bool> alterou,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            alterou.value = await mostrarEditorFotoPerfil(
              context,
              possuiFoto: possuiFoto,
              salvar: salvar,
              remover: remover,
              seletor: seletor,
            );
          },
          child: const Text('Abrir'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FakePathProvider.instalar);
  tearDownAll(FakePathProvider.remover);

  group('Fase 5A: preparação da foto de perfil', () {
    test('valida formato, tamanho e gera JPEG redimensionado', () async {
      final processada = await ProfilePhoto.preparar(
        _arquivo('foto.png', _png(largura: 2000, altura: 1000)),
      );

      expect(processada.sucesso, isTrue);
      expect(processada.extensao, 'jpg');
      expect(processada.bytes, isNotNull);
      expect(processada.bytes!.length, lessThanOrEqualTo(5 * 1024 * 1024));
      final decodificada = img.decodeImage(processada.bytes!);
      expect(decodificada!.width, 1080);
      expect(decodificada.height, 540);
    });

    test('rejeita extensão fora da lista e arquivo corrompido', () async {
      final invalida = await ProfilePhoto.preparar(
        _arquivo('foto.gif', _png()),
      );
      expect(invalida.sucesso, isFalse);
      expect(invalida.erro, contains('JPG'));

      final corrompida = await ProfilePhoto.preparar(
        _arquivo('foto.png', Uint8List.fromList([1, 2, 3, 4])),
      );
      expect(corrompida.sucesso, isFalse);
      expect(corrompida.erro, contains('Não foi possível ler'));
    });

    test('rejeita arquivo original acima de 15 MB', () async {
      final grande = Uint8List(ProfilePhoto.maxOriginalBytes + 1);
      final resultado = await ProfilePhoto.preparar(
        _arquivo('foto.png', grande),
      );
      expect(resultado.sucesso, isFalse);
      expect(resultado.erro, contains('15 MB'));
    });

    test('copyWith permite limpar fotoUrl', () async {
      final store = DemoStore.demo();
      await store.entrarComo(PerfilUsuario.motorista);
      final usuario = store.usuarioAtual!;
      final comFoto = usuario.copyWith(fotoUrl: 'https://exemplo/foto.jpg');
      expect(comFoto.fotoUrl, isNotNull);
      expect(comFoto.copyWith(limparFotoUrl: true).fotoUrl, isNull);
    });

    testWidgets('avatar do modo demo renderiza foto em data URI', (
      tester,
    ) async {
      final uri = 'data:image/png;base64,${base64Encode(_png())}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VangoAvatar(nome: 'Teste', fotoUrl: uri),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });
  });

  group('Fase 5A: interface de seleção', () {
    testWidgets('mostra prévia, salva e cancela', (tester) async {
      Uint8List? enviado;
      String? extensaoEnviada;
      final alterou = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _harness(
          possuiFoto: false,
          salvar: ({required bytes, required extensao}) async {
            enviado = bytes;
            extensaoEnviada = extensao;
            return const OperacaoResultado.ok('Foto salva.');
          },
          remover: () async => const OperacaoResultado.ok('Foto removida.'),
          seletor: (origem) async => _arquivo('foto.png', _png()),
          alterou: alterou,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher da galeria'), findsOneWidget);

      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();
      expect(find.text('Prévia da nova foto'), findsOneWidget);
      expect(find.text('Salvar foto'), findsOneWidget);

      await tester.tap(find.text('Salvar foto'));
      await tester.pumpAndSettle();

      expect(enviado, isNotNull);
      expect(extensaoEnviada, 'jpg');
      expect(alterou.value, isTrue);
      expect(find.text('Prévia da nova foto'), findsNothing);
    });

    testWidgets('cancelar não altera a foto', (tester) async {
      var chamou = false;
      final alterou = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _harness(
          possuiFoto: true,
          salvar: ({required bytes, required extensao}) async {
            chamou = true;
            return const OperacaoResultado.ok('Foto salva.');
          },
          remover: () async => const OperacaoResultado.ok('Foto removida.'),
          seletor: (origem) async => _arquivo('foto.png', _png()),
          alterou: alterou,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Remover foto'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(chamou, isFalse);
      expect(alterou.value, isFalse);
    });

    testWidgets('remove a foto após confirmação', (tester) async {
      var removeu = false;
      final alterou = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _harness(
          possuiFoto: true,
          salvar: ({required bytes, required extensao}) async =>
              const OperacaoResultado.ok('Foto salva.'),
          remover: () async {
            removeu = true;
            return const OperacaoResultado.ok('Foto removida.');
          },
          seletor: (origem) async => null,
          alterou: alterou,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover foto'));
      await tester.pumpAndSettle();
      expect(find.text('Remover foto?'), findsOneWidget);
      await tester.tap(find.text('Remover').last);
      await tester.pumpAndSettle();

      expect(removeu, isTrue);
      expect(alterou.value, isTrue);
    });

    testWidgets('falha no upload mantém a prévia e não altera a foto', (
      tester,
    ) async {
      final alterou = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        _harness(
          possuiFoto: true,
          salvar: ({required bytes, required extensao}) async {
            return const OperacaoResultado.erro(
              'Não foi possível enviar a foto.',
            );
          },
          remover: () async => const OperacaoResultado.ok('Foto removida.'),
          seletor: (origem) async => _arquivo('foto.png', _png()),
          alterou: alterou,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();
      expect(find.text('Prévia da nova foto'), findsOneWidget);

      await tester.tap(find.text('Salvar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível enviar a foto.'), findsOneWidget);
      expect(find.text('Prévia da nova foto'), findsOneWidget);
      expect(alterou.value, isFalse);
    });
  });
}
