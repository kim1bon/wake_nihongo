import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/quiz_alarm_categories_notifier.dart';
import '../../settings/presentation/quiz_alarm_types_notifier.dart';
import '../data/quiz_cache_local_data_source.dart';
import '../data/quiz_repository.dart';
import '../data/quiz_version_remote_data_source.dart';
import '../domain/quiz_entry.dart';
import '../domain/quiz_generator.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository();
});

final localQuizVersionProvider = FutureProvider<String>((ref) async {
  final cache = QuizCacheLocalDataSource();
  final meta = await cache.readMeta();
  return meta.quizVersion;
});

final remoteQuizVersionProvider = FutureProvider<String>((ref) async {
  final remote = QuizVersionRemoteDataSource();
  try {
    final info = await remote.fetchVersionInfo();
    return info.quizVersion;
  } finally {
    remote.dispose();
  }
});

/// 런치 동기화 이후 로컬 CSV를 우선 사용합니다.
final quizEntriesProvider = FutureProvider<List<QuizEntry>>((ref) async {
  final repository = ref.read(quizRepositoryProvider);
  return repository.loadEntries();
});

/// 설정의 type·category 에 맞춘 출제용 목록 (알람 해제 퀴즈·연습 퀴즈 공통).
final quizFilteredEntriesProvider = FutureProvider<List<QuizEntry>>((ref) async {
  final entries = await ref.watch(quizEntriesProvider.future);
  final enabledTypes = await ref.watch(quizAlarmEnabledTypesProvider.future);
  var enabledCategories = await ref.watch(quizAlarmEnabledCategoriesProvider.future);

  var filtered = QuizGenerator.filterByEnabledTypes(entries, enabledTypes);

  if (enabledCategories.isNotEmpty) {
    final known = entries.map((e) => e.category.trim()).toSet();
    enabledCategories = enabledCategories.intersection(known);
    if (enabledCategories.isEmpty) {
      enabledCategories = {};
    }
  }
  filtered = QuizGenerator.filterByEnabledCategories(filtered, enabledCategories);
  return filtered;
});
