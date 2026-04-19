import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alarm/presentation/alarm_providers.dart';
import 'quiz_alarm_types_notifier.dart';

/// 알람 관련 안내·권한, 알람 해제 시 퀴즈 유형(시트 `type`) 설정.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(quizAlarmEnabledTypesProvider);

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
              '알람을 끌 때 출제되는 일본어 문제의 유형입니다. 시트의「type」열과 같습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }
}
