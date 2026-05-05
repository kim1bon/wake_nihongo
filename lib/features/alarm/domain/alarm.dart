/// Single alarm schedule. Weekdays follow [DateTime.weekday] (Monday = 1 … Sunday = 7).
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.enabled,
    required this.soundId,
    this.rescheduleEnabled = false,
    this.rescheduleDelayMinutes = 5,
    this.rescheduleMaxCount = 3,
  });

  final int id;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final bool enabled;

  /// One of [AlarmSoundIds.all], e.g. `basic`.
  final String soundId;

  /// 「다시 알림」기능 사용 여부.
  final bool rescheduleEnabled;

  /// 다시 알림 연기 시간(분). 1~15.
  final int rescheduleDelayMinutes;

  /// 한 번 울릴 때 다시 알림을 쓸 수 있는 최대 횟수. 1~10.
  final int rescheduleMaxCount;
}
