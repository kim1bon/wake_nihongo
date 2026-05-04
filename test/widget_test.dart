import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_nihongo/app/app.dart';
import 'package:wake_nihongo/features/alarm/presentation/alarm_providers.dart';

import 'fake_alarm_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('알람 목록 화면 타이틀 표시', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWith((ref) => FakeAlarmRepository()),
        ],
        child: const WakeNihongoApp(),
      ),
    );
    await tester.pump();
    // [WakeNihongoApp] 퀴즈 동기화용 1초 지연 타이머
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('알람'), findsWidgets);
  });
}
