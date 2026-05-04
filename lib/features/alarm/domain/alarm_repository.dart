import 'alarm.dart';

abstract class AlarmRepository {
  Future<List<Alarm>> getAlarms();

  Future<Alarm?> getAlarm(int id);

  Future<Alarm> createAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
    bool rescheduleEnabled = false,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 3,
  });

  Future<void> deleteAlarm(int id);

  Future<Alarm> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
    bool rescheduleEnabled = false,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 3,
  });

  /// 「다시 알림」로 예약된 일회 알림 취소.
  Future<void> cancelPendingReschedule(int alarmId);

  /// 「다시 알림」일회 예약 (동일 알람 ID의 기존 다시 알림은 덮어씀).
  Future<void> scheduleReschedule({
    required int alarmId,
    required String soundId,
    required int delayMinutes,
  });

  Future<void> setAlarmEnabled(int id, bool enabled);

  /// Re-register all notifications from local data (e.g. after reboot or app update).
  Future<void> restoreSchedules();

  Future<void> ensureNotificationPermissions();
}
