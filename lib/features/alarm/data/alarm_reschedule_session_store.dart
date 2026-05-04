import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 한 번의 알람 울림(또는 다시 알림 체인)에서 남은 「다시 알림」횟수.
class AlarmRescheduleSessionStore {
  AlarmRescheduleSessionStore._();

  static const _prefsKey = 'alarm_reschedule_session_v1';

  static Future<void> startSession({
    required int alarmId,
    required int remainingUses,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'alarmId': alarmId,
        'remaining': remainingUses,
      }),
    );
  }

  static Future<void> clearForAlarm(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['alarmId'];
      final storedId = id is int ? id : int.tryParse('$id') ?? -1;
      if (storedId == alarmId) {
        await prefs.remove(_prefsKey);
      }
    } catch (_) {}
  }

  /// 세션 없거나 알람 ID 불일치 시 `null`.
  static Future<int?> readRemaining(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['alarmId'];
      final storedId = id is int ? id : int.tryParse('$id') ?? -1;
      if (storedId != alarmId) return null;
      final r = map['remaining'];
      if (r is int) return r;
      return int.tryParse('$r');
    } catch (_) {
      return null;
    }
  }

  static Future<void> decrementRemaining(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['alarmId'];
      final storedId = id is int ? id : int.tryParse('$id') ?? -1;
      if (storedId != alarmId) return;
      final r = map['remaining'];
      var remaining = r is int ? r : int.tryParse('$r') ?? 0;
      remaining = (remaining - 1).clamp(0, 999);
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'alarmId': alarmId,
          'remaining': remaining,
        }),
      );
    } catch (_) {}
  }
}
