import 'package:adaptive_recovery_tracker/src/core/models.dart';
import 'package:adaptive_recovery_tracker/src/core/habit_library.dart';
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
    expect(const AppSettings().privacyConsentCompleted, isFalse);
    expect(AppSettings.fromMap(const {}).privacyConsentCompleted, isFalse);
    expect(
      AppSettings.fromMap(const {
        'softReminders': false,
      }).privacyConsentCompleted,
      isTrue,
    );
  });

  test('privacy consent choice persists in settings', () {
    final settings = const AppSettings().copyWith(
      privacyConsentCompleted: true,
      softReminders: true,
      hiddenNotifications: true,
      pinLock: true,
      pinHash: 'hash',
    );

    final restored = AppSettings.fromMap(settings.toMap());

    expect(restored.privacyConsentCompleted, isTrue);
    expect(restored.softReminders, isTrue);
    expect(restored.hiddenNotifications, isTrue);
    expect(restored.pinLock, isTrue);
    expect(restored.pinHash, 'hash');
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

  test('entry unit cost persists and analytics prefers log snapshot', () {
    final habit = Habit(
      id: 'coffee',
      name: 'Coffee',
      category: HabitCategory.caffeine,
      unit: 'cups',
      colorValue: 0xFFB88A44,
      createdAt: DateTime(2026),
      costPerUnit: 10,
    );
    final entry = UsageEntry(
      id: 'entry',
      habitId: habit.id,
      loggedAt: DateTime.now(),
      quantity: 2,
      unitCost: 4,
    );
    final restored = UsageEntry.fromMap(entry.toMap());

    expect(restored.unitCost, 4);
    expect(restored.estimatedCostFor(habit), 8);

    final snapshot = AnalyticsService.buildSnapshot(
      AppState(
        habits: [habit],
        entries: [restored],
        settings: const AppSettings(),
      ),
    );

    expect(snapshot.todayEstimatedCost, 8);
    expect(snapshot.totalEstimatedCost, 8);
  });

  test(
    'local habit library includes aliases, context chips, and cost defaults',
    () {
      final cannabis = Habit(
        id: 'cannabis',
        name: 'Cannabis',
        category: HabitCategory.cannabis,
        unit: 'uses',
        colorValue: 0xFF6F8E65,
        createdAt: DateTime(2026),
      );
      final cigarettes = Habit(
        id: 'cigarettes',
        name: 'Cigarettes',
        category: HabitCategory.cigarettes,
        unit: 'cigarettes',
        colorValue: 0xFF6A8F7A,
        createdAt: DateTime(2026),
      );

      expect(HabitLibrary.matchesHabit(cannabis, 'weed'), isTrue);
      expect(HabitLibrary.matchesHabit(cigarettes, 'cigs'), isTrue);
      expect(
        HabitLibrary.contextChipsFor(HabitCategory.alcohol),
        containsAll(['Social', 'Alone', 'After work', 'Celebration']),
      );
      expect(
        HabitLibrary.contextChipsFor(HabitCategory.methamphetamine),
        containsAll(['Redose', 'Sleep loss', 'Work pressure', 'Focus']),
      );
      expect(HabitLibrary.defaultUnitCostFor(HabitCategory.alcohol), 8);
    },
  );

  test('insight preferences persist locally', () {
    final state = AppState(
      habits: const [],
      entries: const [],
      settings: const AppSettings(),
      insightPreferences: [
        InsightPreference(
          id: 'time_of_day_evening',
          evidenceKey: 'evening:4',
          pinned: true,
          updatedAt: DateTime(2026),
        ),
      ],
    );

    final restored = AppState.fromMap(state.toMap());

    expect(restored.insightPreferences, hasLength(1));
    expect(restored.insightPreferences.first.id, 'time_of_day_evening');
    expect(restored.insightPreferences.first.pinned, isTrue);
  });
}
