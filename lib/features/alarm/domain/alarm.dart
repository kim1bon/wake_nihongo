/// Single alarm schedule. Weekdays follow [DateTime.weekday] (Monday = 1 … Sunday = 7).
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.enabled,
    required this.soundId,
  });

  final int id;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final bool enabled;

  /// One of [AlarmSoundIds.all], e.g. `Alram_01`.
  final String soundId;
}
