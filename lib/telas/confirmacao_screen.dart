import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/botao_primario.dart';

class ConfirmacaoScreen extends StatefulWidget {
  final bool idaInicial;
  final bool voltaInicial;

  const ConfirmacaoScreen({
    super.key,
    this.idaInicial = true,
    this.voltaInicial = true,
  });

  @override
  State<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends State<ConfirmacaoScreen> {
  late bool _ida;
  late bool _volta;

  @override
  void initState() {
    super.initState();
    _ida = widget.idaInicial;
    _volta = widget.voltaInicial;
  }

  void _salvar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presença atualizada com sucesso!'),
        backgroundColor: AppTheme.primaryDark,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context, {'ida': _ida, 'volta': _volta});
  }

  Widget _buildOpcaoCard({
    required String titulo,
    required String horario,
    required bool selecao,
    required ValueChanged<bool> onSelect,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  horario,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selecao ? AppTheme.badgeIdaEVoltaBg : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selecao ? AppTheme.badgeIdaEVoltaText : AppTheme.borderLight,
                          width: selecao ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: selecao ? AppTheme.badgeIdaEVoltaText : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vou',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selecao ? AppTheme.badgeIdaEVoltaText : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !selecao ? AppTheme.badgeNaoVaiBg : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !selecao ? AppTheme.badgeNaoVaiText : AppTheme.borderLight,
                          width: !selecao ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            size: 20,
                            color: !selecao ? AppTheme.badgeNaoVaiText : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Não vou',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: !selecao ? AppTheme.badgeNaoVaiText : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Minha presença'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confirme sua presença na van para hoje (18/06):',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Seção Ida
              _buildOpcaoCard(
                titulo: 'Seção Ida',
                horario: 'Embarque 06:30',
                selecao: _ida,
                onSelect: (val) {
                  setState(() {
                    _ida = val;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Seção Volta
              _buildOpcaoCard(
                titulo: 'Seção Volta',
                horario: 'Saída 22:10',
                selecao: _volta,
                onSelect: (val) {
                  setState(() {
                    _volta = val;
                  });
                },
              ),

              const Spacer(),

              BotaoPrimario(
                texto: 'Salvar confirmação',
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
