import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';
import '../domain/alarm_repository.dart';
import 'alarm_local_data_source.dart';
import 'alarm_native_android.dart';
import 'alarm_notification_scheduler.dart';

class AlarmRepositoryImpl implements AlarmRepository {
  AlarmRepositoryImpl(this._dataSource, this._scheduler);

  final AlarmLocalDataSource _dataSource;
  final AlarmNotificationScheduler _scheduler;

  @override
  Future<List<Alarm>> getAlarms() => _dataSource.getAll();

  @override
  Future<Alarm> createAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final resolvedSoundId = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    final alarm = await _dataSource.insertAlarm(
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      soundId: resolvedSoundId,
    );
    await _scheduler.schedule(alarm);
    await AlarmNativeAndroid.syncAlarms(await _dataSource.getAll());
    return alarm;
  }

  @override
  Future<void> deleteAlarm(int id) async {
    await _scheduler.cancelAllSlotsForAlarmId(id);
    await _dataSource.delete(id);
    await AlarmNativeAndroid.syncAlarms(await _dataSource.getAll());
  }

  @override
  Future<void> setAlarmEnabled(int id, bool enabled) async {
    await _dataSource.setAlarmEnabled(id, enabled);
    final alarm = await _dataSource.getById(id);
    if (alarm == null) return;
    await _scheduler.cancelAllSlotsForAlarmId(id);
    if (alarm.enabled) {
      await _scheduler.schedule(alarm);
    }
    await AlarmNativeAndroid.syncAlarms(await _dataSource.getAll());
  }

  @override
  Future<Alarm> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final existing = await _dataSource.getById(id);
    if (existing == null) {
      throw StateError('Alarm not found: $id');
    }
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    await _scheduler.cancelAllSlotsForAlarmId(id);
    await _dataSource.updateAlarm(
      id: id,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      enabled: existing.enabled,
      soundId: sid,
    );
    final updated = await _dataSource.getById(id);
    if (updated == null) {
      throw StateError('Alarm missing after update: $id');
    }
    if (updated.enabled) {
      await _scheduler.schedule(updated);
    }
    await AlarmNativeAndroid.syncAlarms(await _dataSource.getAll());
    return updated;
  }

  @override
  Future<void> restoreSchedules() async {
    final alarms = await _dataSource.getAll();
    for (final alarm in alarms) {
      await _scheduler.cancelAllSlotsForAlarmId(alarm.id);
    }
    for (final alarm in alarms) {
      if (alarm.enabled) {
        await _scheduler.schedule(alarm);
      }
    }
    await AlarmNativeAndroid.syncAlarms(await _dataSource.getAll());
  }

  @override
  Future<void> ensureNotificationPermissions() => _scheduler.ensurePermissions();
}
