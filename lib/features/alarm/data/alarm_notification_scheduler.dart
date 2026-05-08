import 'dart:io';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/alarm_sound_ids.dart';
import 'alarm_native_android.dart';
import '../domain/alarm.dart';
import '../domain/alarm_payload_kind.dart';

/// Schedules alarms. Android: per-sound notification channel + `res/raw` tone + alarm usage.
/// iOS: bundled `basic.mp3` ... `ghibli_style.mp3` in Runner. See [AlarmSoundIds].
class AlarmNotificationScheduler {
  AlarmNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _appNotificationTitle = '일어나';

  static const _channelDescription = '일어나 알람 (알람 볼륨)';
  static const _iosMaxPendingNotifications = 64;
  static const _iosSnoozeMaxCount = 10;
  static const _iosRepeatSlots = _iosSnoozeMaxCount + 1;
  static const _iosRepeatInterval = Duration(minutes: 5);

  static int notificationId(int alarmId, int weekday) => alarmId * 10 + weekday;
  static int _iosSlotNotificationId(int alarmId, int weekday, int slot) =>
      alarmId * 100 + (weekday * 10) + slot;

  /// 「다시 알림」일회 예약용. 주간 슬롯·iOS 체인 ID와 겹치지 않도록 큰 베이스를 둡니다.
  static int rescheduleNotificationId(int alarmId) => 800000000 + alarmId;

  String _androidChannelId(String soundId) =>
      'wake_nihongo_${AlarmSoundIds.channelSuffix(soundId)}';

  bool _isAndroidScheduledDataCorruptionError(Object error) {
    if (!Platform.isAndroid || error is! PlatformException) return false;
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    final details = '${error.details}'.toLowerCase();
    return code.contains('error') &&
        (message.contains('missing type parameter') ||
            details.contains('missing type parameter'));
  }

