import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';

/// Android: [AlarmManager] + 포그라운드 서비스 무한 루프와 동기화합니다. iOS에서는 no-op.
class AlarmNativeAndroid {
  AlarmNativeAndroid._();

  static const _ch = MethodChannel('com.bon.nihongona/alarm_native');
  static const _methodOnAlarmLaunchIntent = 'onAlarmLaunchIntent';

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

  static Future<void> stopRinging({int alarmId = -1}) async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod<void>('stopRinging', {'alarmId': alarmId});
  }

  static Future<bool> isRinging() async {
    if (!Platform.isAndroid) return false;
    final v = await _ch.invokeMethod<bool>('isRinging');
    return v ?? false;
  }

  /// 네이티브 서비스가 꺼진 pending 복원 시 재생을 다시 시작합니다.
  static Future<void> ensureRinging({
    required int alarmId,
    required String soundId,
  }) async {
    if (!Platform.isAndroid) return;
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    await _ch.invokeMethod<void>('ensureRinging', {
      'alarmId': alarmId,
      'soundId': sid,
      'raw': AlarmSoundIds.androidRawName(sid),
    });
  }

  /// flutter_local_notifications의 손상된 예약 캐시를 Android 네이티브에서 정리합니다.
  static Future<void> clearCorruptedScheduledNotificationCache() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod<void>('clearCorruptedScheduledNotificationCache');
  }

  /// MainActivity가 포그라운드 서비스 알림에서 열렸을 때 1회 페이로드.
  static Future<Map<String, dynamic>?> takePendingAlarmLaunch() async {
    if (!Platform.isAndroid) return null;
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>?>('takePendingAlarmLaunch');
    if (m == null) return null;
    return m.map((k, v) => MapEntry(k as String, v));
  }

  /// MainActivity.onNewIntent(알람 포그라운드 서비스 인텐트) 이벤트를 즉시 수신합니다.
  static Future<void> bindAlarmLaunchIntentListener(
    Future<void> Function(Map<String, dynamic> payload) onLaunch,
  ) async {
    if (!Platform.isAndroid) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method != _methodOnAlarmLaunchIntent) return;
      final args = call.arguments;
      if (args is! Map) return;
      final payload = args.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      await onLaunch(payload);
    });
  }
}
