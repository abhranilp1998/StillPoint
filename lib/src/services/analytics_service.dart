import 'dart:math';

import '../core/models.dart';

class DailyUsage {
  const DailyUsage({
    required this.day,
    required this.quantity,
    required this.logs,
    required this.averageMood,
    required this.averageCraving,
  });

  final DateTime day;
  final double quantity;
  final int logs;
  final double averageMood;
  final double averageCraving;
}

class HourBucket {
  const HourBucket({
    required this.hour,
    required this.quantity,
    required this.logs,
  });

  final int hour;
  final double quantity;
  final int logs;
}

class TriggerMetric {
  const TriggerMetric({
    required this.name,
    required this.quantity,
    required this.logs,
  });

  final String name;
  final double quantity;
  final int logs;
}

class HeatmapCell {
  const HeatmapCell({
    required this.day,
    required this.intensity,
    required this.quantity,
  });

  final DateTime day;
  final int intensity;
  final double quantity;
}

class AdaptiveReminderSuggestion {
  const AdaptiveReminderSuggestion({
    required this.windowStartHour,
    required this.windowLabel,
    required this.leadTime,
    required this.evidenceCount,
    this.topTrigger,
  });

  final int windowStartHour;
  final String windowLabel;
  final Duration leadTime;
  final int evidenceCount;
  final String? topTrigger;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.daily,
    required this.hourly,
    required this.triggers,
    required this.heatmap,
    required this.todayTotal,
    required this.weekTotal,
    required this.previousWeekTotal,
    required this.averageMood,
    required this.averageCraving,
    required this.currentTargetDays,
    required this.totalLogs,
    required this.mostActiveWindow,
    required this.reductionPercent,
    required this.totalEstimatedCost,
    required this.weekEstimatedCost,
    required this.sevenDayEstimatedCost,
    required this.previousWeekEstimatedCost,
    required this.todayEstimatedCost,
    required this.monthEstimatedCost,
    required this.topCostHabitAmount,
    this.topCostHabitName,
    required this.habitsWithCost,
  });

  final List<DailyUsage> daily;
  final List<HourBucket> hourly;
  final List<TriggerMetric> triggers;
  final List<HeatmapCell> heatmap;
  final double todayTotal;
  final double weekTotal;
  final double previousWeekTotal;
  final double averageMood;
  final double averageCraving;
  final int currentTargetDays;
  final int totalLogs;
  final String mostActiveWindow;
  final double reductionPercent;
  final double totalEstimatedCost;
  final double weekEstimatedCost;
  final double sevenDayEstimatedCost;
  final double previousWeekEstimatedCost;
  final double todayEstimatedCost;
  final double monthEstimatedCost;
  final double topCostHabitAmount;
  final String? topCostHabitName;
  final int habitsWithCost;
}

