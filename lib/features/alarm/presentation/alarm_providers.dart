import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';
import '../domain/alarm_repository.dart';

AlarmRepository? _alarmRepository;

void registerAlarmRepository(AlarmRepository repository) {
  _alarmRepository = repository;
}

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  final repo = _alarmRepository;
  if (repo == null) {
    throw StateError('Call registerAlarmRepository() in main() before runApp.');
  }
  return repo;
});

final alarmsNotifierProvider =
    AsyncNotifierProvider<AlarmsNotifier, List<Alarm>>(AlarmsNotifier.new);

class AlarmsNotifier extends AsyncNotifier<List<Alarm>> {
  @override
  Future<List<Alarm>> build() {
    return ref.read(alarmRepositoryProvider).getAlarms();
  }

  Future<void> create({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    await ref.read(alarmRepositoryProvider).createAlarm(
          hour: hour,
          minute: minute,
          weekdays: weekdays,
          soundId: sid,
        );
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await ref.read(alarmRepositoryProvider).deleteAlarm(id);
    ref.invalidateSelf();
  }

  Future<void> setAlarmEnabled(int id, bool enabled) async {
    await ref.read(alarmRepositoryProvider).setAlarmEnabled(id, enabled);
    ref.invalidateSelf();
  }

  Future<void> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
  }) async {
    final sid = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    await ref.read(alarmRepositoryProvider).updateAlarm(
          id: id,
          hour: hour,
          minute: minute,
          weekdays: weekdays,
          soundId: sid,
        );
    ref.invalidateSelf();
  }
}
