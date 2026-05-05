import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/constants/alarm_weekdays.dart';
import '../../../core/theme/theme.dart';
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
  static const String _soundModePopupHideUntilKey =
      'alarm_sound_mode_popup_hide_until_v1';

  late TimeOfDay _time;
  late Set<int> _weekdays;
  late String _soundId;
  late bool _rescheduleEnabled;
  late int _rescheduleDelayMinutes;
  late int _rescheduleMaxCount;

  late final FixedExtentScrollController _delayPickController;
  late final FixedExtentScrollController _countPickController;

  static const _pickerItemExtent = 36.0;
  static const _pickerVisibleHeight = 180.0;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlarm;
    if (a != null) {
      _time = TimeOfDay(hour: a.hour, minute: a.minute);
      _weekdays = Set<int>.from(a.weekdays);
      _soundId = AlarmSoundIds.isValid(a.soundId) ? a.soundId : AlarmSoundIds.defaultId;
      _rescheduleEnabled = a.rescheduleEnabled;
      _rescheduleDelayMinutes = a.rescheduleDelayMinutes.clamp(1, 15);
      _rescheduleMaxCount = a.rescheduleMaxCount.clamp(1, 10);
    } else {
      _time = const TimeOfDay(hour: 7, minute: 0);
      _weekdays = {};
      _soundId = AlarmSoundIds.defaultId;
      _rescheduleEnabled = false;
      _rescheduleDelayMinutes = 5;
      _rescheduleMaxCount = 3;
    }
    _delayPickController = FixedExtentScrollController(
      initialItem: (_rescheduleDelayMinutes - 1).clamp(0, 14),
    );
    _countPickController = FixedExtentScrollController(
      initialItem: (_rescheduleMaxCount - 1).clamp(0, 9),
    );
  }

  @override
  void dispose() {
    _delayPickController.dispose();
    _countPickController.dispose();
    super.dispose();
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

    if (await _shouldShowSoundModePopup()) {
      final hideFor30Days = await _showSoundModePopup();
      if (hideFor30Days) {
        final prefs = await SharedPreferences.getInstance();
        final hideUntil = DateTime.now().add(const Duration(days: 30));
        await prefs.setInt(
          _soundModePopupHideUntilKey,
          hideUntil.millisecondsSinceEpoch,
        );
      }
    }

    final notifier = ref.read(alarmsNotifierProvider.notifier);
    final initial = widget.initialAlarm;
    if (initial == null) {
      await notifier.create(
        hour: _time.hour,
        minute: _time.minute,
        weekdays: Set<int>.from(_weekdays),
        soundId: _soundId,
        rescheduleEnabled: _rescheduleEnabled,
        rescheduleDelayMinutes: _rescheduleDelayMinutes,
        rescheduleMaxCount: _rescheduleMaxCount,
      );
    } else {
      await notifier.updateAlarm(
        id: initial.id,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: Set<int>.from(_weekdays),
        soundId: _soundId,
        rescheduleEnabled: _rescheduleEnabled,
        rescheduleDelayMinutes: _rescheduleDelayMinutes,
        rescheduleMaxCount: _rescheduleMaxCount,
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _shouldShowSoundModePopup() async {
    final prefs = await SharedPreferences.getInstance();
    final hideUntilMs = prefs.getInt(_soundModePopupHideUntilKey);
    if (hideUntilMs == null) return true;
    final hideUntil = DateTime.fromMillisecondsSinceEpoch(hideUntilMs);
    return DateTime.now().isAfter(hideUntil);
  }

  Future<bool> _showSoundModePopup() async {
    var hideFor30Days = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
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
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              actionsPadding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
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
                      Icons.notifications_active_outlined,
                      size: 20,
                      color: AppPalette.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '알람 소리 안내',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.navy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: AppPalette.beigeContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppPalette.green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'iOS에서는 무음 상태일 때 알람 소리가 재생되지 않을 수 있습니다. '
                        '알람을 사용할 때는 기기를 소리 모드로 전환해 주세요.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setDialogState(() {
                          hideFor30Days = !hideFor30Days;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: hideFor30Days,
                              side: BorderSide(
                                color: AppPalette.green.withValues(alpha: 0.6),
                              ),
                              onChanged: (v) {
                                setDialogState(() {
                                  hideFor30Days = v ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                '해당 팝업 30일간 보이지 않기',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppPalette.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(hideFor30Days),
                    child: const Text('확인'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      _time,
      alwaysUse24HourFormat: false,
    );

    final rescheduleHeaderStyle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.onSurface,
      fontSize: 17,
      fontWeight: FontWeight.w500,
    );
    final rescheduleAccentStyle = rescheduleHeaderStyle?.copyWith(
      color: AppPalette.green,
      fontWeight: FontWeight.w600,
    );
    final rescheduleMutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppPalette.onSurfaceVariantTone,
      fontSize: 13,
    );
    final reschedulePanelDecoration = BoxDecoration(
      color: AppPalette.beigeContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppPalette.green.withValues(alpha: 0.38),
      ),
    );
    final pickerCupertinoTheme = CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: AppPalette.green,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: AppPalette.navy,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
    final pickerSelectionOverlay = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.symmetric(
            horizontal: BorderSide(
              color: AppPalette.green.withValues(alpha: 0.42),
            ),
          ),
        ),
        child: const SizedBox.expand(),
      ),
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
            subtitle: Text(AlarmSoundIds.label(_soundId)),
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
          const SizedBox(height: 24),
          Text('다시 알림', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '알람이 울릴 때 연기할 수 있습니다. 횟수를 다 쓰면 퀴즈로만 끌 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('다시 알림 사용'),
            subtitle: const Text('끄면 연기 시간·횟수 설정이 비활성화됩니다.'),
            value: _rescheduleEnabled,
            onChanged: (v) => setState(() => _rescheduleEnabled = v),
          ),
          if (_rescheduleEnabled) ...[
            const SizedBox(height: 12),
            Container(
              decoration: reschedulePanelDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '다시 알림 연기 시간',
                            style: rescheduleHeaderStyle,
                          ),
                        ),
                        Text(
                          '$_rescheduleDelayMinutes분',
                          style: rescheduleAccentStyle,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _pickerVisibleHeight,
                    child: CupertinoTheme(
                      data: pickerCupertinoTheme,
                      child: CupertinoPicker(
                        scrollController: _delayPickController,
                        itemExtent: _pickerItemExtent,
                        magnification: 1.05,
                        squeeze: 1.05,
                        useMagnifier: true,
                        selectionOverlay: pickerSelectionOverlay,
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _rescheduleDelayMinutes = index + 1;
                          });
                        },
                        children: [
                          for (var m = 1; m <= 15; m++)
                            Center(child: Text('$m분')),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppPalette.navy.withValues(alpha: 0.10),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '다시 알림 횟수',
                            style: rescheduleHeaderStyle,
                          ),
                        ),
                        Text(
                          '$_rescheduleMaxCount회',
                          style: rescheduleAccentStyle,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                      '한 번 울릴 때 최대 몇 번 연기할 수 있는지',
                      style: rescheduleMutedStyle,
                    ),
                  ),
                  SizedBox(
                    height: _pickerVisibleHeight,
                    child: CupertinoTheme(
                      data: pickerCupertinoTheme,
                      child: CupertinoPicker(
                        scrollController: _countPickController,
                        itemExtent: _pickerItemExtent,
                        magnification: 1.05,
                        squeeze: 1.05,
                        useMagnifier: true,
                        selectionOverlay: pickerSelectionOverlay,
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _rescheduleMaxCount = index + 1;
                          });
                        },
                        children: [
                          for (var n = 1; n <= 10; n++)
                            Center(child: Text('$n회')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
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
