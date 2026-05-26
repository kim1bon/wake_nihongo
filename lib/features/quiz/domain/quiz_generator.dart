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
    QuizPromptMode mode = QuizPromptMode.jpToKor,
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

  static QuizChallengeQuestion? _buildQuestionForGroup({
    required List<QuizEntry> pool,
    required QuizPromptMode mode,
    required Random random,
  }) {
    if (pool.isEmpty) return null;
    final type = pool.first.type.trim();
    final n = choiceCountForType(type);
    if (n <= 1) return null;

    QuizEntry pickEntryForLabel(
      String label, {
      required String correctLabel,
      required QuizEntry correctEntry,
      required Map<String, QuizEntry> poolLabelSource,
      required Map<String, QuizEntry> anyLabelSource,
    }) {
      if (label == correctLabel) {
        return correctEntry;
      }
      final fromPool = poolLabelSource[label];
      if (fromPool != null) return fromPool;
      final any = anyLabelSource[label];
      return any ?? correctEntry;
    }

    final correctEntry = pool[random.nextInt(pool.length)];
    final correctLabel = switch (mode) {
      QuizPromptMode.jpToKor => correctEntry.kor.trim(),
      QuizPromptMode.korToJp => correctEntry.jp.trim(),
    };
    if (correctLabel.isEmpty) {
      return null;
    }

    // 전체 후보에서 label ↔ 대표 entry 매핑 구성.
    final baseCandidates = <String, QuizEntry>{};
    for (final e in pool) {
      final label = switch (mode) {
        QuizPromptMode.jpToKor => e.kor.trim(),
        QuizPromptMode.korToJp => e.jp.trim(),
      };
      if (label.isEmpty || label == correctLabel) continue;
      baseCandidates.putIfAbsent(label, () => e);
    }

    if (baseCandidates.length < n - 1) {
      return null;
    }

    // incorrect_pool 기반 우선 오답.
    final incorrectPoolIds = correctEntry.incorrectPoolIds;
    final fromPoolLabels = <String>[];
    final fromPoolLabelSource = <String, QuizEntry>{};
    if (incorrectPoolIds != null && incorrectPoolIds.isNotEmpty) {
      final entriesById = <String, List<QuizEntry>>{};
      for (final e in pool) {
        entriesById.putIfAbsent(e.id.trim(), () => []).add(e);
      }
      for (final rawId in incorrectPoolIds) {
        final id = rawId.trim();
        if (id.isEmpty) continue;
        final candidates = entriesById[id];
        if (candidates == null || candidates.isEmpty) continue;
        for (final e in candidates) {
          if (e.id == correctEntry.id) continue;
          final label = switch (mode) {
            QuizPromptMode.jpToKor => e.kor.trim(),
            QuizPromptMode.korToJp => e.jp.trim(),
          };
          if (label.isEmpty || label == correctLabel) continue;
          if (!fromPoolLabelSource.containsKey(label)) {
            fromPoolLabelSource[label] = e;
            fromPoolLabels.add(label);
          }
        }
      }
      fromPoolLabels.shuffle(random);
    }

    final desiredWrongCount = n - 1;
    final selectedWrongLabels = <String>[];

    // 1단계: incorrect_pool에서 가능한 만큼 채우기.
    for (final label in fromPoolLabels) {
      if (selectedWrongLabels.length >= desiredWrongCount) break;
      selectedWrongLabels.add(label);
    }

    // 2단계: 부족분은 기존 그룹 랜덤으로 보충.
    if (selectedWrongLabels.length < desiredWrongCount) {
      final remainingCount = desiredWrongCount - selectedWrongLabels.length;
      final otherLabels = baseCandidates.keys
          .where(
            (label) =>
                label != correctLabel && !selectedWrongLabels.contains(label),
          )
          .toList()
        ..shuffle(random);
      if (otherLabels.length < remainingCount) {
        return null;
      }
      selectedWrongLabels.addAll(otherLabels.take(remainingCount));
    }

    if (selectedWrongLabels.length != desiredWrongCount) {
      return null;
    }

    final allLabels = <String>[correctLabel, ...selectedWrongLabels]..shuffle(random);
    final anyLabelSource = Map<String, QuizEntry>.from(baseCandidates);

    final wrongPickQuotes = <String>[];
    final choiceKorPronunciations = <String?>[];

    for (final label in allLabels) {
      final entry = pickEntryForLabel(
        label,
        correctLabel: correctLabel,
        correctEntry: correctEntry,
        poolLabelSource: fromPoolLabelSource,
        anyLabelSource: anyLabelSource,
      );
      wrongPickQuotes.add(entry.jp.trim());
      switch (mode) {
        case QuizPromptMode.jpToKor:
          choiceKorPronunciations.add(null);
          break;
        case QuizPromptMode.korToJp:
          final p = entry.korPronunciation.trim();
          choiceKorPronunciations.add(p.isEmpty ? null : p);
          break;
      }
    }

    final correctIndex = allLabels.indexOf(correctLabel);
    if (correctIndex < 0) return null;

    final promptPrimary = switch (mode) {
      QuizPromptMode.jpToKor => correctEntry.jp.trim(),
      QuizPromptMode.korToJp => correctEntry.kor.trim(),
    };

    final promptSecondary = switch (mode) {
      QuizPromptMode.jpToKor => () {
          final showHira = correctEntry.hiraganaDisplay &&
              correctEntry.hiragana.trim().isNotEmpty;
          return showHira ? correctEntry.hiragana.trim() : null;
        }(),
      QuizPromptMode.korToJp => null,
    };

    return QuizChallengeQuestion(
      mode: mode,
      promptPrimary: promptPrimary,
      promptSecondary: promptSecondary,
      choices: allLabels,
      wrongPickQuotes: wrongPickQuotes,
      choiceKorPronunciations: choiceKorPronunciations,
      correctChoiceIndex: correctIndex,
      category: correctEntry.category.trim(),
      type: type,
    );
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
      final q = _buildQuestionForGroup(
        pool: pool,
        mode: QuizPromptMode.jpToKor,
        random: r,
      );
      if (q != null) {
        return q;
      }
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
      final q = _buildQuestionForGroup(
        pool: pool,
        mode: QuizPromptMode.korToJp,
        random: r,
      );
      if (q != null) {
        return q;
      }
    }
    return null;
  }
}
