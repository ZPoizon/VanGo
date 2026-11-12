import 'package:flutter_test/flutter_test.dart';
import 'package:vango/app/app.dart';
import 'package:vango/demo/demo_store.dart';

void main() {
  testWidgets('VanGo app render smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(VanGoApp(store: DemoStore.demo()));
    await tester.pumpAndSettle();

    // A tela de login deve aparecer no modo demonstração.
    expect(find.text('VanGo'), findsWidgets);
    expect(find.text('Transporte Universitário por Van'), findsOneWidget);
  });
}
