import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wake_nihongo/app/app.dart';
import 'package:wake_nihongo/features/alarm/presentation/alarm_providers.dart';

import 'fake_alarm_repository.dart';

void main() {
  testWidgets('알람 목록 화면 타이틀 표시', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWith((ref) => FakeAlarmRepository()),
        ],
        child: const WakeNihongoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WakeNihongo'), findsOneWidget);
  });
}
