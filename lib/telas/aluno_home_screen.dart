import 'package:flutter/material.dart';
import 'package:vango/theme/app_theme.dart';
import 'package:vango/data/dados_mock.dart';
import 'package:vango/telas/confirmacao_screen.dart';
import 'package:vango/telas/padrao_semanal_screen.dart';
import 'package:vango/telas/aviso_chegada_screen.dart';
import 'package:vango/telas/login_screen.dart';

class AlunoHomeScreen extends StatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  State<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends State<AlunoHomeScreen> {
  // Estado demonstrativo da presença do dia
  bool _vaiIda = true;
  bool _vaiVolta = true;

  void _abrirConfirmacao() async {
    final result = await Navigator.push<Map<String, bool>>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmacaoScreen(
          idaInicial: _vaiIda,
          voltaInicial: _vaiVolta,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _vaiIda = result['ida'] ?? _vaiIda;
        _vaiVolta = result['volta'] ?? _vaiVolta;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aluno = DadosMock.usuarioAlunoLogado;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho do Aluno
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ALUNO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Olá, ${aluno.nome.split(' ').first}',
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
                      'LM',
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

              // Card de Notificação de Chegada da Van
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvisoChegadaScreen(isMotorista: false),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryYellow, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.primaryDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avisos da Van',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Toque para ver se a van está a caminho',
                              style: TextStyle(
                                fontSize: 13,
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
              ),

              const SizedBox(height: 20),

              // Card de Status da Presença de Hoje
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.today_rounded, size: 20, color: AppTheme.primaryDark),
                              SizedBox(width: 8),
                              Text(
                                'Presença de Hoje',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_vaiIda || _vaiVolta)
                                  ? AppTheme.badgeIdaEVoltaBg
                                  : AppTheme.badgeNaoVaiBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (_vaiIda && _vaiVolta)
                                  ? 'Ida e Volta'
                                  : _vaiIda
                                      ? 'Só Ida'
                                      : _vaiVolta
                                          ? 'Só Volta'
                                          : 'Ausente',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (_vaiIda || _vaiVolta)
                                    ? AppTheme.badgeIdaEVoltaText
                                    : AppTheme.badgeNaoVaiText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1, color: AppTheme.borderLight),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'IDA (Manhã)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        _vaiIda
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 18,
                                        color: _vaiIda ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _vaiIda ? 'Vou de van' : 'Não vou',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _vaiIda ? Colors.green[800] : Colors.red[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'VOLTA (Tarde)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        _vaiVolta
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 18,
                                        color: _vaiVolta ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _vaiVolta ? 'Vou de van' : 'Não vou',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _vaiVolta ? Colors.green[800] : Colors.red[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _abrirConfirmacao,
                          child: const Text('Alterar minha presença'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Opção Padrão Semanal
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.date_range_rounded, color: AppTheme.primaryDark),
                  ),
                  title: const Text(
                    'Padrão semanal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Configure os dias fixos que você utiliza a van',
                    style: TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PadraoSemanalScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Botão Sair / Trocar perfil
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Sair da conta',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent),
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
