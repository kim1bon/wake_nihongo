import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../alarm/presentation/alarm_providers.dart';
import '../../quiz/domain/quiz_entry.dart';
import '../../quiz/domain/quiz_prompt_mode.dart';
import '../../quiz/presentation/quiz_providers.dart';
import 'alarm_quiz_question_count_notifier.dart';
import 'quiz_alarm_categories_notifier.dart';
import 'quiz_alarm_category_levels_notifier.dart';
import 'quiz_prompt_mode_notifier.dart';

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
      await ref.read(quizAlarmCategoryLevelsProvider.notifier).clearCategory(category);
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
    await ref.read(quizAlarmCategoryLevelsProvider.notifier).clearCategory(category);
  }
}

List<String> _sortedLevelsForCategory(List<QuizEntry> entries, String category) {
  final raw = entries
      .where((e) => e.category.trim() == category)
      .map((e) => e.level.trim())
      .where((l) => l.isNotEmpty)
      .toSet()
      .toList();
  raw.sort((a, b) {
    final ia = int.tryParse(a);
    final ib = int.tryParse(b);
    if (ia != null && ib != null) return ia.compareTo(ib);
    if (ia != null) return -1;
    if (ib != null) return 1;
    return a.compareTo(b);
  });
  return raw;
}

/// [restricted] — 저장된 제한 집합(비어 있으면 해당 카테고리는 전체 레벨 허용으로 간주).
Future<void> _toggleLevelForCategory({
  required WidgetRef ref,
  required BuildContext context,
  required String category,
  required String level,
  required bool? checked,
  required List<String> allSorted,
  required Set<String> restricted,
}) async {
  if (checked == null || allSorted.isEmpty) return;
  final allSet = allSorted.toSet();
  final notifier = ref.read(quizAlarmCategoryLevelsProvider.notifier);

  if (restricted.isEmpty) {
    if (!checked) {
      final next = allSet.difference({level});
      if (next.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최소 한 가지 레벨은 선택해 주세요.')),
          );
        }
        return;
      }
      await notifier.setLevelsForCategory(category, next);
    }
    return;
  }

  if (checked) {
    final next = {...restricted, level};
    if (next.length == allSet.length && allSet.containsAll(next)) {
      await notifier.setLevelsForCategory(category, {});
    } else {
      await notifier.setLevelsForCategory(category, next);
    }
  } else {
    final next = {...restricted}..remove(level);
    if (next.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최소 한 가지 레벨은 선택해 주세요.')),
        );
      }
      return;
    }
    await notifier.setLevelsForCategory(category, next);
  }
}

