import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/constants/alarm_weekdays.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';
import '../../quiz/presentation/quiz_practice_screen.dart';
import '../domain/alarm.dart';
import 'add_alarm_screen.dart';
import 'alarm_providers.dart';

class AlarmListScreen extends ConsumerStatefulWidget {
  const AlarmListScreen({super.key});

  @override
  ConsumerState<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends ConsumerState<AlarmListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(alarmRepositoryProvider).ensureNotificationPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarmsAsync = ref.watch(alarmsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm, color: theme.colorScheme.onSurface),
            SizedBox(width: context.w(8)),
            const Text('알람'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '일본어 퀴즈',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const QuizPracticeScreen(),
                ),
              );
            },
            icon: const Icon(Icons.quiz_outlined),
          ),
        ],
      ),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return const Center(
              child: Text('알람이 없습니다.\n+ 버튼으로 알람을 추가하세요.'),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              context.w(12),
              context.h(8),
              context.w(12),
              context.h(12),
            ),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return Padding(
                padding: EdgeInsets.only(bottom: context.h(8)),
                child: _AlarmTile(
                  alarm: alarm,
                  onEdit: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => AddAlarmScreen(initialAlarm: alarm),
                      ),
                    );
                    ref.invalidate(alarmsNotifierProvider);
                  },
                  onDelete: () => ref.read(alarmsNotifierProvider.notifier).remove(alarm.id),
                  onEnabledChanged: (enabled) => ref
                      .read(alarmsNotifierProvider.notifier)
                      .setAlarmEnabled(alarm.id, enabled),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const AddAlarmScreen()),
          );
          ref.invalidate(alarmsNotifierProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({
    required this.alarm,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  final Alarm alarm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;

  static const _weekdayShort = ['', '월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    final label = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: false);
    final days = alarm.weekdays.toList()..sort();
    final dayLabel = days.isEmpty
        ? '1회'
        : AlarmWeekdays.isEveryDay(alarm.weekdays)
            ? '매일'
            : days.map((d) => _weekdayShort[d]).join(', ');

    final soundLabel = AlarmSoundIds.label(alarm.soundId);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: EdgeInsets.fromLTRB(
          context.w(14),
          context.h(6),
          context.w(8),
          context.h(6),
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: alarm.enabled ? AppPalette.navy : disabledColor,
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: context.h(2)),
          child: Text(
            '반복: $dayLabel · 알람음: $soundLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: alarm.enabled
                      ? AppPalette.navy.withValues(alpha: 0.78)
                      : disabledColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: alarm.enabled,
              onChanged: onEnabledChanged,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: '수정',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }
}
