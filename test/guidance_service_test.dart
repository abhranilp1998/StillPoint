import 'package:flutter_test/flutter_test.dart';
import 'package:stillpoint/src/core/models.dart';
import 'package:stillpoint/src/services/guidance_service.dart';
import 'package:stillpoint/src/services/insight_engine.dart';

void main() {
  test(
    'insight resources reuse matching tracker guidance when a habit is named',
    () {
      final alcohol = Habit(
        id: 'alcohol',
        name: 'Alcohol',
        category: HabitCategory.alcohol,
        unit: 'drinks',
        colorValue: 0xFFC77D57,
        createdAt: DateTime(2026),
      );
      final state = AppState(
        habits: [alcohol],
        entries: const [],
        settings: const AppSettings(),
      );
      final insight = BehaviorInsight(
        id: 'weekday_active',
        evidenceKey: 'friday',
        title: 'Friday has been more active',
        body: 'Friday carries more logged moments than other weekdays.',
        kind: InsightKind.pattern,
        type: InsightType.weekday,
        why: 'Grouped by weekday, Friday has the clearest concentration.',
        nextAction: 'Treat Friday as a planning cue.',
        habitsNoticed: const ['Alcohol'],
      );

      final resources = GuidanceService.resourcesForInsight(
        insight: insight,
        state: state,
      );

      expect(resources, isNotEmpty);
      expect(resources.first.title, 'Alcohol and your health');
      expect(resources.first.source, 'CDC');
    },
  );

  test(
    'insight resources fall back to curated generic guidance when no habit matches',
    () {
      final caffeine = Habit(
        id: 'caffeine',
        name: 'Caffeine',
        category: HabitCategory.caffeine,
        unit: 'cups',
        colorValue: 0xFFB88A44,
        createdAt: DateTime(2026),
      );
      final state = AppState(
        habits: [caffeine],
        entries: const [],
        settings: const AppSettings(),
      );
      final insight = BehaviorInsight(
        id: 'trigger_after_work',
        evidenceKey: 'after_work',
        title: 'After work appears often',
        body: 'This context is linked with recent logs.',
        kind: InsightKind.context,
        type: InsightType.triggerContext,
        why: 'After work has the strongest link among logged context chips.',
        nextAction: 'Prepare one small barrier for after work moments.',
        habitsNoticed: const ['After work'],
        searchQuery: 'after work cravings harm reduction coping support',
      );

      final resources = GuidanceService.resourcesForInsight(
        insight: insight,
        state: state,
      );

      expect(resources, hasLength(3));
      expect(resources.first.title, 'Commonly used drugs and effects');
      expect(resources[1].source, 'SAMHSA');
    },
  );
}
