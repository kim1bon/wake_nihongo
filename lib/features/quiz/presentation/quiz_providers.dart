import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/quiz_alarm_categories_notifier.dart';
import '../../settings/presentation/quiz_alarm_category_levels_notifier.dart';
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

/// 설정의 category·카테고리별 level 에 맞춘 출제용 목록.
/// 출제 형식: 시트 `type`이 `sentence`면 3지선다, 그 외는 4지선다(대소문자 무시).
final quizFilteredEntriesProvider = FutureProvider<List<QuizEntry>>((ref) async {
  final entries = await ref.watch(quizEntriesProvider.future);
  var levelsByCategory = await ref.watch(quizAlarmCategoryLevelsProvider.future);
  var enabledCategories = await ref.watch(quizAlarmEnabledCategoriesProvider.future);

  if (levelsByCategory.isNotEmpty) {
    final knownCats = entries.map((e) => e.category.trim()).toSet();
    levelsByCategory = Map.fromEntries(
      levelsByCategory.entries.where((e) => knownCats.contains(e.key)),
    );
    levelsByCategory.removeWhere((_, levels) => levels.isEmpty);
  }

  if (enabledCategories.isNotEmpty) {
    final known = entries.map((e) => e.category.trim()).toSet();
    enabledCategories = enabledCategories.intersection(known);
    if (enabledCategories.isEmpty) {
      enabledCategories = {};
    }
  }

  var filtered = QuizGenerator.filterByEnabledCategories(entries, enabledCategories);
  filtered = QuizGenerator.filterByCategoryLevels(filtered, levelsByCategory);
  return filtered;
});
