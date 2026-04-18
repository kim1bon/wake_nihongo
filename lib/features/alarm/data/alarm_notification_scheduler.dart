import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';
/// Schedules alarms. Android: per-sound notification channel + `res/raw` tone + alarm usage.
/// iOS: bundled `Alram_0x.mp3` in Runner. See [AlarmSoundIds].
class AlarmNotificationScheduler {
  AlarmNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelDescription = 'WakeNihongo 알람 (알람 볼륨)';

  static int notificationId(int alarmId, int weekday) => alarmId * 10 + weekday;

  String _androidChannelId(String soundId) =>
      'wake_nihongo_${AlarmSoundIds.channelSuffix(soundId)}';

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
          '알람 ($soundId)',
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
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(notificationId(alarmId, weekday));
    }
  }

  Future<void> schedule(Alarm alarm) async {
    if (!alarm.enabled || alarm.weekdays.isEmpty) return;

    final soundId = AlarmSoundIds.isValid(alarm.soundId) ? alarm.soundId : AlarmSoundIds.defaultId;
    final rawName = AlarmSoundIds.androidRawName(soundId);
    final channelId = _androidChannelId(soundId);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      '알람 ($soundId)',
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
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode({
      'alarmId': alarm.id,
      'soundId': soundId,
    });

    for (final weekday in alarm.weekdays) {
      final when = _nextInstanceOfWeekday(weekday, alarm.hour, alarm.minute);
      await _plugin.zonedSchedule(
        notificationId(alarm.id, weekday),
        'WakeNihongo',
        '알람 시간입니다. 앱을 열어 알람을 끄세요.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
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
