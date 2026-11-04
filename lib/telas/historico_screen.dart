import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/usuario.dart';
import '../data/dados_mock.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late List<ViagemHistorico> _historico;
  String _periodoAtual = 'Junho de 2025';

  @override
  void initState() {
    super.initState();
    _historico = DadosMock.getHistoricoViagens();
  }

  void _alterarPeriodo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final periodos = ['Junho de 2025', 'Maio de 2025', 'Abril de 2025'];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Selecione o Período',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...periodos.map(
              (p) => ListTile(
                title: Text(p),
                trailing: p == _periodoAtual ? const Icon(Icons.check, color: AppTheme.primaryDark) : null,
                onTap: () {
                  setState(() {
                    _periodoAtual = p;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Histórico'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Card de Seleção de Período (Figma Image 5)
            Card(
              child: ListTile(
                onTap: _alterarPeriodo,
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text(
                  'PERÍODO · TOQUE PARA ALTERAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                subtitle: Text(
                  _periodoAtual,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ),
            ),

            const SizedBox(height: 20),

            // Lista de Viagens Passadas
            ..._historico.map((viagem) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Badge com a Data (ex: 18 JUN)
                      Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          viagem.data,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Informações de Horário e Confirmados
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viagem.tipo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              viagem.horario,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${viagem.confirmados} de ${viagem.total} confirmados',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
