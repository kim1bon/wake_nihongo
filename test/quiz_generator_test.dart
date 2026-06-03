import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_nihongo/features/quiz/data/quiz_sheet_parser.dart';
import 'package:wake_nihongo/features/quiz/domain/quiz_entry.dart';
import 'package:wake_nihongo/features/quiz/domain/quiz_generator.dart';
import 'package:wake_nihongo/features/quiz/domain/quiz_prompt_mode.dart';

QuizEntry _e({
  required String id,
  required String category,
  required String type,
  required String jp,
  required String kor,
  String level = '',
  String hiragana = '',
  String korPronunciation = '',
  bool hiraganaDisplay = false,
  List<String>? incorrectPoolIds,
}) {
  return QuizEntry(
    id: id,
    category: category,
    level: level,
    type: type,
    jp: jp,
    hiragana: hiragana,
    kor: kor,
    korPronunciation: korPronunciation,
    hiraganaDisplay: hiraganaDisplay,
    incorrectPoolIds: incorrectPoolIds,
  );
}

void main() {
  group('QuizGenerator', () {
    test('일→한: sentence가 아니면 4지선다, 같은 카테고리·타입의 한국어만 사용', () {
      final entries = List<QuizEntry>.generate(
        5,
        (i) => _e(
          id: '$i',
          category: 'A',
          type: '단어',
          jp: 'w$i',
          kor: 'k$i',
        ),
      );
      final q = QuizGenerator.generate(
        entries,
        random: Random(1),
        mode: QuizPromptMode.jpToKor,
      );
      expect(q, isNotNull);
      expect(q!.choices.length, 4);
      expect(q.wrongPickQuotes.length, q.choices.length);
      expect(q.mode, QuizPromptMode.jpToKor);
      for (var i = 0; i < q.choices.length; i++) {
        final kor = q.choices[i];
        final idx = int.parse(kor.substring(1));
        expect(q.wrongPickQuotes[i], 'w$idx');
        expect(q.choiceKorMeanings[i], isNull);
      }
      expect(q.type, '단어');
      expect(q.category, 'A');
      for (final k in q.choices) {
        expect(k.startsWith('k'), isTrue);
      }
    });

    test('한→일: 4지선다이면 일본어 보기', () {
      final entries = List<QuizEntry>.generate(
        5,
        (i) => _e(
          id: '$i',
          category: 'A',
          type: '단어',
          jp: 'w$i',
          kor: 'k$i',
        ),
      );
      final q = QuizGenerator.generate(
        entries,
        random: Random(2),
        mode: QuizPromptMode.korToJp,
      );
      expect(q, isNotNull);
      expect(q!.choices.length, 4);
      expect(q.choiceKorPronunciations.length, 4);
      expect(q.choiceKorMeanings.length, 4);
      expect(q.mode, QuizPromptMode.korToJp);
      expect(q.promptPrimary.startsWith('k'), isTrue);
      for (final c in q.choices) {
        expect(c.startsWith('w'), isTrue);
      }
    });

    test('한→일: kor_pronunciation이 선택지 보조 줄과 매칭된다', () {
      final entries = List<QuizEntry>.generate(
        5,
        (i) => _e(
          id: '$i',
          category: 'A',
          type: '단어',
          jp: 'w$i',
          kor: 'k$i',
          korPronunciation: '발음$i',
        ),
      );
      final q = QuizGenerator.generate(
        entries,
        random: Random(2),
        mode: QuizPromptMode.korToJp,
      );
      expect(q, isNotNull);
      for (var i = 0; i < q!.choices.length; i++) {
        final idx = int.parse(q.choices[i].substring(1));
        expect(q.choiceKorPronunciations[i], '발음$idx');
        expect(q.choiceKorMeanings[i], 'k$idx');
      }
    });

    test('filterByEnabledCategories로 category만 걸러낸다', () {
      final entries = [
        _e(id: '0', category: '여행', type: '단어', jp: 'a', kor: '1'),
        _e(id: '1', category: '식당', type: '단어', jp: 'b', kor: '2'),
      ];
      final onlyTravel = QuizGenerator.filterByEnabledCategories(entries, {'여행'});
      expect(onlyTravel.length, 1);
      expect(onlyTravel.single.category, '여행');
      final all = QuizGenerator.filterByEnabledCategories(entries, {});
      expect(all.length, 2);
    });

    test('filterByCategoryLevels로 카테고리별 level만 걸러낸다', () {
      final entries = [
        _e(id: '0', category: 'C', type: '단어', jp: 'a', kor: '1', level: '1'),
        _e(id: '1', category: 'C', type: '단어', jp: 'b', kor: '2', level: '2'),
        _e(id: '2', category: 'D', type: '단어', jp: 'c', kor: '3', level: '1'),
      ];
      final filtered = QuizGenerator.filterByCategoryLevels(entries, {
        'C': {'1'},
      });
      expect(filtered.length, 2);
      expect(filtered.where((e) => e.category == 'C').length, 1);
      expect(filtered.where((e) => e.category == 'D').single.level, '1');
    });

    test('일→한 sentence 타입은 3지선다', () {
      final entries = [
        _e(id: '0', category: 'A', type: 'sentence', jp: 'a', kor: 'x'),
        _e(id: '1', category: 'A', type: 'sentence', jp: 'b', kor: 'y'),
        _e(id: '2', category: 'A', type: 'sentence', jp: 'c', kor: 'z'),
      ];
      final q = QuizGenerator.generate(
        entries,
        random: Random(0),
        mode: QuizPromptMode.jpToKor,
      );
      expect(q, isNotNull);
      expect(q!.choices.length, 3);
      expect(q.wrongPickQuotes.length, 3);
      expect(q.type.toLowerCase(), 'sentence');
    });

    test('일→한 hiragana_display이면 promptSecondary가 채워진다', () {
      final entries = List<QuizEntry>.generate(
        5,
        (i) => _e(
          id: '$i',
          category: 'A',
          type: '단어',
          jp: 'w$i',
          hiragana: 'h$i',
          kor: 'k$i',
          hiraganaDisplay: true,
        ),
      );
      final q = QuizGenerator.generate(
        entries,
        random: Random(0),
        mode: QuizPromptMode.jpToKor,
      );
      expect(q, isNotNull);
      expect(q!.promptSecondary, isNotNull);
      expect(q.promptSecondary!.isNotEmpty, isTrue);
    });

    test('일→한: incorrect_pool이 3개 이상이면 오답 3개를 전부 풀에서 고른다', () {
      final entries = [
        _e(id: '0', category: 'A', type: '단어', jp: 'w0', kor: 'k0'),
        _e(id: '1', category: 'A', type: '단어', jp: 'w1', kor: 'k1'),
        _e(id: '2', category: 'A', type: '단어', jp: 'w2', kor: 'k2'),
        _e(id: '3', category: 'A', type: '단어', jp: 'w3', kor: 'k3'),
        _e(id: '4', category: 'A', type: '단어', jp: 'w4', kor: 'k4'),
      ];
      final withPool = [
        _e(
          id: '0',
          category: 'A',
          type: '단어',
          jp: 'w0',
          kor: 'k0',
          incorrectPoolIds: ['1', '2', '3', '4'],
        ),
        ...entries.skip(1),
      ];

      final q = QuizGenerator.generate(
        withPool,
        random: Random(0),
        mode: QuizPromptMode.jpToKor,
      );

      expect(q, isNotNull);
      expect(q!.choices.length, 4);
      final correct = 'k0';
      final wrong = q.choices.where((c) => c != correct).toSet();
      expect(wrong.length, 3);
      expect(wrong.difference({'k1', 'k2', 'k3', 'k4'}).isEmpty, isTrue);
    });

    test('일→한: incorrect_pool이 2개면 2개는 풀에서, 1개는 기존 규칙으로 보충한다', () {
      final base = [
        _e(id: '0', category: 'A', type: '단어', jp: 'w0', kor: 'k0'),
        _e(id: '1', category: 'A', type: '단어', jp: 'w1', kor: 'k1'),
        _e(id: '2', category: 'A', type: '단어', jp: 'w2', kor: 'k2'),
        _e(id: '3', category: 'A', type: '단어', jp: 'w3', kor: 'k3'),
        _e(id: '4', category: 'A', type: '단어', jp: 'w4', kor: 'k4'),
      ];
      final withPool = [
        _e(
          id: '0',
          category: 'A',
          type: '단어',
          jp: 'w0',
          kor: 'k0',
          incorrectPoolIds: ['1', '2'],
        ),
        ...base.skip(1),
      ];

      final q = QuizGenerator.generate(
        withPool,
        random: Random(1),
        mode: QuizPromptMode.jpToKor,
      );

      expect(q, isNotNull);
      expect(q!.choices.length, 4);
      final correct = 'k0';
      final wrong = q.choices.where((c) => c != correct).toSet();
      expect(wrong.length, 3);
      // 최소 2개는 incorrect_pool에서 온다.
      final fromPool = wrong.intersection({'k1', 'k2'});
      expect(fromPool.length >= 2, isTrue);
    });
  });

  group('parseQuizSheetCsv', () {
    test('헤더와 행 파싱', () {
      const csv = 'id,category,type,jp,kor\n'
          '0,C,단어,あ,a\n'
          '1,C,단어,い,b\n';
      final rows = parseQuizSheetCsv(csv);
      expect(rows.length, 2);
      expect(rows.first.kor, 'a');
      expect(rows.first.hiraganaDisplay, isFalse);
    });

    test('확장 컬럼 파싱', () {
      const csv = 'id,category,level,type,jp,hiragana,kor,kor_pronunciation,hiragana_display\n'
          '0,C,1,단어,漢字,かんじ,한자,한자,TRUE\n';
      final rows = parseQuizSheetCsv(csv);
      expect(rows.single.level, '1');
      expect(rows.single.hiragana, 'かんじ');
      expect(rows.single.korPronunciation, '한자');
      expect(rows.single.hiraganaDisplay, isTrue);
    });
  });
}
