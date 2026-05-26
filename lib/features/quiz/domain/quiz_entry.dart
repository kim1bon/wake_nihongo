class QuizEntry {
  const QuizEntry({
    required this.id,
    required this.category,
    required this.level,
    required this.type,
    required this.jp,
    required this.hiragana,
    required this.kor,
    required this.korPronunciation,
    required this.hiraganaDisplay,
    this.incorrectPoolIds,
  });

  final String id;
  final String category;

  /// 시트 `level` (난이도). 문자열로 보관합니다.
  final String level;
  final String type;
  final String jp;
  final String hiragana;
  final String kor;
  final String korPronunciation;
  final bool hiraganaDisplay;

  /// 오답 풀 id 목록. 비어 있거나 `null`이면 그룹 전체에서 기존 규칙대로 오답을 고릅니다.
  final List<String>? incorrectPoolIds;
}
