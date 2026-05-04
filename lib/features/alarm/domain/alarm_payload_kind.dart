/// 로컬 알림 payload의 `kind` 값. 기존 payload에 없으면 [weekly]로 간주합니다.
enum AlarmPayloadKind {
  weekly,
  reschedule,
}

AlarmPayloadKind? alarmPayloadKindFromString(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case 'weekly':
      return AlarmPayloadKind.weekly;
    case 'reschedule':
      return AlarmPayloadKind.reschedule;
    default:
      return null;
  }
}
