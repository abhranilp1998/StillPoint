import 'package:adaptive_recovery_tracker/src/core/models.dart';
import 'package:adaptive_recovery_tracker/src/services/analytics_service.dart';
import 'package:adaptive_recovery_tracker/src/services/insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insight language stays neutral and data-backed', () {
    final habit = Habit(
      id: 'caffeine',
      name: 'Caffeine',
      category: HabitCategory.caffeine,
      unit: 'servings',
      colorValue: 0xFFB88A44,
      createdAt: DateTime(2026),
    );
    final now = DateTime.now();
    final state = AppState(
      habits: [habit],
      settings: const AppSettings(),
      entries: [
        for (var i = 0; i < 8; i++)
          UsageEntry(
            id: '$i',
            habitId: habit.id,
            loggedAt: now.subtract(Duration(days: i)),
            quantity: i < 3 ? 1 : 3,
            stress: i < 3 ? 2 : 5,
            trigger: i < 3 ? 'Sleep' : 'Work',
          ),
      ],
    );

    final insights = InsightEngine.generate(
      state,
      AnalyticsService.buildSnapshot(state),
    );
    final language = insights.map((insight) => insight.body).join(' ');

    expect(insights, isNotEmpty);
    expect(language.contains('failed'), isFalse);
    expect(language.contains('bad habit'), isFalse);
    expect(language.contains('discipline'), isFalse);
  });
}
