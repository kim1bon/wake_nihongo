import '../features/alarm/data/alarm_ringtone_player.dart';

/// Holds app-wide alarm helpers created during bootstrap (no Riverpod yet).
class AlarmServices {
  AlarmServices._();

  static late final AlarmRingtonePlayer ringtonePlayer;
}
