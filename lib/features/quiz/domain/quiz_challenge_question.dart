import 'quiz_prompt_mode.dart';

/// 퀴즈 한 문제분. [promptPrimary]가 질문, [choices]가 선택 버튼 문구입니다.
class QuizChallengeQuestion {
  const QuizChallengeQuestion({
    required this.mode,
    required this.promptPrimary,
    this.promptSecondary,
    required this.choices,
    required this.wrongPickQuotes,
    required this.choiceKorPronunciations,
    required this.correctChoiceIndex,
    required this.category,
    required this.type,
  })  : assert(choices.length == wrongPickQuotes.length),
        assert(choices.length == choiceKorPronunciations.length),
        assert(correctChoiceIndex >= 0 && correctChoiceIndex < choices.length);

  final QuizPromptMode mode;

  /// 질문 본문 (일→한: 일본어, 한→일: 한국어).
  final String promptPrimary;

  /// 일본어 질문일 때만 히라가나 보조 줄.
  final String? promptSecondary;

  final List<String> choices;

  /// 오답 안내 「…」에 넣을 문구 (보통 일본어 표기).
  final List<String> wrongPickQuotes;

  /// 한→일 모드에서만 사용. 선택지 아래 작은 글씨(한국어 발음). `null`이면 미표시.
  final List<String?> choiceKorPronunciations;

  final int correctChoiceIndex;
  final String category;
  final String type;

  String get correctAnswerLabel => choices[correctChoiceIndex];
}