class AnalyticsService {
  static AnalyticsSnapshot buildSnapshot(
    AppState state, {
    Set<String>? focusHabitIds,
  }) {
    final now = DateTime.now();
    final today = _dayStart(now);
    final entries = [...state.entries]
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final activeHabitIds = state.activeHabits.map((habit) => habit.id).toSet();
    final scopedHabitIds = focusHabitIds == null || focusHabitIds.isEmpty
        ? activeHabitIds
        : activeHabitIds.intersection(focusHabitIds);
    final scopedHabits = state.activeHabits
        .where((habit) => scopedHabitIds.contains(habit.id))
        .toList(growable: false);
    final habitsById = {for (final habit in scopedHabits) habit.id: habit};
    final scoped = entries
        .where((entry) => scopedHabitIds.contains(entry.habitId))
        .toList(growable: false);

    final daily = <DailyUsage>[];
    for (var offset = 55; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final dayEntries = scoped.where((entry) => _sameDay(entry.loggedAt, day));
      daily.add(
        DailyUsage(
          day: day,
          quantity: dayEntries.fold<double>(
            0,
            (total, entry) => total + entry.quantity,
          ),
          logs: dayEntries.length,
          averageMood: _average(
            dayEntries.map((entry) => entry.mood?.toDouble()).nonNulls,
          ),
          averageCraving: _average(
            dayEntries.map((entry) => entry.craving?.toDouble()).nonNulls,
          ),
        ),
      );
    }

    final hourly = [
      for (var hour = 0; hour < 24; hour++)
        HourBucket(
          hour: hour,
          quantity: scoped
              .where((entry) => entry.loggedAt.hour == hour)
              .fold<double>(0, (total, entry) => total + entry.quantity),
          logs: scoped.where((entry) => entry.loggedAt.hour == hour).length,
        ),
    ];

    final triggerTotals = <String, ({double quantity, int logs})>{};
    for (final entry in scoped.where((entry) => entry.trigger != null)) {
      final key = entry.trigger!;
      final previous = triggerTotals[key] ?? (quantity: 0.0, logs: 0);
      triggerTotals[key] = (
        quantity: previous.quantity + entry.quantity,
        logs: previous.logs + 1,
      );
    }
    final triggers =
        triggerTotals.entries
            .map(
              (entry) => TriggerMetric(
                name: entry.key,
                quantity: entry.value.quantity,
                logs: entry.value.logs,
              ),
            )
            .toList()
          ..sort((a, b) => b.quantity.compareTo(a.quantity));

    final maxDaily = daily.fold<double>(
      0,
      (maxValue, day) => max(maxValue, day.quantity),
    );
    final heatmap = [
      for (final day in daily)
        HeatmapCell(
          day: day.day,
          quantity: day.quantity,
          intensity: maxDaily <= 0
              ? 0
              : min(4, (day.quantity / maxDaily * 4).ceil()),
        ),
    ];

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final weekTotal = _sumBetween(scoped, weekStart, now);
    final previousWeekTotal = _sumBetween(scoped, previousWeekStart, weekStart);
    final totalEstimatedCost = _costFor(scoped, habitsById);
    final weekEstimatedCost = _costFor(
      _between(scoped, weekStart, now),
      habitsById,
    );
    final sevenDayEstimatedCost = _costFor(
      _between(scoped, now.subtract(const Duration(days: 7)), now),
      habitsById,
    );
    final previousWeekEstimatedCost = _costFor(
      _between(scoped, previousWeekStart, weekStart),
      habitsById,
    );
    final todayEstimatedCost = _costFor(
      scoped.where((entry) => _sameDay(entry.loggedAt, today)),
      habitsById,
    );
    final monthEstimatedCost = _costFor(
      _between(scoped, DateTime(now.year, now.month), now),
      habitsById,
    );
    final topCost = _topCostHabit(scoped, habitsById);
    final double reductionPercent = previousWeekTotal <= 0
        ? 0
        : ((previousWeekTotal - weekTotal) / previousWeekTotal) * 100;

    final currentTargetDays = _countRecentTargetDays(scopedHabits, daily);
    final strongestHour = hourly.reduce(
      (a, b) => a.quantity >= b.quantity ? a : b,
    );

    return AnalyticsSnapshot(
      daily: daily,
      hourly: hourly,
      triggers: triggers.take(5).toList(),
      heatmap: heatmap,
      todayTotal: daily.last.quantity,
      weekTotal: weekTotal,
      previousWeekTotal: previousWeekTotal,
      averageMood: _average(
        scoped.map((entry) => entry.mood?.toDouble()).nonNulls,
      ),
      averageCraving: _average(
        scoped.map((entry) => entry.craving?.toDouble()).nonNulls,
      ),
      currentTargetDays: currentTargetDays,
      totalLogs: scoped.length,
      mostActiveWindow: _windowLabel(strongestHour.hour),
      reductionPercent: reductionPercent,
      totalEstimatedCost: totalEstimatedCost,
      weekEstimatedCost: weekEstimatedCost,
      sevenDayEstimatedCost: sevenDayEstimatedCost,
      previousWeekEstimatedCost: previousWeekEstimatedCost,
      todayEstimatedCost: todayEstimatedCost,
      monthEstimatedCost: monthEstimatedCost,
      topCostHabitName: topCost?.name,
      topCostHabitAmount: topCost?.amount ?? 0,
      habitsWithCost: scopedHabits
          .where((habit) => (habit.costPerUnit ?? 0) > 0)
          .length,
    );
  }

