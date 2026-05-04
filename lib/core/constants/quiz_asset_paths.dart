/// 번들에 포함되는 퀴즈 CSV (네트워크 실패 시 폴백).
abstract final class QuizAssetPaths {
  static const String sampleCsv = 'assets/questions/wake_nihongo_sample.csv';

  /// 구버전 단일 파일 캐시 (인덱스 동기화 전 레거시).
  static const String mainCsvFileName = 'wake_nihongo_main_quiz.csv';

  /// 시트별 CSV (`sheet_<storageKey>.csv`).
  static const String sheetsSubDir = 'sheets';

  static const String sheetsManifestFileName = 'quiz_sheets_manifest.json';
}
