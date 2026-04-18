import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/constants/alarm_weekdays.dart';
import '../domain/alarm.dart';
import 'alarm_providers.dart';
import 'alarm_sound_picker_sheet.dart';

class AddAlarmScreen extends ConsumerStatefulWidget {
  const AddAlarmScreen({super.key, this.initialAlarm});

  /// When set, screen acts as edit mode for this alarm.
  final Alarm? initialAlarm;

  @override
  ConsumerState<AddAlarmScreen> createState() => _AddAlarmScreenState();
}

class _AddAlarmScreenState extends ConsumerState<AddAlarmScreen> {
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late String _soundId;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlarm;
    if (a != null) {
      _time = TimeOfDay(hour: a.hour, minute: a.minute);
      _weekdays = Set<int>.from(a.weekdays);
      _soundId = AlarmSoundIds.isValid(a.soundId) ? a.soundId : AlarmSoundIds.defaultId;
    } else {
      _time = const TimeOfDay(hour: 7, minute: 0);
      _weekdays = {};
      _soundId = AlarmSoundIds.defaultId;
    }
  }

  static const _dayChips = [
    (1, '월'),
    (2, '화'),
    (3, '수'),
    (4, '목'),
    (5, '금'),
    (6, '토'),
    (7, '일'),
  ];

  bool get _everyDaySelected => AlarmWeekdays.isEveryDay(_weekdays);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 요일을 선택하세요.')),
      );
      return;
    }

    final notifier = ref.read(alarmsNotifierProvider.notifier);
    final initial = widget.initialAlarm;
    if (initial == null) {
      await notifier.create(
        hour: _time.hour,
        minute: _time.minute,
        weekdays: Set<int>.from(_weekdays),
        soundId: _soundId,
      );
    } else {
      await notifier.updateAlarm(
        id: initial.id,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: Set<int>.from(_weekdays),
        soundId: _soundId,
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      _time,
      alwaysUse24HourFormat: false,
    );

    final isEdit = widget.initialAlarm != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '알람 수정' : '알람 추가')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('시간'),
            subtitle: Text(timeLabel),
            trailing: const Icon(Icons.schedule),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('알람음'),
            subtitle: Text(_soundId),
            trailing: const Icon(Icons.music_note_outlined),
            onTap: () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => AlarmSoundPickerSheet(initialSoundId: _soundId),
              );
              if (chosen != null) {
                setState(() => _soundId = chosen);
              }
            },
          ),
          const SizedBox(height: 16),
          Text('반복 요일', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('매일'),
                selected: _everyDaySelected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _weekdays = Set<int>.from(AlarmWeekdays.all);
                    } else {
                      _weekdays.clear();
                    }
                  });
                },
              ),
              ..._dayChips.map((e) {
                final day = e.$1;
                final label = e.$2;
                final selected = _weekdays.contains(day);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _weekdays.add(day);
                      } else {
                        _weekdays.remove(day);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ),
      ),
    );
  }
}
