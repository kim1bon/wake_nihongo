/// 번들된 Noto Sans 패밀리 이름 (`pubspec.yaml` 의 `family` 와 동일해야 함).
abstract final class AppFonts {
  static const String korean = 'Noto Sans KR';
  static const String japanese = 'Noto Sans JP';

  /// UI 기본: 한글·영문 우선, 없는 글리프는 일본어 서브셋으로.
  static const List<String> fallbackAfterKorean = [japanese];

  /// 일본어 본문 우선 — 퀴즈 프롬프트 등.
  static const List<String> fallbackAfterJapanese = [korean];
}
