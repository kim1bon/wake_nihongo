import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../alarm_ring_coordinator.dart';
import '../alarm_services.dart';
import '../pending_alarm_launch.dart';
import '../../features/alarm/data/alarm_local_data_source.dart';
import '../../features/alarm/data/alarm_notification_scheduler.dart';
import '../../features/alarm/data/alarm_repository_impl.dart';
import '../../features/alarm/data/alarm_ringtone_player.dart';
import '../../features/alarm/domain/alarm_repository.dart';

/// Wires local DB, timezone, and notification scheduling for the alarm feature.
class AppBootstrap {
  static Future<AlarmRepository> createAlarmRepository() async {
    tz_data.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    AlarmServices.ringtonePlayer = AlarmRingtonePlayer();

    final notifications = FlutterLocalNotificationsPlugin();
    final scheduler = AlarmNotificationScheduler(notifications);
    await scheduler.init(
      onDidReceiveNotificationResponse: (response) {
        unawaited(AlarmRingCoordinator.handleNotificationResponse(response));
      },
    );

    final launch = await notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch!.notificationResponse != null) {
      PendingAlarmLaunch.notificationResponse = launch.notificationResponse;
    }

    final dataSource = AlarmLocalDataSource();
    await dataSource.open();

    final repo = AlarmRepositoryImpl(dataSource, scheduler);
    await repo.restoreSchedules();
    return repo;
  }
}
