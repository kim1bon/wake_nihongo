import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 시트 `type` 열과 동일한 문자열. 표시 순서 고정.
const List<String> kQuizAlarmTypeLabels = [
  '단어',
  '짧은 표현',
  '간단한 회화',
];

final quizAlarmEnabledTypesProvider =
    AsyncNotifierProvider<QuizAlarmEnabledTypesNotifier, Set<String>>(
  QuizAlarmEnabledTypesNotifier.new,
);

class QuizAlarmEnabledTypesNotifier extends AsyncNotifier<Set<String>> {
  static const String _prefsKey = 'quiz_alarm_enabled_types_v1';

  static Set<String> get defaultTypes => kQuizAlarmTypeLabels.toSet();

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey);
    if (list == null || list.isEmpty) {
      return {...defaultTypes};
    }
    final loaded = list.map((e) => e.trim()).toSet();
    final intersect = loaded.intersection(defaultTypes);
    if (intersect.isEmpty) {
      return {...defaultTypes};
    }
    return intersect;
  }

  Future<void> setTypes(Set<String> types) async {
    final valid = types.intersection(defaultTypes);
    if (valid.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      kQuizAlarmTypeLabels.where(valid.contains).toList(),
    );
    state = AsyncData(valid);
  }
}
