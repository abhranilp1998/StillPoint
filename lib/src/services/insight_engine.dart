import '../core/models.dart';
import 'analytics_service.dart';

class BehaviorInsight {
  const BehaviorInsight({
    required this.title,
    required this.body,
    required this.kind,
  });

  final String title;
  final String body;
  final InsightKind kind;
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
        ),
        BehaviorInsight(
          title: 'Private by default',
          body:
              'Your tracker is local-first, with optional reminders and exports kept under your control.',
          kind: InsightKind.privacy,
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
        ),
      );
    } else if (analytics.reductionPercent < -12) {
      insights.add(
        BehaviorInsight(
          title: 'Patterns shifted upward this week',
          body:
              'This week is ${analytics.reductionPercent.abs().toStringAsFixed(0)}% higher than the previous week. It may be worth looking at timing and context.',
          kind: InsightKind.pattern,
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
        ),
      );
    }

    return insights.take(4).toList();
  }
}
