import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alarm/presentation/alarm_providers.dart';
import '../../quiz/domain/quiz_entry.dart';
import '../../quiz/presentation/quiz_providers.dart';
import 'quiz_alarm_categories_notifier.dart';
import 'quiz_alarm_types_notifier.dart';

List<String> _sortedCategoryNames(List<QuizEntry> entries) {
  final s = entries
      .map((e) => e.category.trim())
      .where((c) => c.isNotEmpty)
      .toSet();
  final l = s.toList()..sort();
  return l;
}

Future<void> _toggleQuizCategory({
  required WidgetRef ref,
  required BuildContext context,
  required String category,
  required bool? checked,
  required List<String> allSorted,
  required Set<String> saved,
}) async {
  if (checked == null || allSorted.isEmpty) return;
  final allSet = allSorted.toSet();

  if (saved.isEmpty) {
    if (!checked) {
      final next = allSet.difference({category});
      if (next.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최소 한 가지 카테고리는 선택해 주세요.')),
          );
        }
        return;
      }
      await ref.read(quizAlarmEnabledCategoriesProvider.notifier).setCategories(next);
    }
    return;
  }

  if (checked) {
    final next = {...saved, category};
    if (next.length == allSet.length && allSet.containsAll(next)) {
      await ref.read(quizAlarmEnabledCategoriesProvider.notifier).setCategories({});
    } else {
      await ref.read(quizAlarmEnabledCategoriesProvider.notifier).setCategories(next);
    }
  } else {
    final next = {...saved}..remove(category);
    if (next.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최소 한 가지 카테고리는 선택해 주세요.')),
        );
      }
      return;
    }
    await ref.read(quizAlarmEnabledCategoriesProvider.notifier).setCategories(next);
  }
}

/// 알람 관련 안내·권한, 알람 해제 시 퀴즈 유형·카테고리 설정.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(quizAlarmEnabledTypesProvider);
    final entriesAsync = ref.watch(quizEntriesProvider);
    final categoriesAsync = ref.watch(quizAlarmEnabledCategoriesProvider);
    final localQuizVersionAsync = ref.watch(localQuizVersionProvider);
    final remoteQuizVersionAsync = ref.watch(remoteQuizVersionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '알람',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('알림 권한'),
                  subtitle: const Text(
                    '알람 알림을 받으려면 허용이 필요합니다.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await ref.read(alarmRepositoryProvider).ensureNotificationPermissions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('설정 또는 권한 화면을 확인해 주세요.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '알람 해제 퀴즈',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '알람을 끌 때 출제되는 문제 범위입니다. 시트의「type」「category」열과 같습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '유형 (type)',
              style: theme.textTheme.titleSmall,
            ),
          ),
          typesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('설정을 불러오지 못했습니다.\n$e'),
            ),
            data: (enabled) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final type in kQuizAlarmTypeLabels)
                    CheckboxListTile(
                      title: Text(type),
                      value: enabled.contains(type),
                      onChanged: (checked) async {
                        if (checked == null) return;
                        final next = {...enabled};
                        if (checked) {
                          next.add(type);
                        } else {
                          next.remove(type);
                        }
                        if (next.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('최소 한 가지 유형은 켜 두어야 합니다.'),
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(quizAlarmEnabledTypesProvider.notifier)
                            .setTypes(next);
                      },
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '카테고리 (category)',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '모두 선택이면 전체 카테고리에서 출제됩니다. 일부만 끄면 해당 제목만 제외됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 8),
          entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('문제 목록을 불러오지 못했습니다.\n$e'),
            ),
            data: (entries) {
              return categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('카테고리 설정을 불러오지 못했습니다.\n$e'),
                ),
                data: (savedCategories) {
                  final allCats = _sortedCategoryNames(entries);
                  if (allCats.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          title: Text('불러온 데이터에 카테고리가 없습니다.'),
                        ),
                      ),
                    );
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (final cat in allCats)
                          CheckboxListTile(
                            title: Text(cat),
                            value: savedCategories.isEmpty || savedCategories.contains(cat),
                            onChanged: (checked) => _toggleQuizCategory(
                              ref: ref,
                              context: context,
                              category: cat,
                              checked: checked,
                              allSorted: allCats,
                              saved: savedCategories,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '로컬 데이터',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('원격 quiz_version'),
                  subtitle: remoteQuizVersionAsync.when(
                    loading: () => const Text('불러오는 중...'),
                    error: (e, _) => Text('조회 실패: $e'),
                    data: (version) => Text(version),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('로컬 quiz_version'),
                  subtitle: localQuizVersionAsync.when(
                    loading: () => const Text('불러오는 중...'),
                    error: (e, _) => Text('조회 실패: $e'),
                    data: (version) => Text(version),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: remoteQuizVersionAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (remote) => localQuizVersionAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (local) => Text(
                  remote == local ? '버전이 일치합니다.' : '버전이 다릅니다. 다음 동기화에서 갱신됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
