import 'alarm.dart';

abstract class AlarmRepository {
  Future<List<Alarm>> getAlarms();

  Future<Alarm> createAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  });

  Future<void> deleteAlarm(int id);

  Future<Alarm> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  });

  Future<void> setAlarmEnabled(int id, bool enabled);

  /// Re-register all notifications from local data (e.g. after reboot or app update).
  Future<void> restoreSchedules();

  Future<void> ensureNotificationPermissions();
}
