import 'package:adaptive_recovery_tracker/src/core/models.dart';
import 'package:adaptive_recovery_tracker/src/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default trackers include expanded user-requested catalogue', () {
    final categories = AppState.defaultHabitPresets(
      DateTime(2026),
    ).map((habit) => habit.category).toSet();

    expect(categories, contains(HabitCategory.cannabis));
    expect(categories, contains(HabitCategory.opioids));
    expect(categories, contains(HabitCategory.methamphetamine));
    expect(categories, contains(HabitCategory.benzodiazepines));
    expect(categories, contains(HabitCategory.coughMedicine));
    expect(categories, contains(HabitCategory.kratom));
    expect(categories, contains(HabitCategory.otherDrugs));
  });

  test('gentle reminders are opt-in by default', () {
    expect(const AppSettings().softReminders, isFalse);
    expect(AppSettings.fromMap(const {}).softReminders, isFalse);
  });

  test('habit cost persists and analytics estimates money that could stay', () {
    final habit = Habit(
      id: 'caffeine',
      name: 'Caffeine',
      category: HabitCategory.caffeine,
      unit: 'servings',
      colorValue: 0xFFB88A44,
      createdAt: DateTime(2026),
      costPerUnit: 4.5,
    );
    final restored = Habit.fromMap(habit.toMap());

    expect(restored.costPerUnit, 4.5);

    final snapshot = AnalyticsService.buildSnapshot(
      AppState(
        habits: [restored],
        entries: [
          UsageEntry(
            id: 'entry',
            habitId: restored.id,
            loggedAt: DateTime.now(),
            quantity: 2,
          ),
        ],
        settings: const AppSettings(),
      ),
    );

    expect(snapshot.todayEstimatedCost, 9);
    expect(snapshot.weekEstimatedCost, 9);
    expect(snapshot.habitsWithCost, 1);
  });
}
