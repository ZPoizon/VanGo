import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/usuario.dart';
import '../data/dados_mock.dart';

class ListaViagemScreen extends StatefulWidget {
  const ListaViagemScreen({super.key});

  @override
  State<ListaViagemScreen> createState() => _ListaViagemScreenState();
}

class _ListaViagemScreenState extends State<ListaViagemScreen> {
  late List<AlunoPresenca> _listaAlunos;
  String _filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    _listaAlunos = DadosMock.getListaDoDia();
  }

  Widget _buildBadge(StatusPresenca status) {
    Color bg;
    Color text;

    switch (status) {
      case StatusPresenca.idaEVolta:
        bg = AppTheme.badgeIdaEVoltaBg;
        text = AppTheme.badgeIdaEVoltaText;
        break;
      case StatusPresenca.soIda:
        bg = AppTheme.badgeSoIdaBg;
        text = AppTheme.badgeSoIdaText;
        break;
      case StatusPresenca.soVolta:
        bg = AppTheme.badgeSoVoltaBg;
        text = AppTheme.badgeSoVoltaText;
        break;
      case StatusPresenca.naoVai:
        bg = AppTheme.badgeNaoVaiBg;
        text = AppTheme.badgeNaoVaiText;
        break;
      case StatusPresenca.semResposta:
        bg = AppTheme.badgeSemRespostaBg;
        text = AppTheme.badgeSemRespostaText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responderamCount = _listaAlunos.where((a) => a.status != StatusPresenca.semResposta).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Lista do dia'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-cabeçalho de estatísticas (Image 3 do Figma)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    children: [
                      TextSpan(
                        text: '$responderamCount de ${_listaAlunos.length} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const TextSpan(text: 'responderam à chamada'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),

          // Filtros rápidos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _filtro == 'TODOS',
                  onSelected: (_) => setState(() => _filtro = 'TODOS'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Confirmados'),
                  selected: _filtro == 'CONFIRMADOS',
                  onSelected: (_) => setState(() => _filtro = 'CONFIRMADOS'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Não vai'),
                  selected: _filtro == 'NAO_VAI',
                  onSelected: (_) => setState(() => _filtro = 'NAO_VAI'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Sem resposta'),
                  selected: _filtro == 'SEM_RESPOSTA',
                  onSelected: (_) => setState(() => _filtro = 'SEM_RESPOSTA'),
                ),
              ],
            ),
          ),

          // Lista de Alunos
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _listaAlunos.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderLight),
              itemBuilder: (context, index) {
                final item = _listaAlunos[index];

                // Aplicar filtro
                if (_filtro == 'CONFIRMADOS' &&
                    (item.status == StatusPresenca.naoVai || item.status == StatusPresenca.semResposta)) {
                  return const SizedBox.shrink();
                }
                if (_filtro == 'NAO_VAI' && item.status != StatusPresenca.naoVai) {
                  return const SizedBox.shrink();
                }
                if (_filtro == 'SEM_RESPOSTA' && item.status != StatusPresenca.semResposta) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.aluno.nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.aluno.faculdade} · Entra ${item.aluno.horarioEntrada} · Sai ${item.aluno.horarioSaida}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (item.horarioEstouIndo != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.check, size: 14, color: AppTheme.badgeAvisadoText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Estou indo - ${item.horarioEstouIndo}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.badgeAvisadoText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.horarioAvisado != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.badgeAvisadoBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Avisado ${item.horarioAvisado}',
                                style: const TextStyle(
                                  color: AppTheme.badgeAvisadoText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          _buildBadge(item.status),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
