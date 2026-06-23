import 'package:flutter_test/flutter_test.dart';
import 'package:rally_master/main.dart';
import 'package:rally_master/services/app_settings_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final settings = AppSettingsProvider();
    await tester.pumpWidget(RaidApp(settings: settings));
    expect(find.byType(RaidApp), findsOneWidget);
  });
}
