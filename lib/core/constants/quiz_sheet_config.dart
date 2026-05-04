/// 구글 시트 CSV 내보내기 URL (시트가 ‘웹에 게시’ 또는 링크 공개여야 앱에서 읽을 수 있음).
abstract final class QuizSheetConfig {
  static const String spreadsheetId = '13vaIALwMHGeHVKSlAwgxUKRlkF3pri96k4eQZQLKKVE';
  static const String versionSheetGid = '0';

  /// 사용 유무(인덱스) 탭 — `id`, `use_display`, `content_name`, `url`.
  static const String quizIndexSheetGid = '793932036';

  /// 인덱스·URL 동기화 실패 시 단일 탭 폴백.
  static const String legacyQuizSheetGid = '1842058493';

  /// `format=csv` + `gid` 로 해당 탭만 가져옵니다.
  static Uri exportCsvUriForGid(String gid) => Uri.parse(
        'https://docs.google.com/spreadsheets/d/$spreadsheetId/export?format=csv&gid=$gid',
      );

  static Uri get versionExportCsvUri => exportCsvUriForGid(versionSheetGid);
  static Uri get quizIndexExportCsvUri => exportCsvUriForGid(quizIndexSheetGid);
  static Uri get legacyQuizExportCsvUri => exportCsvUriForGid(legacyQuizSheetGid);
}
