/// [DateTime.weekday] 기준: 월=1 … 일=7
class AlarmWeekdays {
  AlarmWeekdays._();

  static const Set<int> all = {1, 2, 3, 4, 5, 6, 7};

  static bool isEveryDay(Set<int> weekdays) =>
      weekdays.length == 7 && weekdays.containsAll(all);
}
