import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vango/features/driver/widgets/solicitacoes_entrada_card.dart';
import 'package:vango/models/notificacao_entrada.dart';

NotificacaoEntrada _aviso({
  required String id,
  required String aluno,
  required String van,
  required DateTime criadoEm,
}) =>
    NotificacaoEntrada(
      id: id,
      grupoId: 'grupo_$id',
      grupoNome: van,
      solicitacaoId: id,
      alunoNome: aluno,
      criadoEm: criadoEm,
    );

void main() {
  test('mensagem identifica o aluno e a van do aviso', () {
    final aviso = _aviso(
      id: 'aluno-1',
      aluno: 'Ana',
      van: 'Manhã Centro',
      criadoEm: DateTime(2026, 11, 23, 8, 30),
    );

    expect(
      aviso.mensagem,
      'Ana solicitou entrada na van Manhã Centro.',
    );
  });

  testWidgets('nenhum cartão é renderizado sem avisos pendentes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SolicitacoesEntradaCard(
            notificacoes: <NotificacaoEntrada>[],
            onAbrir: _ignorar,
          ),
        ),
      ),
    );

    expect(find.text('Solicitações de entrada'), findsNothing);
  });

  testWidgets('cartão mostra contador e abre a solicitação tocada', (tester) async {
    final abertos = <String>[];
    final avisos = <NotificacaoEntrada>[
      _aviso(
        id: 'aluno-2',
        aluno: 'Bruno',
        van: 'Tarde Centro',
        criadoEm: DateTime(2026, 11, 23, 10),
      ),
      _aviso(
        id: 'aluno-1',
        aluno: 'Ana',
        van: 'Manhã Centro',
        criadoEm: DateTime(2026, 11, 23, 8, 30),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SolicitacoesEntradaCard(
            notificacoes: avisos,
            onAbrir: (aviso) => abertos.add(aviso.grupoId),
          ),
        ),
      ),
    );

    expect(find.text('Solicitações de entrada'), findsOneWidget);
    expect(find.text('2 pendente(s)'), findsOneWidget);
    expect(
      find.text('Bruno solicitou entrada na van Tarde Centro.'),
      findsOneWidget,
    );
    expect(
      find.text('Ana solicitou entrada na van Manhã Centro.'),
      findsOneWidget,
    );
    expect(find.text('Van: Tarde Centro · toque para analisar'), findsOneWidget);

    await tester.tap(find.text('Van: Tarde Centro · toque para analisar'));
    await tester.pump();

    expect(abertos, <String>['grupo_aluno-2']);
  });
}

void _ignorar(NotificacaoEntrada _) {}