  Future<void> _runWithAndroidScheduledDataRecovery(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!_isAndroidScheduledDataCorruptionError(error)) rethrow;
      // cancelAll()도 동일 오류로 실패할 수 있어 네이티브에서 직접 캐시를 정리합니다.
      await AlarmNativeAndroid.clearCorruptedScheduledNotificationCache();
      await action();
    }
  }

  /// 앱 시작 시 Android 예약 캐시 손상 여부를 선제 점검/복구합니다.
  Future<void> healAndroidScheduledDataIfNeeded() async {
    if (!Platform.isAndroid) return;
    await _runWithAndroidScheduledDataRecovery(() async {
      await _plugin.pendingNotificationRequests();
    });
  }

  Future<void> init({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final soundId in AlarmSoundIds.all) {
      final raw = AlarmSoundIds.androidRawName(soundId);
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _androidChannelId(soundId),
          '알람 (${AlarmSoundIds.label(soundId)})',
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(raw),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
  }

  Future<void> ensurePermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestFullScreenIntentPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> cancel(Alarm alarm) async {
    await cancelAllSlotsForAlarmId(alarm.id);
  }

  /// Clears all weekday slots for this alarm id (1–7). Use when weekdays may have changed.
  Future<void> cancelAllSlotsForAlarmId(int alarmId) async {
    // 0: Android 1회 알람 슬롯(네이티브와 동일한 requestCode 규칙). 1–7: 요일 반복.
    for (var weekday = 0; weekday <= 7; weekday++) {
      await _plugin.cancel(notificationId(alarmId, weekday));
      for (var slot = 0; slot < _iosRepeatSlots; slot++) {
        await _plugin.cancel(_iosSlotNotificationId(alarmId, weekday, slot));
      }
    }
    await cancelRescheduleForAlarmId(alarmId);
  }

  Future<void> cancelRescheduleForAlarmId(int alarmId) async {
    await _plugin.cancel(rescheduleNotificationId(alarmId));
  }

  /// 앱이 꺼져 있어도 [delayMinutes] 후 알람 UI로 이어지도록 로컬 알림 1회 예약.
  Future<void> scheduleReschedule({
    required int alarmId,
    required String soundId,
    required int delayMinutes,
  }) async {
    await _runWithAndroidScheduledDataRecovery(() async {
      if (alarmId < 0) return;
      final sid = AlarmSoundIds.isValid(soundId)
          ? soundId
          : AlarmSoundIds.defaultId;
      final rawName = AlarmSoundIds.androidRawName(sid);
      final channelId = _androidChannelId(sid);
      final when = tz.TZDateTime.now(tz.local).add(
        Duration(minutes: delayMinutes),
      );

      final androidDetails = AndroidNotificationDetails(
        channelId,
        '알람 (${AlarmSoundIds.label(sid)})',
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: RawResourceAndroidNotificationSound(rawName),
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: false,
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        sound: AlarmSoundIds.iosFileName(sid),
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'alarmId': alarmId,
        'soundId': sid,
        'kind': AlarmPayloadKind.reschedule.name,
      });

      if (Platform.isIOS) {
        final pending = await _plugin.pendingNotificationRequests();
        if (pending.length >= _iosMaxPendingNotifications) return;
      }

      await _plugin.zonedSchedule(
        rescheduleNotificationId(alarmId),
        _appNotificationTitle,
        '$delayMinutes분 후 다시 알려드릴게요.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    });
  }

  Future<void> schedule(Alarm alarm) async {
    await _runWithAndroidScheduledDataRecovery(() async {
      if (!alarm.enabled) return;

      // 빈 요일: Android는 AlarmManager(네이티브)만 1회 예약. iOS는 절대 시각 1회(5분 간격 체인) 로컬 알림.
      if (alarm.weekdays.isEmpty) {
        if (Platform.isIOS) {
          await _scheduleIosOneShotChain(alarm);
        }
        return;
      }

      final soundId = AlarmSoundIds.isValid(alarm.soundId)
          ? alarm.soundId
          : AlarmSoundIds.defaultId;
      final rawName = AlarmSoundIds.androidRawName(soundId);
      final channelId = _androidChannelId(soundId);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        '알람 (${AlarmSoundIds.label(soundId)})',
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: RawResourceAndroidNotificationSound(rawName),
        // 무한 루프는 네이티브 포그라운드 서비스(MediaPlayer)에서 재생 — 짧은 알림음 중복 방지
        playSound: false,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: false,
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        sound: AlarmSoundIds.iosFileName(soundId),
        // iOS 전달 우선순위를 높여 Focus 환경에서도 알림 도달 가능성을 높입니다.
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'alarmId': alarm.id,
        'soundId': soundId,
        'kind': AlarmPayloadKind.weekly.name,
      });

      var iosBudget = 0;
      if (Platform.isIOS) {
        final pending = await _plugin.pendingNotificationRequests();
        iosBudget = _iosMaxPendingNotifications - pending.length;
        if (iosBudget <= 0) return;
      }

      for (final weekday in alarm.weekdays) {
        final firstWhen = _nextInstanceOfWeekday(
          weekday,
          alarm.hour,
          alarm.minute,
        );
        if (Platform.isIOS) {
          // iOS는 Android처럼 OS 레벨 무한 루프 재생이 어려워, 5분 간격 재알림 체인을 예약합니다.
          for (var slot = 0; slot < _iosRepeatSlots; slot++) {
            if (iosBudget <= 0) return;
            final when = firstWhen.add(_iosRepeatInterval * slot);
            await _plugin.zonedSchedule(
              _iosSlotNotificationId(alarm.id, weekday, slot),
              _appNotificationTitle,
              '알람 시간입니다. 앱을 열어 알람을 끄세요.',
              when,
              details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: payload,
            );
            iosBudget--;
          }
        } else {
          await _plugin.zonedSchedule(
            notificationId(alarm.id, weekday),
            _appNotificationTitle,
            '알람 시간입니다. 앱을 열어 알람을 끄세요.',
            firstWhen,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload,
          );
        }
      }
    });
  }

  /// 요일 미선택(1회): iOS는 주간 반복 없이 다음 시각부터 5분 간격 체인만 예약합니다.
  Future<void> _scheduleIosOneShotChain(Alarm alarm) async {
    final soundId = AlarmSoundIds.isValid(alarm.soundId)
        ? alarm.soundId
        : AlarmSoundIds.defaultId;
    final rawName = AlarmSoundIds.androidRawName(soundId);
    final channelId = _androidChannelId(soundId);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      '알람 (${AlarmSoundIds.label(soundId)})',
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: RawResourceAndroidNotificationSound(rawName),
      playSound: false,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: false,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: AlarmSoundIds.iosFileName(soundId),
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'alarmId': alarm.id,
      'soundId': soundId,
      'kind': AlarmPayloadKind.weekly.name,
    });

    final pending = await _plugin.pendingNotificationRequests();
    var iosBudget = _iosMaxPendingNotifications - pending.length;
    if (iosBudget <= 0) return;

    final firstWhen = _nextInstanceOfTime(alarm.hour, alarm.minute);

    for (var slot = 0; slot < _iosRepeatSlots; slot++) {
      if (iosBudget <= 0) return;
      final when = firstWhen.add(_iosRepeatInterval * slot);
      await _plugin.zonedSchedule(
        _iosSlotNotificationId(alarm.id, 0, slot),
        _appNotificationTitle,
        '알람 시간입니다. 앱을 열어 알람을 끄세요.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      iosBudget--;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }
}
