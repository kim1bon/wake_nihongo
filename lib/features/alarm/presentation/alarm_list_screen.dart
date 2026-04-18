import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/constants/alarm_weekdays.dart';
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
    final alarmsAsync = ref.watch(alarmsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WakeNihongo')),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return const Center(
              child: Text('알람이 없습니다.\n+ 버튼으로 알람을 추가하세요.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: alarms.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return _AlarmTile(
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
                onEnabledChanged: (enabled) =>
                    ref.read(alarmsNotifierProvider.notifier).setAlarmEnabled(alarm.id, enabled),
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
    final time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    final label = MaterialLocalizations.of(context).formatTimeOfDay(time, alwaysUse24HourFormat: false);
    final days = alarm.weekdays.toList()..sort();
    final dayLabel = AlarmWeekdays.isEveryDay(alarm.weekdays)
        ? '매일'
        : days.map((d) => _weekdayShort[d]).join(', ');

    final soundLabel = AlarmSoundIds.isValid(alarm.soundId) ? alarm.soundId : AlarmSoundIds.defaultId;
    return ListTile(
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: alarm.enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
      ),
      subtitle: Text(
        '반복: $dayLabel · 알람음: $soundLabel',
        style: alarm.enabled
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
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
    );
  }
}
