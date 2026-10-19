enum DeadlineStatus { healthy, yellow, orange, red, completed }

class DeadlineResult {
  final DateTime deadline;
  final DeadlineStatus status;
  final int daysRemaining;
  const DeadlineResult(this.deadline, this.status, this.daysRemaining);
  bool get overdue => status == DeadlineStatus.red;
}

class DeadlineService {
  static DateTime addMonths(DateTime date, int months) {
    final target = date.month + months;
    final year = date.year + ((target - 1) ~/ 12);
    final month = ((target - 1) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  static DateTime addMonthsAndDays(DateTime date, int months, int days) =>
      addMonths(date, months).add(Duration(days: days));

  static DeadlineResult police(DateTime start, {DateTime? completed, DateTime? now}) =>
      _result(start, completed, now, yellow: addMonths(start, 3), orange: addMonths(start, 4), red: addMonths(start, 5));

  static DeadlineResult filing(DateTime start, {DateTime? completed, DateTime? now}) =>
      _result(start, completed, now, yellow: addMonths(start, 4), orange: addMonths(start, 4), red: addMonths(start, 5), skipOrange: true);

  static DeadlineResult deposit(DateTime start, {DateTime? completed, DateTime? now}) =>
      _result(start, completed, now, yellow: addMonthsAndDays(start, 2, 15), orange: addMonths(start, 3), red: addMonthsAndDays(start, 3, 15));

  static DeadlineResult ep(DateTime start, {DateTime? completed, DateTime? now}) =>
      _result(start, completed, now, yellow: addMonths(start, 4), orange: addMonths(start, 4), red: addMonths(start, 4));

  static DeadlineResult fees(DateTime start, {DateTime? completed, DateTime? now}) =>
      _result(start, completed, now, yellow: start.add(const Duration(days: 7)), orange: start.add(const Duration(days: 7)), red: start.add(const Duration(days: 7)));

  static DeadlineResult _result(DateTime start, DateTime? completed, DateTime? now, {
    required DateTime yellow, required DateTime orange, required DateTime red, bool skipOrange = false,
  }) {
    final today = now ?? DateTime.now();
    if (completed != null) return DeadlineResult(completed, DeadlineStatus.completed, 0);
    final days = DateTime(yellow.year, yellow.month, yellow.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (today.isBefore(yellow)) return DeadlineResult(yellow, DeadlineStatus.healthy, days);
    if (!skipOrange && today.isBefore(orange)) return DeadlineResult(orange, DeadlineStatus.yellow, days);
    if (today.isBefore(red)) return DeadlineResult(red, skipOrange ? DeadlineStatus.yellow : DeadlineStatus.orange, days);
    return DeadlineResult(red, DeadlineStatus.red, days);
  }
}
