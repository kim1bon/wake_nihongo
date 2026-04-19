/// 구글 시트 CSV 내보내기 URL (시트가 ‘웹에 게시’ 또는 링크 공개여야 앱에서 읽을 수 있음).
abstract final class QuizSheetConfig {
  static const String spreadsheetId = '13vaIALwMHGeHVKSlAwgxUKRlkF3pri96k4eQZQLKKVE';
  static const String gid = '434121783';

  /// `format=csv` + `gid` 로 해당 탭만 가져옵니다.
  static Uri exportCsvUri = Uri.parse(
    'https://docs.google.com/spreadsheets/d/$spreadsheetId/export?format=csv&gid=$gid',
  );
}
