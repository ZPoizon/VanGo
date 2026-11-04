import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/botao_primario.dart';

class AvisoChegadaScreen extends StatefulWidget {
  final bool isMotorista;

  const AvisoChegadaScreen({
    super.key,
    this.isMotorista = false,
  });

  @override
  State<AvisoChegadaScreen> createState() => _AvisoChegadaScreenState();
}

class _AvisoChegadaScreenState extends State<AvisoChegadaScreen> {
  bool _notificacaoEnviada = false;
  bool _alunoConfirmou = false;

  void _dispararAvisoMotorista() {
    setState(() {
      _notificacaoEnviada = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aviso "A van está chegando" enviado para todos os alunos!'),
        backgroundColor: AppTheme.primaryDark,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _confirmarAlunoEstouIndo() {
    setState(() {
      _alunoConfirmou = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sua resposta "Estou indo!" foi enviada ao motorista.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Aviso de chegada'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Simulação de Card da Notificação Push (Figma Design / Notificação)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: AppTheme.primaryYellow, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryYellow.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 40,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'A van está chegando!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'O motorista Roberto está a aproximadamente 5 minutos do seu ponto de embarque. Esteja no local preparado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_alunoConfirmou) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.badgeIdaEVoltaBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppTheme.badgeIdaEVoltaText, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Você respondeu: Estou indo! (06:42)',
                              style: TextStyle(
                                color: AppTheme.badgeIdaEVoltaText,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.directions_walk_rounded),
                          label: const Text('Estou indo!'),
                          onPressed: _confirmarAlunoEstouIndo,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (widget.isMotorista) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_circle_outlined, color: AppTheme.primaryDark),
                            SizedBox(width: 8),
                            Text(
                              'Controle do Motorista (Simulação)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Como motorista, toque abaixo para disparar o aviso de proximidade para os alunos da rota:',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        BotaoPrimario(
                          texto: _notificacaoEnviada
                              ? 'Aviso reenviado'
                              : 'Disparar aviso aos alunos',
                          icone: Icons.send_rounded,
                          onPressed: _dispararAvisoMotorista,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),

              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar para o início'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
