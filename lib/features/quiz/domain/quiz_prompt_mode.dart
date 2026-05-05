/// 퀴즈 제시 방향: 설정·출제·UI에서 공통으로 사용합니다.
enum QuizPromptMode {
  /// 한국어 제시 → 일본어 선택 (기본값).
  korToJp,

  /// 일본어 제시 → 한국어 선택.
  jpToKor;

  static QuizPromptMode fromStorage(String? value) {
    if (value == jpToKor.storageValue) {
      return QuizPromptMode.jpToKor;
    }
    return QuizPromptMode.korToJp;
  }

  String get storageValue => switch (this) {
        QuizPromptMode.korToJp => 'korToJp',
        QuizPromptMode.jpToKor => 'jpToKor',
      };
}
