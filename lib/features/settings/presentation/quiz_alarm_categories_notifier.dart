import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final quizAlarmEnabledCategoriesProvider =
    AsyncNotifierProvider<QuizAlarmEnabledCategoriesNotifier, Set<String>>(
  QuizAlarmEnabledCategoriesNotifier.new,
);

/// 비어 있으면「전체 카테고리」. 하나라도 있으면 해당 이름의 카테고리만 출제.
class QuizAlarmEnabledCategoriesNotifier extends AsyncNotifier<Set<String>> {
  static const String _prefsKey = 'quiz_alarm_enabled_categories_v1';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey);
    if (list == null || list.isEmpty) {
      return {};
    }
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> setCategories(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    if (categories.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      final sorted = categories.toList()..sort();
      await prefs.setStringList(_prefsKey, sorted);
    }
    state = AsyncData(categories);
  }
}
