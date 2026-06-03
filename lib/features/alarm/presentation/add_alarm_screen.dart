import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/constants/alarm_weekdays.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';
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
  late bool _repeatEnabled;
  late String _soundId;
  late bool _rescheduleEnabled;
  late int _rescheduleDelayMinutes;
  late int _rescheduleMaxCount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlarm;
    if (a != null) {
      _time = TimeOfDay(hour: a.hour, minute: a.minute);
      _weekdays = Set<int>.from(a.weekdays);
      _repeatEnabled = a.weekdays.isNotEmpty;
      _soundId = AlarmSoundIds.isValid(a.soundId)
          ? a.soundId
          : AlarmSoundIds.defaultId;
      _rescheduleEnabled = a.rescheduleEnabled;
      _rescheduleDelayMinutes = a.rescheduleDelayMinutes.clamp(1, 15);
      _rescheduleMaxCount = a.rescheduleMaxCount.clamp(1, 10);
    } else {
      _time = const TimeOfDay(hour: 7, minute: 0);
      _weekdays = {};
      _repeatEnabled = false;
      _soundId = AlarmSoundIds.defaultId;
      _rescheduleEnabled = true;
      _rescheduleDelayMinutes = 5;
      _rescheduleMaxCount = 5;
    }
  }

  @override
  void dispose() {
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

  int _to12Hour(int hour24) {
    final h = hour24 % 12;
    return h == 0 ? 12 : h;
  }

  int _to24Hour({required int hour12, required bool isPm}) {
    if (isPm) return hour12 == 12 ? 12 : hour12 + 12;
    return hour12 == 12 ? 0 : hour12;
  }

  Future<void> _pickTime() async {
    final picked = await showDialog<TimeOfDay>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _JapaneseDialTimePickerDialog(
        initial: _time,
        to12Hour: _to12Hour,
        to24Hour: _to24Hour,
      ),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Set<int> get _weekdaysToSave =>
      _repeatEnabled ? Set<int>.from(_weekdays) : <int>{};

  Future<void> _save() async {
    if (_isSaving) return;
    if (_repeatEnabled && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반복 알람을 켠 경우 요일을 하나 이상 선택해 주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
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
          weekdays: _weekdaysToSave,
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
          weekdays: _weekdaysToSave,
          soundId: _soundId,
          rescheduleEnabled: _rescheduleEnabled,
          rescheduleDelayMinutes: _rescheduleDelayMinutes,
          rescheduleMaxCount: _rescheduleMaxCount,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (mounted) {
        final detail = 'PlatformException/Runtime 로그:\n$e\n\nStackTrace:\n$st';
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('알람 저장 실패'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: SelectableText(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _shouldShowSoundModePopup() async {
    if (!Platform.isIOS) return false;
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
    final timeLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(_time, alwaysUse24HourFormat: false);

    final isEdit = widget.initialAlarm != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '알람 수정' : '알람 추가')),
      body: ListView(
        padding: EdgeInsets.all(context.w(16)),
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(context.r(14)),
              onTap: _pickTime,
              child: Ink(
                decoration: BoxDecoration(
                  color: AppPalette.beigeContainer,
                  borderRadius: BorderRadius.circular(context.r(14)),
                  border: Border.all(
                    color: AppPalette.green.withValues(alpha: 0.35),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  context.w(14),
                  context.h(14),
                  context.w(12),
                  context.h(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.r(38),
                      height: context.r(38),
                      decoration: BoxDecoration(
                        color: AppPalette.green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(context.r(10)),
                      ),
                      child: const Icon(
                        Icons.watch_later_outlined,
                        color: AppPalette.green,
                        size: 21,
                      ),
                    ),
                    SizedBox(width: context.w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '時間 / じかん',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppPalette.onSurfaceVariantTone,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: context.h(4)),
                          Text(
                            timeLabel,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppPalette.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: context.h(2)),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppPalette.navy.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: context.h(8)),
          ListTile(
            title: const Text('알람음'),
            subtitle: Text(AlarmSoundIds.label(_soundId)),
            trailing: const Icon(Icons.music_note_outlined),
            onTap: () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) =>
                    AlarmSoundPickerSheet(initialSoundId: _soundId),
              );
              if (chosen != null) {
                setState(() => _soundId = chosen);
              }
            },
          ),
          SizedBox(height: context.h(16)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '반복 알람',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              _repeatEnabled
                  ? '선택한 요일마다 알람이 울립니다.'
                  : '설정한 시간에 한 번만 울립니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.onSurfaceVariantTone,
                  ),
            ),
            value: _repeatEnabled,
            activeThumbColor: AppPalette.green,
            onChanged: (v) {
              setState(() => _repeatEnabled = v);
            },
          ),
          if (_repeatEnabled) ...[
            SizedBox(height: context.h(8)),
            Text('반복 요일', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: context.h(8)),
            Wrap(
              spacing: context.w(8),
              runSpacing: context.h(8),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.w(16)),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('저장'),
          ),
        ),
      ),
    );
  }
}

enum _DialSelectMode { hour, minute }

enum _TimeInputMode { dial, keyboard }

