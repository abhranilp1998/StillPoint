import '../core/models.dart';
import 'analytics_service.dart';

class BehaviorInsight {
  const BehaviorInsight({
    required this.title,
    required this.body,
    required this.kind,
    this.suggestions = const [],
    this.habitsNoticed = const [],
  });

  final String title;
  final String body;
  final InsightKind kind;
  final List<String> suggestions;
  final List<String> habitsNoticed;
}

enum InsightKind { pattern, progress, context, privacy }

class InsightEngine {
  static List<BehaviorInsight> generate(
    AppState state,
    AnalyticsSnapshot analytics,
  ) {
    if (state.entries.length < 3) {
      return const [
        BehaviorInsight(
          title: 'Patterns will appear gradually',
          body:
              'A few logs are enough to begin showing time, mood, and trigger shifts without judging the day.',
          kind: InsightKind.context,
          suggestions: [
            'Add one log when it feels easy, even if details are incomplete.',
            'Use optional context only when it helps you remember the moment.',
            'Set money per unit for trackers where cost matters.',
          ],
          habitsNoticed: ['Waiting for a few local logs'],
        ),
        BehaviorInsight(
          title: 'Private by default',
          body:
              'Your tracker is local-first, with optional reminders and exports kept under your control.',
          kind: InsightKind.privacy,
          suggestions: [
            'Turn on biometric lock if this device is shared.',
            'Keep notification content hidden if privacy matters in public.',
            'Use exports only when you decide they are useful.',
          ],
          habitsNoticed: ['All logs stay on this device'],
        ),
      ];
    }

    final insights = <BehaviorInsight>[];

    if (analytics.reductionPercent > 8) {
      insights.add(
        BehaviorInsight(
          title: 'Usage is lower than last week',
          body:
              'This week is ${analytics.reductionPercent.toStringAsFixed(0)}% lower than the previous week. Small reductions are staying visible.',
          kind: InsightKind.progress,
          suggestions: [
            'Notice what made the lower week easier.',
            'Repeat one helpful condition tomorrow.',
            'Keep the target flexible; the direction matters more than a perfect day.',
          ],
          habitsNoticed: _topHabitNames(state),
        ),
      );
    } else if (analytics.reductionPercent < -12) {
      insights.add(
        BehaviorInsight(
          title: 'Patterns shifted upward this week',
          body:
              'This week is ${analytics.reductionPercent.abs().toStringAsFixed(0)}% higher than the previous week. It may be worth looking at timing and context.',
          kind: InsightKind.pattern,
          suggestions: [
            'Check whether a time window or trigger changed.',
            'Use the support screen before the next high-risk window.',
            'Consider logging context for the next few entries.',
          ],
          habitsNoticed: _topHabitNames(state),
        ),
      );
    }

    final eveningQuantity = analytics.hourly
        .where((bucket) => bucket.hour >= 18 || bucket.hour < 2)
        .fold<double>(0, (total, bucket) => total + bucket.quantity);
    final daytimeQuantity = analytics.hourly
        .where((bucket) => bucket.hour >= 8 && bucket.hour < 18)
        .fold<double>(0, (total, bucket) => total + bucket.quantity);
    if (eveningQuantity > daytimeQuantity && eveningQuantity > 0) {
      insights.add(
        const BehaviorInsight(
          title: 'Evenings appear more active',
          body:
              'More logs happen later in the day. A softer evening routine may be useful to test.',
          kind: InsightKind.pattern,
          suggestions: [
            'Choose a phone-down or supply-away time before the evening starts.',
            'Try a 10 minute delay timer before the first evening use.',
            'Keep one replacement action visible and easy.',
          ],
          habitsNoticed: ['Evening window'],
        ),
      );
    }

    if (analytics.triggers.isNotEmpty) {
      final top = analytics.triggers.first;
      insights.add(
        BehaviorInsight(
          title: '${top.name} appears often',
          body:
              'This context is linked with ${top.logs} recent logs. Treat it as information, not a verdict.',
          kind: InsightKind.context,
          suggestions: [
            'Prepare one small barrier for ${top.name.toLowerCase()} moments.',
            'Log the next ${top.name.toLowerCase()} moment with mood or stress.',
            'Try changing location before deciding what comes next.',
          ],
          habitsNoticed: [top.name],
        ),
      );
    }

    final stressedEntries = state.entries
        .where((entry) => (entry.stress ?? 0) >= 4)
        .toList();
    final steadyEntries = state.entries
        .where((entry) => (entry.stress ?? 6) <= 2)
        .toList();
    if (stressedEntries.length >= 2 && steadyEntries.length >= 2) {
      final stressedAvg =
          stressedEntries.fold<double>(
            0,
            (total, entry) => total + entry.quantity,
          ) /
          stressedEntries.length;
      final steadyAvg =
          steadyEntries.fold<double>(
            0,
            (total, entry) => total + entry.quantity,
          ) /
          steadyEntries.length;
      if (stressedAvg > steadyAvg * 1.2) {
        insights.add(
          const BehaviorInsight(
            title: 'Stress may be influencing quantity',
            body:
                'Higher-stress logs are carrying more quantity than steadier logs in your data.',
            kind: InsightKind.pattern,
            suggestions: [
              'Use the breathing card before logging during high stress.',
              'Lower stimulation first; decide after the body settles.',
              'Add stress context for a few more logs to confirm the pattern.',
            ],
            habitsNoticed: ['High-stress logs'],
          ),
        );
      }
    }

    if (analytics.currentTargetDays > 0) {
      insights.add(
        BehaviorInsight(
          title: 'Target continuity is building',
          body:
              '${analytics.currentTargetDays} recent day${analytics.currentTargetDays == 1 ? '' : 's'} stayed within your flexible target.',
          kind: InsightKind.progress,
          suggestions: [
            'Keep the target gentle enough to repeat.',
            'Notice the conditions around the days that worked.',
            'Avoid turning one hard day into a reset.',
          ],
          habitsNoticed: _topHabitNames(state),
        ),
      );
    }

    if (analytics.weekEstimatedCost > 0) {
      insights.add(
        BehaviorInsight(
          title: 'Money pattern is visible',
          body:
              '\$${analytics.weekEstimatedCost.toStringAsFixed(2)} could have stayed with you this week based on the unit costs you entered.',
          kind: InsightKind.progress,
          suggestions: [
            'Use this as information, not guilt.',
            'Pick one lower-cost window to test next.',
            'Update unit costs on trackers when prices change.',
          ],
          habitsNoticed: _costedHabitNames(state),
        ),
      );
    } else if (analytics.totalLogs > 0 && analytics.habitsWithCost == 0) {
      insights.add(
        const BehaviorInsight(
          title: 'Money tracking is optional',
          body:
              'Add a cost per unit to any tracker to see how much money could have stayed with you.',
          kind: InsightKind.context,
          suggestions: [
            'Open a tracker and set cost per unit when money is relevant.',
            'Use rough estimates; exact accounting is not required.',
            'Leave cost blank for patterns where money is not useful.',
          ],
          habitsNoticed: ['No tracker costs set yet'],
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        BehaviorInsight(
          title: 'Your data looks steady',
          body:
              'No strong shift stands out yet. Keeping the pattern visible is still useful.',
          kind: InsightKind.context,
          suggestions: [
            'Keep logging lightly and look for timing changes.',
            'Add context only when a moment feels meaningful.',
            'Use custom trackers for patterns that do not fit the presets.',
          ],
          habitsNoticed: _topHabitNames(state),
        ),
      );
    }

    return insights.take(4).toList();
  }
}

List<String> _topHabitNames(AppState state) {
  final counts = <String, int>{};
  final habitsById = {for (final habit in state.activeHabits) habit.id: habit};
  for (final entry in state.entries) {
    final habit = habitsById[entry.habitId];
    if (habit == null) continue;
    counts.update(habit.name, (value) => value + 1, ifAbsent: () => 1);
  }
  final names = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return names.take(3).map((entry) => entry.key).toList(growable: false);
}

List<String> _costedHabitNames(AppState state) {
  return state.activeHabits
      .where((habit) => (habit.costPerUnit ?? 0) > 0)
      .take(3)
      .map((habit) => habit.name)
      .toList(growable: false);
}
