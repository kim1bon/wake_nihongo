import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cold start from a notification: handled after [MaterialApp] mounts.
class PendingAlarmLaunch {
  static NotificationResponse? notificationResponse;
}
