import 'package:flutter/material.dart';
import 'package:vango/theme/app_theme.dart';
import 'package:vango/data/dados_mock.dart';
import 'package:vango/telas/lista_viagem_screen.dart';
import 'package:vango/telas/alunos_screen.dart';
import 'package:vango/telas/historico_screen.dart';
import 'package:vango/telas/aviso_chegada_screen.dart';
import 'package:vango/telas/login_screen.dart';

class MotoristaHomeScreen extends StatefulWidget {
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> {
  bool _chamadaAberta = false;

  void _alternarChamada() {
    setState(() {
      _chamadaAberta = !_chamadaAberta;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_chamadaAberta
            ? 'Chamada de amanhã (Quarta, 19/06) foi aberta!'
            : 'Chamada encerrada.'),
        backgroundColor: AppTheme.primaryDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icone, size: 28, color: AppTheme.primaryDark),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motorista = DadosMock.usuarioMotoristaLogado;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Motorista (Figma Image 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOTORISTA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Olá, ${motorista.nome.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Terça-feira, 18 de junho',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryDark,
                    child: Text(
                      'RS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Card de Status da Chamada
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _chamadaAberta ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'STATUS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _chamadaAberta ? 'Chamada aberta para amanhã' : 'Nenhuma chamada aberta',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão Principal "ABRIR CHAMADA DE AMANHÃ"
              SizedBox(
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _alternarChamada,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _chamadaAberta ? 'FECHAR CHAMADA DE AMANHÃ' : 'ABRIR CHAMADA DE AMANHÃ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Quarta, 19/06',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Lista de Menu Cards
              _buildMenuItem(
                icone: Icons.group_outlined,
                titulo: 'Lista do dia',
                subtitulo: 'Confirmações e embarques',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ListaViagemScreen()),
                  );
                },
              ),

              _buildMenuItem(
                icone: Icons.person_outline_rounded,
                titulo: 'Alunos',
                subtitulo: 'Cadastros e endereços',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AlunosScreen()),
                  );
                },
              ),

              _buildMenuItem(
                icone: Icons.access_time_rounded,
                titulo: 'Histórico',
                subtitulo: 'Viagens anteriores',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoricoScreen()),
                  );
                },
              ),

              _buildMenuItem(
                icone: Icons.notifications_active_outlined,
                titulo: 'Aviso de chegada',
                subtitulo: 'Enviar notificação aos alunos',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvisoChegadaScreen(isMotorista: true),
                    ),
                  );
                },
              ),

              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.logout_rounded, size: 28, color: Colors.redAccent),
                  title: const Text(
                    'Sair',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
