/// 일본어(`jp`) 제시 → 한국어(`kor`) 고르기 한 문제분.
class JpToKorQuestion {
  const JpToKorQuestion({
    required this.promptJp,
    required this.koreanChoices,
    required this.correctChoiceIndex,
    required this.category,
    required this.type,
  });

  final String promptJp;
  final List<String> koreanChoices;
  final int correctChoiceIndex;
  final String category;
  final String type;

  String get correctKor => koreanChoices[correctChoiceIndex];
}