/// 알람 관련 안내·권한, 알람 해제 시 퀴즈 카테고리·레벨 설정.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sectionTitleStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    final panelTitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: AppPalette.navy,
      fontWeight: FontWeight.w700,
    );
    final panelDescStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
      height: 1.3,
      fontWeight: FontWeight.w500,
    );
    final entriesAsync = ref.watch(quizEntriesProvider);
    final categoriesAsync = ref.watch(quizAlarmEnabledCategoriesProvider);
    final categoryLevelsAsync = ref.watch(quizAlarmCategoryLevelsProvider);
    final alarmQuizCountAsync = ref.watch(alarmQuizQuestionCountProvider);
    final quizPromptModeAsync = ref.watch(quizPromptModeProvider);
    final localQuizVersionAsync = ref.watch(localQuizVersionProvider);
    final remoteQuizVersionAsync = ref.watch(remoteQuizVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('설정'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '알람',
              style: sectionTitleStyle,
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('iOS 알림 안내'),
                  subtitle: const Text(
                    '무음 스위치/집중 모드에서는 소리가 제한될 수 있습니다.',
                  ),
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        final theme = Theme.of(dialogContext);
                        return AlertDialog(
                          insetPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          backgroundColor: AppPalette.beigeSoft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: AppPalette.green.withValues(alpha: 0.28),
                            ),
                          ),
                          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                          contentPadding:
                              const EdgeInsets.fromLTRB(18, 10, 18, 10),
                          actionsPadding:
                              const EdgeInsets.fromLTRB(16, 2, 16, 18),
                          title: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppPalette.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.phone_iphone,
                                  size: 20,
                                  color: AppPalette.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'iOS 알림 설정 가이드',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: 360,
                            child: SingleChildScrollView(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.beigeContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppPalette.green
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  '아래 설정을 확인해 주세요.\n\n'
                                  '1) 설정 > 알림 > 일어나\n'
                                  ' - 알림 허용, 잠금화면, 배너, 사운드 ON\n'
                                  ' - 시간 민감 알림(Time Sensitive) ON\n\n'
                                  '2) 설정 > 집중 모드(Focus)\n'
                                  ' - 일어나 알림 허용\n\n'
                                  '3) 설정 > 사운드 및 햅틱\n'
                                  ' - 무음 모드 햅틱 재생 ON (진동 사용 시)\n\n'
                                  '참고: iOS 정책상 무음 스위치 ON 상태에서 소리를 '
                                  '100% 강제할 수는 없습니다.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                    color: AppPalette.navy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppPalette.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('확인'),
                              ),
                            ),
                          ],
                        );
                      },
                    );
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
              style: sectionTitleStyle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '알람을 끌 때 출제되는 문제 범위입니다. 카테고리를 펼치면 해당 묶음의 레벨만 골라 출제할 수 있습니다. '
              '시트의「category」「level」열과 같으며, type이 sentence면 2지·그 외 4지입니다.',
              style: panelDescStyle,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: quizPromptModeAsync.when(
                loading: () => const ListTile(
                  title: Text('문제 방식'),
                  subtitle: Text('불러오는 중…'),
                ),
                error: (e, _) => ListTile(
                  title: const Text('문제 방식'),
                  subtitle: Text('불러오지 못했습니다.\n$e'),
                ),
                data: (mode) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '문제 방식',
                      style: panelTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '연습 퀴즈와 알람 해제 퀴즈 모두 이 설정을 따릅니다.',
                      style: panelDescStyle,
                    ),
                    const SizedBox(height: 14),
                    Builder(
                      builder: (context) {
                        final isKorToJp = mode == QuizPromptMode.korToJp;
                        final questionLabel = isKorToJp ? '한국어' : '일본어';
                        final answerLabel = isKorToJp ? '일본어' : '한국어';
                        return Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            color: AppPalette.beigeSoft.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppPalette.green.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('문제', style: panelDescStyle),
                                        const SizedBox(height: 4),
                                        Text(
                                          questionLabel,
                                          style: panelTitleStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    child: StatefulBuilder(
                                      builder: (context, setPressedState) {
                                        var isPressed = false;
                                        return StatefulBuilder(
                                          builder: (context, setInnerState) {
                                            return AnimatedScale(
                                              duration: const Duration(
                                                milliseconds: 110,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              scale: isPressed ? 0.92 : 1.0,
                                              child: Material(
                                                color: AppPalette.green.withValues(
                                                  alpha: isPressed ? 0.24 : 0.16,
                                                ),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder: const CircleBorder(),
                                                  splashColor: AppPalette.green
                                                      .withValues(alpha: 0.24),
                                                  highlightColor: AppPalette.green
                                                      .withValues(alpha: 0.16),
                                                  onHighlightChanged: (v) {
                                                    setInnerState(() {
                                                      isPressed = v;
                                                    });
                                                  },
                                                  onTap: () {
                                                    final next = isKorToJp
                                                        ? QuizPromptMode.jpToKor
                                                        : QuizPromptMode.korToJp;
                                                    ref
                                                        .read(
                                                          quizPromptModeProvider
                                                              .notifier,
                                                        )
                                                        .setMode(next);
                                                  },
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: AppPalette.green
                                                            .withValues(
                                                              alpha: isPressed
                                                                  ? 0.54
                                                                  : 0.38,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.swap_horiz_rounded,
                                                      size: 19,
                                                      color: AppPalette.navy
                                                          .withValues(alpha: 0.82),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('정답', style: panelDescStyle),
                                        const SizedBox(height: 4),
                                        Text(
                                          answerLabel,
                                          style: panelTitleStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: alarmQuizCountAsync.when(
                loading: () => const ListTile(
                  title: Text('알람 시 문제 개수'),
                  subtitle: Text('불러오는 중…'),
                ),
                error: (e, _) => ListTile(
                  title: const Text('알람 시 문제 개수'),
                  subtitle: Text('설정을 불러오지 못했습니다.\n$e'),
                ),
                data: (count) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '알람 시 문제 개수',
                        style: panelTitleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '설정한 개수만큼 연속으로 맞혀야 알람을 끌 수 있어요.',
                        style: panelDescStyle,
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(value: 1, label: Text('1개')),
                          ButtonSegment<int>(value: 2, label: Text('2개')),
                          ButtonSegment<int>(value: 3, label: Text('3개')),
                        ],
                        selected: {count},
                        onSelectionChanged: (next) {
                          final v = next.first;
                          ref
                              .read(alarmQuizQuestionCountProvider.notifier)
                              .setCount(v);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '카테고리 · 레벨',
              style: sectionTitleStyle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '카테고리를 모두 켜 두면 전체에서 출제됩니다. 펼친 뒤 레벨을 일부만 켜 두면 그 카테고리는 선택한 레벨만 출제됩니다.',
              style: panelDescStyle,
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
                  return categoryLevelsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('레벨 설정을 불러오지 못했습니다.\n$e'),
                    ),
                    data: (levelsByCategory) {
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
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < allCats.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _CategoryLevelExpansionTile(
                                category: allCats[i],
                                entries: entries,
                                savedCategories: savedCategories,
                                levelsByCategory: levelsByCategory,
                                onToggleCategory: (checked) => _toggleQuizCategory(
                                  ref: ref,
                                  context: context,
                                  category: allCats[i],
                                  checked: checked,
                                  allSorted: allCats,
                                  saved: savedCategories,
                                ),
                                onToggleLevel: (level, checked) => _toggleLevelForCategory(
                                  ref: ref,
                                  context: context,
                                  category: allCats[i],
                                  level: level,
                                  checked: checked,
                                  allSorted: _sortedLevelsForCategory(entries, allCats[i]),
                                  restricted: levelsByCategory[allCats[i]] ?? {},
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
              style: sectionTitleStyle,
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
                  style: panelDescStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLevelExpansionTile extends StatelessWidget {
  const _CategoryLevelExpansionTile({
    required this.category,
    required this.entries,
    required this.savedCategories,
    required this.levelsByCategory,
    required this.onToggleCategory,
    required this.onToggleLevel,
  });

  final String category;
  final List<QuizEntry> entries;
  final Set<String> savedCategories;
  final Map<String, Set<String>> levelsByCategory;
  final void Function(bool? checked) onToggleCategory;
  final void Function(String level, bool? checked) onToggleLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryOn =
        savedCategories.isEmpty || savedCategories.contains(category);
    final levels = _sortedLevelsForCategory(entries, category);
    final restricted = levelsByCategory[category] ?? {};

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(10, 2, 14, 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        collapsedBackgroundColor: AppPalette.beigeContainer.withValues(alpha: 0.35),
        backgroundColor: AppPalette.beigeContainer.withValues(alpha: 0.50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Checkbox(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: categoryOn,
          onChanged: onToggleCategory,
        ),
        title: Text(
          category,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: levels.isEmpty
            ? Text(
                'level 값 없음',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Text(
                restricted.isEmpty
                    ? '전체 레벨 출제'
                    : '레벨 ${restricted.length}/${levels.length}개만 출제',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        children: [
          if (levels.isEmpty)
            ListTile(
              dense: true,
              title: Text(
                '시트에 level 열을 채우면 여기서 고를 수 있어요.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            ...levels.map(
              (lv) => CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('레벨 $lv'),
                value: restricted.isEmpty || restricted.contains(lv),
                onChanged:
                    categoryOn ? (c) => onToggleLevel(lv, c) : null,
              ),
            ),
        ],
      ),
    );
  }
}
