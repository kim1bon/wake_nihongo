import 'alarm.dart';

abstract class AlarmRepository {
  Future<List<Alarm>> getAlarms();

  Future<Alarm?> getAlarm(int id);

  Future<Alarm> createAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
    bool rescheduleEnabled = true,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 5,
  });

  Future<void> deleteAlarm(int id);

  Future<Alarm> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
    bool rescheduleEnabled = true,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 5,
  });

  /// 「다시 알림」로 예약된 일회 알림 취소.
  Future<void> cancelPendingReschedule(int alarmId);

  /// 「다시 알림」일회 예약 (동일 알람 ID의 기존 다시 알림은 덮어씀).
  Future<void> scheduleReschedule({
    required int alarmId,
    required String soundId,
    required int delayMinutes,
  });

  /// 알람 해제 직후 남아있는 iOS 체인 슬롯/다시 알림을 정리하고 주간 스케줄만 복원합니다.
  Future<void> refreshScheduleAfterDismiss(int alarmId);

  Future<void> setAlarmEnabled(int id, bool enabled);

  /// Re-register all notifications from local data (e.g. after reboot or app update).
  Future<void> restoreSchedules();

  Future<void> ensureNotificationPermissions();
}
