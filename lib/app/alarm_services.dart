import '../features/alarm/data/alarm_ringtone_player.dart';
import '../features/alarm/domain/alarm_repository.dart';

/// Holds app-wide alarm helpers created during bootstrap (no Riverpod yet).
class AlarmServices {
  AlarmServices._();

  static late final AlarmRingtonePlayer ringtonePlayer;

  /// [AppBootstrap]에서 설정. [AlarmRingCoordinator] 등 Riverpod 밖 코드용.
  static AlarmRepository? alarmRepository;
}
