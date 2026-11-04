import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/botao_primario.dart';

class PadraoSemanalScreen extends StatefulWidget {
  const PadraoSemanalScreen({super.key});

  @override
  State<PadraoSemanalScreen> createState() => _PadraoSemanalScreenState();
}

class _PadraoSemanalScreenState extends State<PadraoSemanalScreen> {
  final Map<String, Map<String, bool>> _padraoSemanal = {
    'Segunda-feira': {'ida': true, 'volta': true},
    'Terça-feira': {'ida': true, 'volta': true},
    'Quarta-feira': {'ida': true, 'volta': true},
    'Quinta-feira': {'ida': true, 'volta': true},
    'Sexta-feira': {'ida': true, 'volta': false},
  };

  void _salvarPadrao() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Padrão semanal salvo com sucesso!'),
        backgroundColor: AppTheme.primaryDark,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Padrão semanal'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  const Text(
                    'Defina em quais dias da semana você costuma ir e voltar de van. Suas confirmações padrão serão geradas automaticamente.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._padraoSemanal.keys.map((dia) {
                    final configs = _padraoSemanal[dia]!;
                    final bool ida = configs['ida']!;
                    final bool volta = configs['volta']!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dia,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilterChip(
                                    selected: ida,
                                    label: Text(ida ? 'Ida: Sim' : 'Ida: Não'),
                                    selectedColor: AppTheme.badgeIdaEVoltaBg,
                                    checkmarkColor: AppTheme.badgeIdaEVoltaText,
                                    labelStyle: TextStyle(
                                      color: ida ? AppTheme.badgeIdaEVoltaText : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onSelected: (bool selected) {
                                      setState(() {
                                        _padraoSemanal[dia]!['ida'] = selected;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilterChip(
                                    selected: volta,
                                    label: Text(volta ? 'Volta: Sim' : 'Volta: Não'),
                                    selectedColor: AppTheme.badgeIdaEVoltaBg,
                                    checkmarkColor: AppTheme.badgeIdaEVoltaText,
                                    labelStyle: TextStyle(
                                      color: volta ? AppTheme.badgeIdaEVoltaText : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onSelected: (bool selected) {
                                      setState(() {
                                        _padraoSemanal[dia]!['volta'] = selected;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: BotaoPrimario(
                texto: 'Salvar padrão semanal',
                onPressed: _salvarPadrao,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
