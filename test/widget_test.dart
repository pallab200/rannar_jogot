import 'package:flutter_test/flutter_test.dart';
import 'package:rannar_jogot/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const RannarJogotApp());
    expect(find.text('Rannar Jogot'), findsOneWidget);
  });
}
