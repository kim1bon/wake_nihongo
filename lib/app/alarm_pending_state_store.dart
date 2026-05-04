import 'package:shared_preferences/shared_preferences.dart';

class PendingAlarmState {
  const PendingAlarmState({
    required this.alarmId,
    required this.soundId,
    required this.triggeredAtMs,
    this.isReschedule = false,
  });

  final int alarmId;
  final String soundId;
  final int triggeredAtMs;

  /// true면 「다시 알림」으로 인한 울림(주간 알람 재시작이 아님).
  final bool isReschedule;
}

class AlarmPendingStateStore {
  AlarmPendingStateStore._();

  static const _keyAlarmId = 'pending_alarm_id';
  static const _keySoundId = 'pending_alarm_sound_id';
  static const _keyTriggeredAtMs = 'pending_alarm_triggered_at_ms';
  static const _keyIsReschedule = 'pending_alarm_is_reschedule';

  static Future<void> save({
    required int alarmId,
    required String soundId,
    required int triggeredAtMs,
    bool isReschedule = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAlarmId, alarmId);
    await prefs.setString(_keySoundId, soundId);
    await prefs.setInt(_keyTriggeredAtMs, triggeredAtMs);
    await prefs.setBool(_keyIsReschedule, isReschedule);
  }

  static Future<PendingAlarmState?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmId = prefs.getInt(_keyAlarmId);
    final soundId = prefs.getString(_keySoundId);
    final triggeredAtMs = prefs.getInt(_keyTriggeredAtMs);
    if (alarmId == null || soundId == null || triggeredAtMs == null) {
      return null;
    }
    return PendingAlarmState(
      alarmId: alarmId,
      soundId: soundId,
      triggeredAtMs: triggeredAtMs,
      isReschedule: prefs.getBool(_keyIsReschedule) ?? false,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAlarmId);
    await prefs.remove(_keySoundId);
    await prefs.remove(_keyTriggeredAtMs);
    await prefs.remove(_keyIsReschedule);
  }
}
