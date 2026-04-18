import 'package:wake_nihongo/core/constants/alarm_sound_ids.dart';
import 'package:wake_nihongo/features/alarm/domain/alarm.dart';
import 'package:wake_nihongo/features/alarm/domain/alarm_repository.dart';

class FakeAlarmRepository implements AlarmRepository {
  final List<Alarm> _alarms = [];
  int _nextId = 1;

  @override
  Future<List<Alarm>> getAlarms() async => List.unmodifiable(_alarms);

  @override
  Future<Alarm> createAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    final alarm = Alarm(
      id: _nextId++,
      hour: hour,
      minute: minute,
      weekdays: Set<int>.from(weekdays),
      enabled: true,
      soundId: sid,
    );
    _alarms.add(alarm);
    return alarm;
  }

  @override
  Future<void> deleteAlarm(int id) async {
    _alarms.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> setAlarmEnabled(int id, bool enabled) async {
    final i = _alarms.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final prev = _alarms[i];
    _alarms[i] = Alarm(
      id: prev.id,
      hour: prev.hour,
      minute: prev.minute,
      weekdays: prev.weekdays,
      enabled: enabled,
      soundId: prev.soundId,
    );
  }

  @override
  Future<Alarm> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final i = _alarms.indexWhere((a) => a.id == id);
    if (i < 0) {
      throw StateError('Alarm not found: $id');
    }
    final prev = _alarms[i];
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    final next = Alarm(
      id: id,
      hour: hour,
      minute: minute,
      weekdays: Set<int>.from(weekdays),
      enabled: prev.enabled,
      soundId: sid,
    );
    _alarms[i] = next;
    return next;
  }

  @override
  Future<void> restoreSchedules() async {}

  @override
  Future<void> ensureNotificationPermissions() async {}
}
