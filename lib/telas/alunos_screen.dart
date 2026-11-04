import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/usuario.dart';
import '../data/dados_mock.dart';
import '../widgets/botao_primario.dart';

class AlunosScreen extends StatefulWidget {
  const AlunosScreen({super.key});

  @override
  State<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends State<AlunosScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String _abaSelecionada = 'Matutino'; // Matutino, Noturno, Pendentes
  List<Usuario> _todosAlunos = [];

  @override
  void initState() {
    super.initState();
    _todosAlunos = DadosMock.getTodosAlunos();
  }

  void _convidarAluno() {
    showDialog(
      context: context,
      builder: (context) {
        final emailCtrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Convidar novo aluno'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Informe o e-mail do aluno para enviar o convite de cadastro na van:'),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  hintText: 'aluno@email.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Convite enviado com sucesso!'),
                    backgroundColor: AppTheme.primaryDark,
                  ),
                );
              },
              child: const Text('Enviar Convite'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _buscaController.text.trim().toLowerCase();

    final alunosFiltrados = _todosAlunos.where((a) {
      final matchesQuery = a.nome.toLowerCase().contains(query) ||
          (a.faculdade ?? '').toLowerCase().contains(query);
      if (!matchesQuery) return false;

      if (_abaSelecionada == 'Pendentes') {
        return a.pendente;
      } else {
        return !a.pendente && a.periodo == _abaSelecionada;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alunos'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Campo de Busca
                  TextField(
                    controller: _buscaController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome',
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Abas Segmentadas (Figma Image 4)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton('Matutino'),
                        _buildTabButton('Noturno'),
                        _buildTabButton('Pendentes', badgeCount: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Alunos
            Expanded(
              child: alunosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum aluno encontrado.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: alunosFiltrados.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppTheme.borderLight),
                      itemBuilder: (context, index) {
                        final aluno = alunosFiltrados[index];
                        return InkWell(
                          onTap: () {
                            _mostrarDetalhesAluno(aluno);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        aluno.nome,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${aluno.faculdade ?? ''} · ${aluno.periodo ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${aluno.telefone ?? ''} · ${aluno.endereco ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Botão Fixo de Convidar Aluno
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: BotaoPrimario(
                texto: 'Convidar aluno',
                onPressed: _convidarAluno,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, {int? badgeCount}) {
    final bool isSelected = _abaSelecionada == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _abaSelecionada = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalhesAluno(Usuario aluno) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aluno.nome,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school, color: AppTheme.primaryDark),
                title: Text('${aluno.faculdade} (${aluno.periodo})'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone, color: AppTheme.primaryDark),
                title: Text(aluno.telefone ?? 'Não informado'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on, color: AppTheme.primaryDark),
                title: Text(aluno.endereco ?? 'Não informado'),
              ),
              const SizedBox(height: 16),
              BotaoPrimario(
                texto: 'Fechar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
