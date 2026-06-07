import '../core/models.dart';

class SanctuaryAttentionService {
  static bool shouldDrawAttention(AppState state, {DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final activeHabitIds = state.activeHabits.map((habit) => habit.id).toSet();
    final activeEntries = state.entries
        .where(
          (entry) =>
              activeHabitIds.contains(entry.habitId) &&
              !entry.loggedAt.isAfter(anchor),
        )
        .toList(growable: false);

    final recentStart = anchor.subtract(const Duration(hours: 6));
    final recentHighNeed = activeEntries.any(
      (entry) => entry.loggedAt.isAfter(recentStart) && _isHighNeed(entry),
    );
    if (recentHighNeed) return true;

    final todayStart = DateTime(anchor.year, anchor.month, anchor.day);
    final todayHighNeed = activeEntries
        .where(
          (entry) => !entry.loggedAt.isBefore(todayStart) && _isHighNeed(entry),
        )
        .toList(growable: false);
    if (todayHighNeed.length >= 2 &&
        todayHighNeed.any(
          (entry) =>
              anchor.difference(entry.loggedAt) <= const Duration(hours: 12),
        )) {
      return true;
    }

    return false;
  }

  static bool _isHighNeed(UsageEntry entry) {
    return (entry.craving ?? 0) >= 4 ||
        (entry.stress ?? 0) >= 4 ||
        (entry.mood != null && entry.mood! <= 2);
  }
}
