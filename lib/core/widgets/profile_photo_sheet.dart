import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/profile_photo.dart';
import '../../core/resultado.dart';
import 'feedback.dart';
import 'vango_button.dart';

typedef SeletorFoto = Future<XFile?> Function(ImageSource origem);
typedef SalvadorFoto =
    Future<OperacaoResultado> Function({
      required Uint8List bytes,
      required String extensao,
    });
typedef RemovedorFoto = Future<OperacaoResultado> Function();

/// Abre o fluxo de foto de perfil: selecionar → prévia → salvar/cancelar.
/// Retorna `true` quando a foto foi salva ou removida com sucesso.
Future<bool> mostrarEditorFotoPerfil(
  BuildContext context, {
  required bool possuiFoto,
  required SalvadorFoto salvar,
  required RemovedorFoto remover,
  SeletorFoto? seletor,
}) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProfilePhotoSheet(
      possuiFoto: possuiFoto,
      salvar: salvar,
      remover: remover,
      seletor: seletor ?? (origem) => ImagePicker().pickImage(source: origem),
    ),
  );
  return resultado ?? false;
}

class _ProfilePhotoSheet extends StatefulWidget {
  const _ProfilePhotoSheet({
    required this.possuiFoto,
    required this.salvar,
    required this.remover,
    required this.seletor,
  });

  final bool possuiFoto;
  final SalvadorFoto salvar;
  final RemovedorFoto remover;
  final SeletorFoto seletor;

  @override
  State<_ProfilePhotoSheet> createState() => _ProfilePhotoSheetState();
}

class _ProfilePhotoSheetState extends State<_ProfilePhotoSheet> {
  Uint8List? _bytes;
  String _extensao = '';
  String? _erro;
  bool _processando = false;
  bool _salvando = false;

  Future<void> _escolher(ImageSource origem) async {
    if (_processando || _salvando) return;
    try {
      final arquivo = await widget.seletor(origem);
      if (arquivo == null || !mounted) return;
      setState(() {
        _processando = true;
        _erro = null;
      });
      final processada = await ProfilePhoto.preparar(arquivo);
      if (!mounted) return;
      setState(() {
        _processando = false;
        if (processada.sucesso) {
          _bytes = processada.bytes;
          _extensao = processada.extensao;
        } else {
          _erro = processada.erro;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erro = 'Não foi possível abrir a imagem. Tente novamente.';
      });
    }
  }

  Future<void> _salvar() async {
    final bytes = _bytes;
    if (bytes == null || _salvando) return;
    setState(() => _salvando = true);
    final resultado = await widget.salvar(
      bytes: bytes,
      extensao: _extensao,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso) Navigator.of(context).pop(true);
  }

  Future<void> _remover() async {
    final confirmou = await confirmarAcao(
      context,
      titulo: 'Remover foto?',
      mensagem: 'Sua foto de perfil será removida para todos os usuários.',
      confirmarLabel: 'Remover',
      destrutivo: true,
      icone: Icons.delete_outline,
    );
    if (!confirmou || !mounted) return;
    setState(() => _salvando = true);
    final resultado = await widget.remover();
    if (!mounted) return;
    setState(() => _salvando = false);
    mostrarResultado(context, resultado);
    if (resultado.sucesso) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final ocupado = _processando || _salvando;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  bytes == null ? 'Foto de perfil' : 'Prévia da nova foto',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (bytes != null)
                  ClipOval(
                    child: Image.memory(
                      bytes,
                      width: 144,
                      height: 144,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 72,
                    color: AppColors.muted,
                  ),
                const SizedBox(height: AppSpacing.md),
                if (bytes == null)
                  const Text(
                    'Escolha uma imagem JPG, PNG ou WebP de até 15 MB. '
                    'Ela será redimensionada antes do envio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  )
                else
                  Text(
                    '${_extensao.toUpperCase()} · pronto para salvar',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                if (_erro != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    label: _erro,
                    child: Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (bytes != null) ...[
                  VangoButton(
                    label: 'Salvar foto',
                    icon: Icons.check_circle_outline,
                    loading: _salvando,
                    onPressed: _salvar,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  VangoButton(
                    label: 'Trocar imagem',
                    icon: Icons.swap_horiz,
                    variant: VangoButtonVariant.outline,
                    onPressed: ocupado ? null : () => _escolher(ImageSource.gallery),
                  ),
                ] else ...[
                  VangoButton(
                    label: 'Escolher da galeria',
                    icon: Icons.photo_library_outlined,
                    loading: _processando,
                    onPressed: () => _escolher(ImageSource.gallery),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: AppSpacing.sm),
                    VangoButton(
                      label: 'Tirar foto',
                      icon: Icons.photo_camera_outlined,
                      onPressed: ocupado ? null : () => _escolher(ImageSource.camera),
                    ),
                  ],
                  if (widget.possuiFoto) ...[
                    const SizedBox(height: AppSpacing.sm),
                    VangoButton(
                      label: 'Remover foto',
                      icon: Icons.delete_outline,
                      variant: VangoButtonVariant.danger,
                      onPressed: ocupado ? null : _remover,
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.sm),
                VangoButton(
                  label: 'Cancelar',
                  variant: VangoButtonVariant.ghost,
                  onPressed: ocupado ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
