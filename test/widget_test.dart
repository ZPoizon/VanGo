import 'package:flutter_test/flutter_test.dart';
import 'package:vango/app.dart';

void main() {
  testWidgets('VanGo app render smoke test', (WidgetTester tester) async {
    // Carrega o aplicativo VanGo
    await tester.pumpWidget(const VanGoApp());

    // Verifica que a tela de login exibe o nome do aplicativo
    expect(find.text('VanGo'), findsOneWidget);
    expect(find.text('Capão Bonito → Itapetininga'), findsOneWidget);
  });
}
