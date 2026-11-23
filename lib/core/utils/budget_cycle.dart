import 'package:intl/intl.dart';

/// Represents a user's budget period anchored to [startDay] (1..28).
///
/// When [startDay] is `1`, each cycle matches a standard calendar month
/// (`2026-04-01` through `2026-04-30`, key `"2026-04"`).
/// When [startDay] is e.g. `25`, a cycle runs from the 25th of one month
/// through the 24th of the following month (`key` is the start month's
/// `"yyyy-MM"`).
class BudgetCycle {
  final String key;
  final DateTime start;
  final DateTime end;
  final int startDay;

  const BudgetCycle({
    required this.key,
    required this.start,
    required this.end,
    required this.startDay,
  });

  /// Clamps a payday / cycle start day to the safe cross-month range `1..28`.
  static int clampStartDay(int day) => day.clamp(1, 28);

  /// Computes the [BudgetCycle] containing [date] for [startDay].
  factory BudgetCycle.forDate(DateTime date, {int startDay = 1}) {
    final safeDay = clampStartDay(startDay);
    final normalized = DateTime(date.year, date.month, date.day);

    final start = normalized.day >= safeDay
        ? DateTime(normalized.year, normalized.month, safeDay)
        : DateTime(normalized.year, normalized.month - 1, safeDay);

    final nextStart = DateTime(start.year, start.month + 1, safeDay);
    final end = nextStart.subtract(const Duration(days: 1));
    final key =
        '${start.year}-${start.month.toString().padLeft(2, '0')}';

    return BudgetCycle(
      key: key,
      start: start,
      end: end,
      startDay: safeDay,
    );
  }

  /// Number of calendar days in this cycle (inclusive).
  int get totalDays => end.difference(start).inDays + 1;

  /// True when [date] (by calendar day) falls inside `[start, end]`.
  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Inclusive days remaining from [now] through [end].
  /// Returns `0` if [now] is after [end].
  int daysRemaining(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(end)) return 0;
    if (today.isBefore(start)) return totalDays;
    return end.difference(today).inDays + 1;
  }

  /// Human-readable label for headers & cards.
  String formatLabel() {
    if (startDay == 1) {
      return DateFormat('MMMM yyyy').format(start);
    }
    if (start.year == end.year) {
      return '${DateFormat('MMM d').format(start)} – '
          '${DateFormat('MMM d').format(end)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – '
        '${DateFormat('MMM d, yyyy').format(end)}';
  }
}
