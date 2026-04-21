import 'dart:math';

import 'jp_to_kor_question.dart';
import 'quiz_entry.dart';

/// 규칙: 일본어 보기 → 한국어 선택. `단어`면 4지선다, 아니면 2지선다.
/// 오답은 같은 `category` + 같은 `type` 안에서만 채움.
class QuizGenerator {
  QuizGenerator._();

  static const String wordType = '단어';

  static int choiceCountForType(String type) => type.trim() == wordType ? 4 : 2;

  /// 알람 설정에서 선택한 `type`만 남깁니다. 시트의 `type` 값과 같아야 합니다.
  static List<QuizEntry> filterByEnabledTypes(
    List<QuizEntry> entries,
    Set<String> enabledTypes,
  ) {
    if (enabledTypes.isEmpty) return entries;
    return entries.where((e) => enabledTypes.contains(e.type.trim())).toList();
  }

  /// 알람 설정에서 선택한 `category`만 남깁니다. [enabledCategories]가 비어 있으면 필터 없음(전체).
  static List<QuizEntry> filterByEnabledCategories(
    List<QuizEntry> entries,
    Set<String> enabledCategories,
  ) {
    if (enabledCategories.isEmpty) return entries;
    return entries
        .where((e) => enabledCategories.contains(e.category.trim()))
        .toList();
  }

  /// 출제 가능한 그룹이 없거나 무작위 실패 시 `null`.
  static JpToKorQuestion? generate(
    List<QuizEntry> entries, {
    Random? random,
  }) {
    final r = random ?? Random();
    final groups = <String, List<QuizEntry>>{};
    for (final e in entries) {
      final jp = e.jp.trim();
      final kor = e.kor.trim();
      if (jp.isEmpty || kor.isEmpty) continue;
      final key = '${e.category.trim()}\x1f${e.type.trim()}';
      groups.putIfAbsent(key, () => []).add(e);
    }

    final viableKeys = groups.keys.where((k) {
      final list = groups[k]!;
      final t = list.first.type.trim();
      final n = choiceCountForType(t);
      final distinctKor = list.map((e) => e.kor.trim()).toSet();
      return distinctKor.length >= n;
    }).toList();

    if (viableKeys.isEmpty) return null;

    viableKeys.shuffle(r);
    for (final key in viableKeys) {
      final pool = groups[key]!;
      final type = pool.first.type.trim();
      final n = choiceCountForType(type);

      final correctEntry = pool[r.nextInt(pool.length)];
      final correctKor = correctEntry.kor.trim();

      final wrongKors = pool
          .map((e) => e.kor.trim())
          .where((k) => k != correctKor)
          .toSet()
          .toList()
        ..shuffle(r);

      if (wrongKors.length < n - 1) continue;

      final selectedWrong = wrongKors.take(n - 1).toList();
      final choices = <String>[correctKor, ...selectedWrong]..shuffle(r);
      final correctIndex = choices.indexOf(correctKor);
      if (correctIndex < 0) continue;

      return JpToKorQuestion(
        promptJp: correctEntry.jp.trim(),
        koreanChoices: choices,
        correctChoiceIndex: correctIndex,
        category: correctEntry.category.trim(),
        type: correctEntry.type.trim(),
      );
    }
    return null;
  }
}