  static AdaptiveReminderSuggestion? buildAdaptiveReminderSuggestion(
    AppState state,
  ) {
    final snapshot = buildSnapshot(state);
    if (snapshot.totalLogs < 4) return null;

    final window = _dominantReminderWindow(snapshot);
    if (window == null) return null;

    final topTrigger =
        snapshot.triggers.isNotEmpty && snapshot.triggers.first.logs >= 2
        ? snapshot.triggers.first.name
        : null;
    return AdaptiveReminderSuggestion(
      windowStartHour: window.startHour,
      windowLabel: _windowLabel(window.startHour),
      leadTime: const Duration(minutes: 45),
      evidenceCount: window.logs,
      topTrigger: topTrigger,
    );
  }

  static DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static double _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (total, value) => total + value) / list.length;
  }

  static double _sumBetween(
    List<UsageEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    return _between(
      entries,
      start,
      end,
    ).fold<double>(0, (total, entry) => total + entry.quantity);
  }

  static Iterable<UsageEntry> _between(
    List<UsageEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    return entries.where(
      (entry) =>
          !entry.loggedAt.isBefore(start) && entry.loggedAt.isBefore(end),
    );
  }

  static double _costFor(
    Iterable<UsageEntry> entries,
    Map<String, Habit> habitsById,
  ) {
    return entries.fold<double>(0, (total, entry) {
      final habit = habitsById[entry.habitId];
      final cost = habit == null ? null : entry.estimatedCostFor(habit);
      if (cost == null || cost <= 0) return total;
      return total + cost;
    });
  }

  static ({String name, double amount})? _topCostHabit(
    Iterable<UsageEntry> entries,
    Map<String, Habit> habitsById,
  ) {
    final totals = <String, double>{};
    for (final entry in entries) {
      final habit = habitsById[entry.habitId];
      if (habit == null) continue;
      final cost = entry.estimatedCostFor(habit);
      if (cost == null || cost <= 0) continue;
      totals.update(habit.id, (value) => value + cost, ifAbsent: () => cost);
    }
    if (totals.isEmpty) return null;

    final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final habit = habitsById[top.key];
    if (habit == null) return null;
    return (name: habit.name, amount: top.value);
  }

  static int _countRecentTargetDays(
    List<Habit> habits,
    List<DailyUsage> daily,
  ) {
    final targets = habits
        .where((habit) => habit.dailyTarget != null)
        .map((habit) => habit.dailyTarget!)
        .toList();
    if (targets.isEmpty) return 0;

    final flexibleDailyTarget = targets.fold<double>(0, (a, b) => a + b);
    var count = 0;
    for (final day in daily.reversed) {
      if (day.quantity <= flexibleDailyTarget) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  static String _windowLabel(int hour) {
    final end = (hour + 3) % 24;
    String format(int value) {
      if (value == 0) return '12 AM';
      if (value < 12) return '$value AM';
      if (value == 12) return '12 PM';
      return '${value - 12} PM';
    }

    return '${format(hour)}-${format(end)}';
  }

  static ({int startHour, int logs, double quantity})? _dominantReminderWindow(
    AnalyticsSnapshot snapshot,
  ) {
    if (snapshot.totalLogs < 4) return null;

    ({int startHour, int logs, double quantity})? bestWindow;
    for (var startHour = 0; startHour < 24; startHour += 1) {
      var logs = 0;
      var quantity = 0.0;
      for (var offset = 0; offset < 3; offset += 1) {
        final bucket = snapshot.hourly[(startHour + offset) % 24];
        logs += bucket.logs;
        quantity += bucket.quantity;
      }
      final candidate = (startHour: startHour, logs: logs, quantity: quantity);
      if (bestWindow == null ||
          candidate.logs > bestWindow.logs ||
          (candidate.logs == bestWindow.logs &&
              candidate.quantity >= bestWindow.quantity)) {
        bestWindow = candidate;
      }
    }

    if (bestWindow == null ||
        bestWindow.logs < 2 ||
        bestWindow.logs / snapshot.totalLogs < .3) {
      return null;
    }
    return bestWindow;
  }
}
