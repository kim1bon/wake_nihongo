import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_nihongo/features/quiz/domain/quiz_entry.dart';
import 'package:wake_nihongo/features/quiz/domain/quiz_generator.dart';
import 'package:wake_nihongo/features/quiz/data/quiz_sheet_parser.dart';

void main() {
  group('QuizGenerator', () {
    test('단어는 4지선다, 같은 카테고리·타입의 한국어만 사용', () {
      final entries = List<QuizEntry>.generate(
        5,
        (i) => QuizEntry(
          id: '$i',
          category: 'A',
          type: '단어',
          jp: 'w$i',
          kor: 'k$i',
        ),
      );
      final q = QuizGenerator.generate(entries, random: Random(1));
      expect(q, isNotNull);
      expect(q!.koreanChoices.length, 4);
      expect(q.type, '단어');
      expect(q.category, 'A');
      for (final k in q.koreanChoices) {
        expect(k.startsWith('k'), isTrue);
      }
    });

    test('filterByEnabledTypes로 type만 걸러낸다', () {
      final entries = [
        const QuizEntry(id: '0', category: 'C', type: '단어', jp: 'a', kor: '1'),
        const QuizEntry(id: '1', category: 'C', type: '짧은 표현', jp: 'b', kor: '2'),
      ];
      final onlyWord = QuizGenerator.filterByEnabledTypes(entries, {'단어'});
      expect(onlyWord.length, 1);
      expect(onlyWord.single.type, '단어');
    });

    test('비단어 타입은 2지선다', () {
      final entries = [
        const QuizEntry(id: '0', category: 'A', type: '짧은 표현', jp: 'a', kor: 'x'),
        const QuizEntry(id: '1', category: 'A', type: '짧은 표현', jp: 'b', kor: 'y'),
      ];
      final q = QuizGenerator.generate(entries, random: Random(0));
      expect(q, isNotNull);
      expect(q!.koreanChoices.length, 2);
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
    });
  });
}
