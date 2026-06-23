import 'package:flutter_test/flutter_test.dart';
import 'package:rally_master/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RaidApp());
    expect(find.byType(RaidApp), findsOneWidget);
  });
}
