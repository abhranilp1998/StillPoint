import 'package:stillpoint/src/core/models.dart';
import 'package:stillpoint/src/services/analytics_service.dart';
import 'package:stillpoint/src/services/insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Habit habit({
    String id = 'caffeine',
    String name = 'Caffeine',
    HabitCategory category = HabitCategory.caffeine,
    String unit = 'servings',
    double? costPerUnit,
  }) {
    return Habit(
      id: id,
      name: name,
      category: category,
      unit: unit,
      colorValue: 0xFFB88A44,
      createdAt: DateTime(2026),
      costPerUnit: costPerUnit,
    );
  }

  test('insight language stays neutral and data-backed', () {
    final tracker = habit();
    final now = DateTime.now();
    final state = AppState(
      habits: [tracker],
      settings: const AppSettings(),
      entries: [
        for (var i = 0; i < 8; i++)
          UsageEntry(
            id: '$i',
            habitId: tracker.id,
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

  test('generates time, stress, and repeated same-day insight types', () {
    final tracker = habit(category: HabitCategory.cannabis, name: 'Cannabis');
    final now = DateTime.now();
    final evening = DateTime(now.year, now.month, now.day, 20);
    final state = AppState(
      habits: [tracker],
      settings: const AppSettings(),
      entries: [
        UsageEntry(
          id: '1',
          habitId: tracker.id,
          loggedAt: evening,
          quantity: 4,
          stress: 5,
        ),
        UsageEntry(
          id: '2',
          habitId: tracker.id,
          loggedAt: evening.add(const Duration(hours: 1)),
          quantity: 4,
          stress: 5,
        ),
        UsageEntry(
          id: '3',
          habitId: tracker.id,
          loggedAt: evening.add(const Duration(hours: 2)),
          quantity: 3,
          stress: 4,
        ),
        UsageEntry(
          id: '4',
          habitId: tracker.id,
          loggedAt: evening.subtract(const Duration(days: 2)),
          quantity: 1,
          stress: 1,
        ),
        UsageEntry(
          id: '5',
          habitId: tracker.id,
          loggedAt: evening.subtract(const Duration(days: 2, hours: -1)),
          quantity: 1,
          stress: 2,
        ),
      ],
    );

    final types = InsightEngine.generate(
      state,
      AnalyticsService.buildSnapshot(state),
    ).map((insight) => insight.type);

    expect(types, contains(InsightType.timeOfDay));
    expect(types, contains(InsightType.stressLinked));
    expect(types, contains(InsightType.repeatedSameDay));
  });

  test('generates reduced frequency and increased quantity insights', () {
    final tracker = habit();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final state = AppState(
      habits: [tracker],
      settings: const AppSettings(),
      entries: [
        for (var i = 0; i < 5; i++)
          UsageEntry(
            id: 'p$i',
            habitId: tracker.id,
            loggedAt: previousWeekStart.add(Duration(days: i, hours: 18)),
            quantity: 1,
          ),
        for (var i = 0; i < 2; i++)
          UsageEntry(
            id: 'c$i',
            habitId: tracker.id,
            loggedAt: weekStart,
            quantity: 3,
          ),
      ],
    );

    final types = InsightEngine.generate(
      state,
      AnalyticsService.buildSnapshot(state),
    ).map((insight) => insight.type);

    expect(types, contains(InsightType.reducedFrequency));
    expect(types, contains(InsightType.increasedQuantity));
  });

  test('generates money-aware insights without punitive language', () {
    final alcohol = habit(
      id: 'alcohol',
      name: 'Alcohol',
      category: HabitCategory.alcohol,
      unit: 'drinks',
      costPerUnit: 8,
    );
    final cannabis = habit(
      id: 'cannabis',
      name: 'Cannabis',
      category: HabitCategory.cannabis,
      unit: 'uses',
      costPerUnit: 6,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final state = AppState(
      habits: [alcohol, cannabis],
      settings: const AppSettings(),
      entries: [
        UsageEntry(
          id: 'previous',
          habitId: alcohol.id,
          loggedAt: previousWeekStart.add(const Duration(hours: 19)),
          quantity: 2,
        ),
        for (var i = 0; i < 4; i++)
          UsageEntry(
            id: 'current$i',
            habitId: cannabis.id,
            loggedAt: weekStart,
            quantity: 4,
          ),
      ],
    );

    final insights = InsightEngine.generate(
      state,
      AnalyticsService.buildSnapshot(state),
    );
    final types = insights.map((insight) => insight.type);
    final language = insights.map((insight) => insight.body).join(' ');

    expect(types, contains(InsightType.moneyIncreased));
    expect(types, contains(InsightType.moneyConcentration));
    expect(language.contains('failure'), isFalse);
    expect(language.contains('punishment'), isFalse);
  });

  test('dismissed insights stay hidden until evidence changes', () {
    const insight = BehaviorInsight(
      id: 'time_of_day_evening',
      evidenceKey: 'evening:3',
      title: 'Evenings show up often',
      body: 'More logs happen later in the day.',
      kind: InsightKind.pattern,
      type: InsightType.timeOfDay,
      why: 'The evening bucket has the most logs.',
      nextAction: 'Plan one gentle evening support.',
    );

    final hidden = InsightEngine.applyPreferences(
      const [insight],
      [
        InsightPreference(
          id: insight.id,
          evidenceKey: insight.evidenceKey,
          dismissed: true,
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final changed = InsightEngine.applyPreferences(
      const [insight],
      [
        InsightPreference(
          id: insight.id,
          evidenceKey: 'evening:2',
          dismissed: true,
          updatedAt: DateTime(2026),
        ),
      ],
    );

    expect(hidden, isEmpty);
    expect(changed, hasLength(1));
  });

  test('pinned insights appear first', () {
    const first = BehaviorInsight(
      id: 'steady',
      evidenceKey: 'steady',
      title: 'Steady',
      body: 'No strong shift stands out yet.',
      kind: InsightKind.context,
      type: InsightType.steady,
      why: 'No strong shift crossed the threshold.',
      nextAction: 'Keep logging lightly.',
      priority: 1,
    );
    const second = BehaviorInsight(
      id: 'quantity',
      evidenceKey: 'quantity',
      title: 'Quantity changed',
      body: 'Quantity is higher this week.',
      kind: InsightKind.pattern,
      type: InsightType.increasedQuantity,
      why: 'Average quantity is higher.',
      nextAction: 'Try a smaller preset first.',
      priority: 100,
    );

    final ordered = InsightEngine.applyPreferences(
      const [second, first],
      [
        InsightPreference(
          id: first.id,
          evidenceKey: first.evidenceKey,
          pinned: true,
          updatedAt: DateTime(2026),
        ),
      ],
    );

    expect(ordered.first.id, first.id);
  });
}
