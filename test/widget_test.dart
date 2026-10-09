import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pip_config/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PipConfig opens with an empty local config list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PipConfigApp());
    await tester.pumpAndSettle();

    expect(find.text('Подключения'), findsOneWidget);
    expect(find.text('Добавь первый конфиг'), findsOneWidget);
  });
}
