import 'package:flutter/services.dart';

import '../../../core/constants/quiz_asset_paths.dart';
import '../domain/quiz_entry.dart';
import 'quiz_sheet_parser.dart';

/// 네트워크 없을 때 사용하는 번들 내 샘플 시트 (형식은 원격 CSV 와 동일).
class QuizLocalAssetDataSource {
  QuizLocalAssetDataSource._();

  static Future<List<QuizEntry>> loadSampleEntries({
    String assetPath = QuizAssetPaths.sampleCsv,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseQuizSheetCsv(raw);
  }
}
