import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final quizAlarmCategoryLevelsProvider =
    AsyncNotifierProvider<QuizAlarmCategoryLevelsNotifier, Map<String, Set<String>>>(
  QuizAlarmCategoryLevelsNotifier.new,
);

/// 카테고리별로 허용할 `level` 집합. 키가 없거나 값이 비어 있으면 해당 카테고리는 전체 레벨 허용.
class QuizAlarmCategoryLevelsNotifier extends AsyncNotifier<Map<String, Set<String>>> {
  static const String _prefsKey = 'quiz_alarm_category_levels_v1';

  @override
  Future<Map<String, Set<String>>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, Set<String>>{};
      decoded.forEach((k, v) {
        final key = '$k'.trim();
        if (key.isEmpty) return;
        if (v is List) {
          final set = v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toSet();
          if (set.isNotEmpty) {
            out[key] = set;
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Map<String, Set<String>> map) async {
    final prefs = await SharedPreferences.getInstance();
    if (map.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    final jsonMap = <String, dynamic>{};
    for (final e in map.entries) {
      if (e.value.isNotEmpty) {
        jsonMap[e.key] = e.value.toList()..sort();
      }
    }
    if (jsonMap.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(jsonMap));
    }
  }

  Map<String, Set<String>> _copyCurrent() {
    return state.maybeWhen(
      data: (m) => m.map((k, v) => MapEntry(k, Set<String>.from(v))),
      orElse: () => <String, Set<String>>{},
    );
  }

  Future<void> setLevelsForCategory(String category, Set<String> levels) async {
    final cat = category.trim();
    if (cat.isEmpty) return;
    final next = _copyCurrent();
    if (levels.isEmpty) {
      next.remove(cat);
    } else {
      next[cat] = levels;
    }
    await _persist(next);
    state = AsyncData(next);
  }

  Future<void> clearCategory(String category) async {
    final cat = category.trim();
    if (cat.isEmpty) return;
    final next = _copyCurrent();
    if (!next.containsKey(cat)) return;
    next.remove(cat);
    await _persist(next);
    state = AsyncData(next);
  }
}
