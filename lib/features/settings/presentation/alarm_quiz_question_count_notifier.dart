import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final alarmQuizQuestionCountProvider =
    AsyncNotifierProvider<AlarmQuizQuestionCountNotifier, int>(
  AlarmQuizQuestionCountNotifier.new,
);

/// 알람 해제까지 맞혀야 하는 퀴즈 개수 (1~3).
class AlarmQuizQuestionCountNotifier extends AsyncNotifier<int> {
  static const String _prefsKey = 'alarm_quiz_question_count_v1';
  static const int defaultCount = 1;
  static const int minCount = 1;
  static const int maxCount = 3;

  @override
  Future<int> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_prefsKey);
    if (v == null) return defaultCount;
    return v.clamp(minCount, maxCount);
  }

  Future<void> setCount(int count) async {
    final c = count.clamp(minCount, maxCount);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, c);
    state = AsyncData(c);
  }
}
