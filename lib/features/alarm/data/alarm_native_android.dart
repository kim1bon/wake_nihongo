import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';

/// Android: [AlarmManager] + 포그라운드 서비스 무한 루프와 동기화합니다. iOS에서는 no-op.
class AlarmNativeAndroid {
  AlarmNativeAndroid._();

  static const _ch = MethodChannel('com.example.wake_nihongo/alarm_native');

  static Future<void> syncAlarms(List<Alarm> alarms) async {
    if (!Platform.isAndroid) return;
    final list = alarms.map((a) {
      return {
        'id': a.id,
        'hour': a.hour,
        'minute': a.minute,
        'enabled': a.enabled,
        'weekdays': (a.weekdays.toList()..sort()),
        'androidRaw': AlarmSoundIds.androidRawName(a.soundId),
      };
    }).toList();
    await _ch.invokeMethod<void>('syncAlarms', jsonEncode(list));
  }

  static Future<void> stopRinging() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod<void>('stopRinging');
  }

  /// MainActivity가 포그라운드 서비스 알림에서 열렸을 때 1회 페이로드.
  static Future<Map<String, dynamic>?> takePendingAlarmLaunch() async {
    if (!Platform.isAndroid) return null;
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>?>('takePendingAlarmLaunch');
    if (m == null) return null;
    return m.map((k, v) => MapEntry(k as String, v));
  }
}
