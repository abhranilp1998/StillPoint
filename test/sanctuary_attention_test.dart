import 'package:flutter_test/flutter_test.dart';
import 'package:stillpoint/src/core/models.dart';
import 'package:stillpoint/src/services/sanctuary_attention_service.dart';

void main() {
  final habit = Habit(
    id: 'caffeine',
    name: 'Caffeine',
    category: HabitCategory.caffeine,
    unit: 'servings',
    colorValue: 0xFFB88A44,
    createdAt: DateTime(2026),
  );

  AppState stateWith(List<UsageEntry> entries) {
    return AppState(
      habits: [habit],
      entries: entries,
      settings: const AppSettings(),
    );
  }

  UsageEntry entry({
    required DateTime loggedAt,
    int? mood,
    int? craving,
    int? stress,
  }) {
    return UsageEntry(
      id: loggedAt.toIso8601String(),
      habitId: habit.id,
      loggedAt: loggedAt,
      quantity: 1,
      mood: mood,
      craving: craving,
      stress: stress,
    );
  }

  test('stays quiet for ordinary recent logs', () {
    final now = DateTime(2026, 6, 8, 10);
    final state = stateWith([
      entry(loggedAt: now.subtract(const Duration(hours: 1)), craving: 2),
      entry(loggedAt: now.subtract(const Duration(hours: 2)), stress: 3),
      entry(loggedAt: now.subtract(const Duration(hours: 3)), mood: 3),
      entry(loggedAt: now.subtract(const Duration(hours: 4))),
    ]);

    expect(
      SanctuaryAttentionService.shouldDrawAttention(state, now: now),
      isFalse,
    );
  });

  test('draws attention for a recent high-need log', () {
    final now = DateTime(2026, 6, 8, 10);
    final state = stateWith([
      entry(loggedAt: now.subtract(const Duration(hours: 2)), craving: 4),
    ]);

    expect(
      SanctuaryAttentionService.shouldDrawAttention(state, now: now),
      isTrue,
    );
  });

  test('draws attention for repeated same-day high-need moments', () {
    final now = DateTime(2026, 6, 8, 18);
    final state = stateWith([
      entry(loggedAt: DateTime(2026, 6, 8, 8), mood: 2),
      entry(loggedAt: DateTime(2026, 6, 8, 12), stress: 4),
    ]);

    expect(
      SanctuaryAttentionService.shouldDrawAttention(state, now: now),
      isTrue,
    );
  });

  test('ignores old elevated logs', () {
    final now = DateTime(2026, 6, 8, 18);
    final state = stateWith([
      entry(loggedAt: DateTime(2026, 6, 7, 9), craving: 5),
    ]);

    expect(
      SanctuaryAttentionService.shouldDrawAttention(state, now: now),
      isFalse,
    );
  });
}
