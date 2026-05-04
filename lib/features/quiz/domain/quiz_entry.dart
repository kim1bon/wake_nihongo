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
}