class _JapaneseDialTimePickerDialog extends StatefulWidget {
  const _JapaneseDialTimePickerDialog({
    required this.initial,
    required this.to12Hour,
    required this.to24Hour,
  });

  final TimeOfDay initial;
  final int Function(int hour24) to12Hour;
  final int Function({required int hour12, required bool isPm}) to24Hour;

  @override
  State<_JapaneseDialTimePickerDialog> createState() =>
      _JapaneseDialTimePickerDialogState();
}

class _JapaneseDialTimePickerDialogState
    extends State<_JapaneseDialTimePickerDialog> {
  late int _hour12;
  late int _minute;
  late bool _isPm;
  _DialSelectMode _mode = _DialSelectMode.hour;
  _TimeInputMode _inputMode = _TimeInputMode.dial;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour12 = widget.to12Hour(widget.initial.hour);
    _minute = widget.initial.minute;
    _isPm = widget.initial.hour >= 12;
    _hourController = TextEditingController(
      text: _hour12.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: _minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String get _preview =>
      '${_isPm ? '오후' : '오전'} $_hour12:${_minute.toString().padLeft(2, '0')}';

  void _syncTextFields() {
    final hourText = _hour12.toString().padLeft(2, '0');
    final minuteText = _minute.toString().padLeft(2, '0');
    if (_hourController.text != hourText) _hourController.text = hourText;
    if (_minuteController.text != minuteText) {
      _minuteController.text = minuteText;
    }
  }

  void _onHourTextChanged(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    final clamped = parsed.clamp(1, 12);
    if (clamped != _hour12) {
      setState(() => _hour12 = clamped);
    }
  }

  void _onMinuteTextChanged(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, 59);
    if (clamped != _minute) {
      setState(() => _minute = clamped);
    }
  }

  Widget _buildKeyboardInput(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppPalette.beigeContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.green.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _hourController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                labelText: '시 (1~12)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onHourTextChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: textTheme.headlineSmall?.copyWith(
                color: AppPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _minuteController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                labelText: '분 (0~59)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onMinuteTextChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeToken({
    required BuildContext context,
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.green.withValues(alpha: 0.16)
                : AppPalette.beigeContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppPalette.green.withValues(alpha: 0.75)
                  : AppPalette.navy.withValues(alpha: 0.12),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeridiemButton({
    required BuildContext context,
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.green.withValues(alpha: 0.16)
                : AppPalette.beigeContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppPalette.green.withValues(alpha: 0.75)
                  : AppPalette.navy.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppPalette.navy,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _onDialChanged(double angle) {
    setState(() {
      if (_mode == _DialSelectMode.hour) {
        var index = (angle / (2 * math.pi) * 12).round() % 12;
        _hour12 = index == 0 ? 12 : index;
      } else {
        _minute = ((angle / (2 * math.pi) * 60).round() % 60);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogContentWidth = math.min(340.0, screenWidth - 56);
    final dialSize = math.min(250.0, screenHeight * 0.30);
    _syncTextFields();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      backgroundColor: AppPalette.beigeSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppPalette.green.withValues(alpha: 0.26)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppPalette.green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: AppPalette.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '時間 선택',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 74,
                      child: Column(
                        children: [
                          _buildMeridiemButton(
                            context: context,
                            text: '오전',
                            selected: !_isPm,
                            onTap: () => setState(() => _isPm = false),
                          ),
                          const SizedBox(height: 6),
                          _buildMeridiemButton(
                            context: context,
                            text: '오후',
                            selected: _isPm,
                            onTap: () => setState(() => _isPm = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        _buildTimeToken(
                          context: context,
                          text: _hour12.toString().padLeft(2, '0'),
                          selected: _mode == _DialSelectMode.hour,
                          onTap: () =>
                              setState(() => _mode = _DialSelectMode.hour),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ':',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppPalette.navy.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _buildTimeToken(
                          context: context,
                          text: _minute.toString().padLeft(2, '0'),
                          selected: _mode == _DialSelectMode.minute,
                          onTap: () =>
                              setState(() => _mode = _DialSelectMode.minute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _preview,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppPalette.navy.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_inputMode == _TimeInputMode.dial)
                _JapaneseDial(
                  mode: _mode,
                  hour12: _hour12,
                  minute: _minute,
                  dialSize: dialSize,
                  onChanged: _onDialChanged,
                )
              else
                _buildKeyboardInput(context),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            IconButton(
              tooltip: _inputMode == _TimeInputMode.dial ? '키보드 입력' : '다이얼 입력',
              onPressed: () {
                setState(() {
                  _inputMode = _inputMode == _TimeInputMode.dial
                      ? _TimeInputMode.keyboard
                      : _TimeInputMode.dial;
                });
              },
              icon: Icon(
                _inputMode == _TimeInputMode.dial
                    ? Icons.keyboard_outlined
                    : Icons.watch_later_outlined,
                color: AppPalette.green,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                final hour24 = widget.to24Hour(hour12: _hour12, isPm: _isPm);
                Navigator.of(
                  context,
                ).pop(TimeOfDay(hour: hour24, minute: _minute));
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ],
    );
  }
}

class _JapaneseDial extends StatelessWidget {
  const _JapaneseDial({
    required this.mode,
    required this.hour12,
    required this.minute,
    required this.dialSize,
    required this.onChanged,
  });

  final _DialSelectMode mode;
  final int hour12;
  final int minute;
  final double dialSize;
  final ValueChanged<double> onChanged;

  double get _selectedAngle {
    final base = mode == _DialSelectMode.hour ? (hour12 % 12) : minute;
    final count = mode == _DialSelectMode.hour ? 12 : 60;
    return (base / count) * 2 * math.pi;
  }

  double _offsetToAngle(Offset local, double size) {
    final c = Offset(size / 2, size / 2);
    final v = local - c;
    var rad = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (rad < 0) rad += 2 * math.pi;
    return rad;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => onChanged(_offsetToAngle(d.localPosition, dialSize)),
      onPanUpdate: (d) => onChanged(_offsetToAngle(d.localPosition, dialSize)),
      onTapDown: (d) => onChanged(_offsetToAngle(d.localPosition, dialSize)),
      child: SizedBox(
        width: dialSize,
        height: dialSize,
        child: CustomPaint(
          painter: _JapaneseDialPainter(
            mode: mode,
            selectedAngle: _selectedAngle,
          ),
        ),
      ),
    );
  }
}

class _JapaneseDialPainter extends CustomPainter {
  _JapaneseDialPainter({required this.mode, required this.selectedAngle});

  final _DialSelectMode mode;
  final double selectedAngle;
  static const List<String> _hourKanjiLabels = [
    '十二時',
    '一時',
    '二時',
    '三時',
    '四時',
    '五時',
    '六時',
    '七時',
    '八時',
    '九時',
    '十時',
    '十一時',
  ];
  static const List<String> _minuteKanjiLabels = [
    '零分',
    '五分',
    '十分',
    '十五分',
    '二十分',
    '二十五分',
    '三十分',
    '三十五分',
    '四十分',
    '四十五分',
    '五十分',
    '五十五分',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()..color = AppPalette.beigeContainer;
    final borderPaint = Paint()
      ..color = AppPalette.green.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawCircle(center, radius, borderPaint);

    final count = mode == _DialSelectMode.hour ? 12 : 60;
    final labelEvery = mode == _DialSelectMode.hour ? 1 : 5;
    for (var i = 0; i < count; i++) {
      final a = (i / count) * 2 * math.pi - math.pi / 2;
      final tickInner =
          center + Offset(math.cos(a), math.sin(a)) * (radius - 10);
      final tickOuter =
          center +
          Offset(math.cos(a), math.sin(a)) *
              (radius - (i % labelEvery == 0 ? 2 : 5));
      final tickPaint = Paint()
        ..color = AppPalette.navy.withValues(
          alpha: i % labelEvery == 0 ? 0.35 : 0.18,
        )
        ..strokeWidth = i % labelEvery == 0 ? 1.5 : 1;
      canvas.drawLine(tickInner, tickOuter, tickPaint);

      if (i % labelEvery == 0) {
        final isHourMode = mode == _DialSelectMode.hour;
        final label = isHourMode
            ? '${i == 0 ? 12 : i}'
            : i.toString().padLeft(2, '0');
        final numberTp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: AppPalette.navy.withValues(alpha: 0.82),
              fontSize: isHourMode ? 17 : 13,
              fontWeight: FontWeight.w600,
              fontFamily: AppFonts.japanese,
              fontFamilyFallback: AppFonts.fallbackAfterJapanese,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final jaTp = TextPainter(
          text: TextSpan(
            text: isHourMode ? _hourKanjiLabels[i] : _minuteKanjiLabels[i ~/ 5],
            style: TextStyle(
              color: AppPalette.navy.withValues(alpha: 0.58),
              fontSize: isHourMode ? 9 : 8.5,
              fontWeight: FontWeight.w500,
              fontFamily: AppFonts.japanese,
              fontFamilyFallback: AppFonts.fallbackAfterJapanese,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos =
            center +
            Offset(math.cos(a), math.sin(a)) * (radius - 26) -
            Offset(numberTp.width / 2, numberTp.height / 2);
        final numberDy = -3.5;
        numberTp.paint(canvas, pos.translate(0, numberDy));
        final jaPos = pos.translate(
          (numberTp.width - jaTp.width) / 2,
          numberTp.height - 1.5,
        );
        jaTp.paint(canvas, jaPos);
      }
    }

    final handEnd =
        center +
        Offset(
              math.cos(selectedAngle - math.pi / 2),
              math.sin(selectedAngle - math.pi / 2),
            ) *
            (radius - 34);
    final handPaint = Paint()
      ..color = AppPalette.green
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, handEnd, handPaint);
    canvas.drawCircle(handEnd, 7, Paint()..color = AppPalette.green);
    canvas.drawCircle(center, 5, Paint()..color = AppPalette.navy);
  }

  @override
  bool shouldRepaint(covariant _JapaneseDialPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.selectedAngle != selectedAngle;
  }
}
