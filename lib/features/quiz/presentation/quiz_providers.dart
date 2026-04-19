import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_local_asset_data_source.dart';
import '../data/quiz_remote_data_source.dart';
import '../domain/quiz_entry.dart';

/// 원격 구글 시트 우선. 실패 시 [QuizAssetPaths.sampleCsv] 번들 샘플로 폴백.
final quizEntriesProvider = FutureProvider<List<QuizEntry>>((ref) async {
  final remote = QuizRemoteDataSource();
  try {
    return await remote.fetchEntries();
  } catch (_) {
    return QuizLocalAssetDataSource.loadSampleEntries();
  }
});
