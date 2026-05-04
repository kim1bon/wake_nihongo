/// 일본어(`jp`) 제시 → 한국어(`kor`) 고르기 한 문제분.
class JpToKorQuestion {
  const JpToKorQuestion({
    required this.promptJp,
    this.promptHiragana,
    required this.koreanChoices,
    required this.japaneseChoices,
    required this.correctChoiceIndex,
    required this.category,
    required this.type,
  }) : assert(
          japaneseChoices.length == koreanChoices.length,
          'japaneseChoices must align with koreanChoices',
        );

  final String promptJp;

  /// 시트에서 `hiragana_display`가 참일 때만 채움. UI에서 `jp` 아래 보조 줄로 표시.
  final String? promptHiragana;

  final List<String> koreanChoices;

  /// [koreanChoices]와 같은 순서·길이. 각 선택지 한국어에 대응하는 일본어 표기.
  final List<String> japaneseChoices;
  final int correctChoiceIndex;
  final String category;
  final String type;

  String get correctKor => koreanChoices[correctChoiceIndex];
}
