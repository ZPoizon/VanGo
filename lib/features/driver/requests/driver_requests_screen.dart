import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/app/theme/app_colors.dart';
import 'package:vango/app/theme/app_spacing.dart';
import 'package:vango/core/store_scope.dart';
import 'package:vango/core/widgets/estado_view.dart';
import 'package:vango/core/widgets/vango_app_bar.dart';
import 'package:vango/core/widgets/vango_button.dart';
import 'package:vango/core/widgets/vango_card.dart';
import 'package:vango/models/grupo.dart';

/// Lista de solicitações pendentes das vans administradas pelo motorista.
/// A contagem é feita por van (`grupoId`), sem consultas globais; a aprovação
/// continua no detalhe da van, que já possui o fluxo completo.
class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  List<GrupoVan> _grupos = <GrupoVan>[];
  Map<String, int?> _pendentes = <String, int?>{};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final store = StoreScope.read(context);
    try {
      final grupos = await store.carregarMeusGrupos();
      final pendentes = <String, int?>{};
      for (final grupo in grupos) {
        pendentes[grupo.id] = await store.contarSolicitacoesGrupo(grupo.id);
      }
      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _pendentes = pendentes;
        _erro = store.erro;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as solicitações.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: VangoAppBar(title: 'Solicitações de entrada'),
      body: SafeArea(
        child: _carregando
            ? const CarregandoView(mensagem: 'Carregando solicitações…')
            : _conteudo(),
      ),
    );
  }

  Widget _conteudo() {
    if (_erro != null && _grupos.isEmpty) {
      return EstadoView(
        titulo: 'Não foi possível carregar',
        mensagem: _erro!,
        tipo: EstadoTipo.erro,
        acaoLabel: 'Tentar novamente',
        onAcao: _carregar,
      );
    }

    final comPendencia = _grupos.where((grupo) {
      final valor = _pendentes[grupo.id];
      return valor != null && valor > 0;
    }).toList();
    final indisponiveis = _grupos.where(
      (grupo) => _pendentes[grupo.id] == null,
    );

    if (comPendencia.isEmpty && indisponiveis.isEmpty) {
      return EstadoView(
        titulo: 'Nenhuma solicitação pendente',
        mensagem: _grupos.isEmpty
            ? 'Crie uma van e compartilhe o código para receber solicitações.'
            : 'Você já analisou todas as solicitações das suas vans.',
        onAcao: () => context.go('/driver/vans'),
        acaoLabel: 'Ver minhas vans',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _erro!,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        for (final grupo in comPendencia)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: VangoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grupo.nome,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_pendentes[grupo.id]} solicitações aguardando análise',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  VangoButton(
                    label: 'Administrar solicitações',
                    icon: Icons.how_to_reg_rounded,
                    expand: false,
                    height: 44,
                    onPressed: () async {
                      await context.push('/driver/vans/${grupo.id}');
                      if (mounted) await _carregar();
                    },
                  ),
                ],
              ),
            ),
          ),
        for (final grupo in indisponiveis)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: VangoCard(
              color: AppColors.warningSoft,
              borderColor: AppColors.warning,
              child: Text(
                '${grupo.nome}: total de solicitações indisponível no momento.',
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
          ),
      ],
    );
  }
}
