import 'dart:math';

import 'quiz_challenge_question.dart';
import 'quiz_entry.dart';
import 'quiz_prompt_mode.dart';

/// `type`이 `sentence`면 2지선다, 그 외는 4지선다.
/// 오답 보기는 같은 `category` + 같은 `type` 안에서만 채웁니다.
/// - 일→한: 서로 다른 [QuizEntry.kor] 가 충분해야 함.
/// - 한→일: 서로 다른 [QuizEntry.jp] 가 충분해야 함.
class QuizGenerator {
  QuizGenerator._();

  static const String sentenceType = 'sentence';

  /// 대소문자 무시.
  static int choiceCountForType(String type) {
    final t = type.trim().toLowerCase();
    return t == sentenceType ? 2 : 4;
  }

  /// 카테고리별 `level` 허용 집합. 해당 카테고리 키가 없거나 값이 비어 있으면 그 카테고리는 레벨 제한 없음.
  /// 제한이 있는 카테고리에서 `level`이 비어 있는 행은 제외됩니다.
  static List<QuizEntry> filterByCategoryLevels(
    List<QuizEntry> entries,
    Map<String, Set<String>> levelsByCategory,
  ) {
    if (levelsByCategory.isEmpty) return entries;
    return entries.where((e) {
      final cat = e.category.trim();
      final allowed = levelsByCategory[cat];
      if (allowed == null || allowed.isEmpty) return true;
      return allowed.contains(e.level.trim());
    }).toList();
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
  static QuizChallengeQuestion? generate(
    List<QuizEntry> entries, {
    Random? random,
    QuizPromptMode mode = QuizPromptMode.korToJp,
  }) {
    return switch (mode) {
      QuizPromptMode.jpToKor => _generateJpToKor(entries, random: random),
      QuizPromptMode.korToJp => _generateKorToJp(entries, random: random),
    };
  }

  static Map<String, List<QuizEntry>> _groupEntries(List<QuizEntry> entries) {
    final groups = <String, List<QuizEntry>>{};
    for (final e in entries) {
      final jp = e.jp.trim();
      final kor = e.kor.trim();
      if (jp.isEmpty || kor.isEmpty) continue;
      final key = '${e.category.trim()}\x1f${e.type.trim()}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  static QuizChallengeQuestion? _generateJpToKor(
    List<QuizEntry> entries, {
    Random? random,
  }) {
    final r = random ?? Random();
    final groups = _groupEntries(entries);

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

      final wrongPickQuotes = choices.map((kor) {
        final entry = pool.firstWhere(
          (e) => e.kor.trim() == kor,
          orElse: () => correctEntry,
        );
        return entry.jp.trim();
      }).toList();

      final showHira = correctEntry.hiraganaDisplay &&
          correctEntry.hiragana.trim().isNotEmpty;

      return QuizChallengeQuestion(
        mode: QuizPromptMode.jpToKor,
        promptPrimary: correctEntry.jp.trim(),
        promptSecondary: showHira ? correctEntry.hiragana.trim() : null,
        choices: choices,
        wrongPickQuotes: wrongPickQuotes,
        choiceKorPronunciations: List<String?>.filled(choices.length, null),
        correctChoiceIndex: correctIndex,
        category: correctEntry.category.trim(),
        type: type,
      );
    }
    return null;
  }

  static QuizChallengeQuestion? _generateKorToJp(
    List<QuizEntry> entries, {
    Random? random,
  }) {
    final r = random ?? Random();
    final groups = _groupEntries(entries);

    final viableKeys = groups.keys.where((k) {
      final list = groups[k]!;
      final t = list.first.type.trim();
      final n = choiceCountForType(t);
      final distinctJp = list.map((e) => e.jp.trim()).toSet();
      return distinctJp.length >= n;
    }).toList();

    if (viableKeys.isEmpty) return null;

    viableKeys.shuffle(r);
    for (final key in viableKeys) {
      final pool = groups[key]!;
      final type = pool.first.type.trim();
      final n = choiceCountForType(type);

      final correctEntry = pool[r.nextInt(pool.length)];
      final correctJp = correctEntry.jp.trim();

      final wrongJps = pool
          .map((e) => e.jp.trim())
          .where((j) => j != correctJp)
          .toSet()
          .toList()
        ..shuffle(r);

      if (wrongJps.length < n - 1) continue;

      final selectedWrong = wrongJps.take(n - 1).toList();
      final choices = <String>[correctJp, ...selectedWrong]..shuffle(r);
      final correctIndex = choices.indexOf(correctJp);
      if (correctIndex < 0) continue;

      final wrongPickQuotes = choices.map((jp) {
        final entry = pool.firstWhere(
          (e) => e.jp.trim() == jp,
          orElse: () => correctEntry,
        );
        return entry.jp.trim();
      }).toList();

      final choiceKorPronunciations = choices.map((jp) {
        final entry = pool.firstWhere(
          (e) => e.jp.trim() == jp,
          orElse: () => correctEntry,
        );
        final p = entry.korPronunciation.trim();
        return p.isEmpty ? null : p;
      }).toList();

      return QuizChallengeQuestion(
        mode: QuizPromptMode.korToJp,
        promptPrimary: correctEntry.kor.trim(),
        promptSecondary: null,
        choices: choices,
        wrongPickQuotes: wrongPickQuotes,
        choiceKorPronunciations: choiceKorPronunciations,
        correctChoiceIndex: correctIndex,
        category: correctEntry.category.trim(),
        type: type,
      );
    }
    return null;
  }
}
