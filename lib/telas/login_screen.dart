import 'package:flutter/material.dart';
import 'package:vango/theme/app_theme.dart';
import 'package:vango/widgets/botao_primario.dart';
import 'package:vango/telas/aluno_home_screen.dart';
import 'package:vango/telas/motorista_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _mostrarSenha = false;
  bool _exibirErro = false;

  void _fazerLogin() {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim().toLowerCase();

    if (email.contains('motorista')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MotoristaHomeScreen()),
      );
    } else if (email.isNotEmpty && !email.contains('erro')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AlunoHomeScreen()),
      );
    } else {
      setState(() {
        _exibirErro = true;
      });
    }
  }

  void _loginComoAluno() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AlunoHomeScreen()),
    );
  }

  void _loginComoMotorista() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MotoristaHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              // Logo VanGo
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryYellow.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 54,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Nome e rota
              const Text(
                'VanGo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Capão Bonito → Itapetininga',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 48),

              // Campo de E-mail
              const Text(
                'E-mail',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'seu@email.com',
                ),
              ),

              const SizedBox(height: 20),

              // Campo de Senha
              const Text(
                'Senha',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _senhaController,
                obscureText: !_mostrarSenha,
                decoration: InputDecoration(
                  hintText: 'Sua senha',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _mostrarSenha = !_mostrarSenha;
                      });
                    },
                  ),
                ),
              ),

              if (_exibirErro) ...[
                const SizedBox(height: 12),
                const Text(
                  'E-mail ou senha incorretos. Tente novamente.',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Botão Entrar
              BotaoPrimario(
                texto: 'Entrar',
                onPressed: _fazerLogin,
              ),

              const SizedBox(height: 36),

              // Seção Modo Demonstração
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 18, color: AppTheme.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'Acesso rápido para demonstração:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryDark,
                              side: const BorderSide(color: AppTheme.borderLight),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.school_outlined, size: 18),
                            label: const Text('Aluno'),
                            onPressed: _loginComoAluno,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryDark,
                              side: const BorderSide(color: AppTheme.borderLight),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.directions_bus_outlined, size: 18),
                            label: const Text('Motorista'),
                            onPressed: _loginComoMotorista,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
