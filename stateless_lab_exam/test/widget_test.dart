import 'package:flutter_test/flutter_test.dart';

import 'package:stateless_lab_exam/main.dart';

void main() {
  testWidgets('Shopping cart page renders its sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('My Cart'), findsOneWidget);
    expect(find.text('Ready for checkout'), findsOneWidget);
    expect(find.text('Wireless Mouse'), findsOneWidget);
    expect(find.text('USB-C Hub'), findsOneWidget);
    expect(find.text('Laptop Stand'), findsOneWidget);
    expect(find.text('Place Order'), findsOneWidget);

    await tester.ensureVisible(find.text('Place Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place Order'));
    await tester.pump();
  });
}
