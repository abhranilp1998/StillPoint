import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../services/analytics_service.dart';
import '../../services/insight_engine.dart';
import '../../state/app_controller.dart';
import '../habit/habit_detail_screen.dart';
import '../logging/quick_log_sheet.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return appState.when(
      data: (state) {
        final analytics = ref.watch(analyticsProvider);
        final insights = ref.watch(insightsProvider);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Stillpoint'),
              actions: [
                IconButton(
                  tooltip: 'Repeat last',
                  onPressed: state.lastEntry == null
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          await ref
                              .read(appControllerProvider.notifier)
                              .repeatLastEntry();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Last log repeated.'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.replay_rounded),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ScreenPadding(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSummary(analytics: analytics),
                    const SizedBox(height: 16),
                    _QuickLogSection(habits: state.activeHabits),
                    const SizedBox(height: 16),
                    _TrackersSection(habits: state.activeHabits),
                    const SizedBox(height: 16),
                    _InsightStrip(insights: insights),
                    const SizedBox(height: 16),
                    _TrendCard(analytics: analytics),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('The local tracker could not be opened: $error'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayLabel = analytics.todayTotal == 0
        ? 'No logs yet'
        : analytics.todayTotal.toStringAsFixed(
            analytics.todayTotal == analytics.todayTotal.roundToDouble()
                ? 0
                : 1,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: .82),
            theme.colorScheme.secondaryContainer.withValues(alpha: .70),
            theme.colorScheme.tertiaryContainer.withValues(alpha: .58),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: .72,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    todayLabel,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.timeline_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 34,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              analytics.todayTotal == 0
                  ? 'Today is ready when you are.'
                  : 'Logged today across your active trackers.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: .78,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.85,
              ),
              children: [
                MetricTile(
                  label: 'This week',
                  value: analytics.weekTotal.toStringAsFixed(0),
                  icon: Icons.calendar_view_week_rounded,
                ),
                MetricTile(
                  label: 'Active window',
                  value: analytics.totalLogs == 0
                      ? 'Learning'
                      : analytics.mostActiveWindow,
                  icon: Icons.schedule_rounded,
                  accent: theme.colorScheme.secondary,
                ),
                MetricTile(
                  label: 'Average mood',
                  value: analytics.averageMood == 0
                      ? 'Unset'
                      : moodLabel(analytics.averageMood.round()),
                  icon: Icons.mood_outlined,
                  accent: theme.colorScheme.tertiary,
                ),
                MetricTile(
                  label: 'Craving level',
                  value: analytics.averageCraving == 0
                      ? 'Unset'
                      : intensityLabel(analytics.averageCraving.round()),
                  icon: Icons.waves_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogSection extends StatelessWidget {
  const _QuickLogSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Quick log',
            trailing: IconButton(
              tooltip: 'Add custom tracker',
              onPressed: () => showAddHabitSheet(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final habit in habits) ...[
                  SizedBox(
                    width: 174,
                    child: HabitPill(
                      habit: habit,
                      onTap: () =>
                          showQuickLogSheet(context, initialHabit: habit),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackersSection extends StatelessWidget {
  const _TrackersSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Trackers'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: habits.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _TrackerTile(habit: habit);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackerTile extends StatelessWidget {
  const _TrackerTile({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(habit.colorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailScreen(habitId: habit.id),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? .18 : .10,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(habitIcon(habit.category), color: color),
            const Spacer(),
            Text(
              habit.name,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              habit.reductionMode.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.insights});

  final List<BehaviorInsight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Observations'),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final insight = insights[index];
              return SizedBox(
                width: minOf(312, MediaQuery.sizeOf(context).width * .78),
                child: CalmCard(
                  color: switch (insight.kind) {
                    InsightKind.progress =>
                      theme.colorScheme.primaryContainer.withValues(alpha: .55),
                    InsightKind.pattern =>
                      theme.colorScheme.secondaryContainer.withValues(
                        alpha: .52,
                      ),
                    InsightKind.privacy =>
                      theme.colorScheme.tertiaryContainer.withValues(
                        alpha: .48,
                      ),
                    InsightKind.context => theme.colorScheme.surface,
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(switch (insight.kind) {
                        InsightKind.progress => Icons.trending_down_rounded,
                        InsightKind.pattern => Icons.query_stats_rounded,
                        InsightKind.privacy => Icons.lock_outline_rounded,
                        InsightKind.context => Icons.lightbulb_outline_rounded,
                      }),
                      const SizedBox(height: 10),
                      Text(
                        insight.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          insight.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double minOf(double a, double b) => a < b ? a : b;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = analytics.daily.skip(analytics.daily.length - 21).toList();
    final maxValue = recent.fold<double>(
      1,
      (value, day) => day.quantity > value ? day.quantity : value,
    );
    final spots = [
      for (var i = 0; i < recent.length; i++)
        FlSpot(i.toDouble(), recent[i].quantity),
    ];

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recent trend'),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxValue * 1.18,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .4,
                    ),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: .22,
                    barWidth: 3,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: .12),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            analytics.totalLogs == 0
                ? 'Your first few logs will turn this into a useful pattern.'
                : analytics.reductionPercent >= 0
                ? 'This week is ${analytics.reductionPercent.toStringAsFixed(0)}% lower than last week.'
                : 'This week is ${analytics.reductionPercent.abs().toStringAsFixed(0)}% higher than last week.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
