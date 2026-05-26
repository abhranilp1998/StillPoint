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
import '../support/support_screen.dart';
import '../trackers/tracker_catalog_screen.dart';
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
                    _HeroSummary(state: state, analytics: analytics),
                    const SizedBox(height: 14),
                    _HomeActions(state: state),
                    const SizedBox(height: 14),
                    _QuickLogSection(habits: state.activeHabits),
                    const SizedBox(height: 14),
                    _TrackersSection(habits: state.activeHabits),
                    const SizedBox(height: 14),
                    _InsightStrip(insights: insights),
                    const SizedBox(height: 14),
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
  const _HeroSummary({required this.state, required this.analytics});

  final AppState state;
  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 5 => 'You are here. That counts.',
      < 12 => 'Good morning. Start gently.',
      < 17 => 'Good afternoon. One clear log at a time.',
      < 21 => 'Good evening. No judgment here.',
      _ => 'Quiet night. Keep it soft.',
    };
    final lastLog = state.lastEntry == null
        ? 'No logs yet today'
        : 'Last logged ${DateFormat('h:mm a').format(state.lastEntry!.loggedAt)}';
    final todayLabel = analytics.todayTotal == 0
        ? 'No logs yet'
        : analytics.todayTotal.toStringAsFixed(
            analytics.todayTotal == analytics.todayTotal.roundToDouble()
                ? 0
                : 1,
          );

    return CalmCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: .72),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All local. Nobody is judging.',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: .78,
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
                  style: theme.textTheme.headlineLarge?.copyWith(fontSize: 40),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.favorite_border_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analytics.todayTotal == 0
                ? 'When you are ready, record one moment. Not the whole story.'
                : 'Logged today across your active trackers. $lastLog.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: .78,
              ),
            ),
          ),
          if (analytics.weekEstimatedCost > 0) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_formatMoney(analytics.weekEstimatedCost)} could have stayed with you this week.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';
}

class _HomeActions extends StatelessWidget {
  const _HomeActions({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final children = [
          CalmCard(
            onTap: () => showQuickLogSheet(context),
            padding: const EdgeInsets.all(14),
            semanticLabel: 'Open quick log',
            child: const _ActionContent(
              icon: Icons.add_rounded,
              title: 'Log now',
              body: 'A few taps, no scorekeeping.',
            ),
          ),
          CalmCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TrackerCatalogScreen(),
              ),
            ),
            padding: const EdgeInsets.all(14),
            semanticLabel: 'Open trackers',
            child: _ActionContent(
              icon: Icons.grid_view_rounded,
              title: 'Trackers',
              body: '${state.activeHabits.length} ready, custom anytime.',
            ),
          ),
          CalmCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
            padding: const EdgeInsets.all(14),
            semanticLabel: 'Open support',
            child: const _ActionContent(
              icon: Icons.self_improvement_rounded,
              title: 'Support',
              body: 'Pause, breathe, choose next.',
            ),
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 10),
              ],
            ]..removeLast(),
          );
        }

        return Row(
          children: [
            for (final child in children) ...[
              Expanded(child: child),
              const SizedBox(width: 10),
            ],
          ]..removeLast(),
        );
      },
    );
  }
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLogSection extends StatelessWidget {
  const _QuickLogSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 10),
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
    );
  }
}

class _TrackersSection extends StatelessWidget {
  const _TrackersSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final visibleHabits = habits.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Trackers',
          trailing: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TrackerCatalogScreen(),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('All'),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 520;
            return GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleHabits.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 3 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 88,
              ),
              itemBuilder: (context, index) {
                if (index == visibleHabits.length) {
                  return AddTrackerTile(
                    onTap: () => showAddHabitSheet(context),
                  );
                }
                final habit = visibleHabits[index];
                return TrackerTile(
                  habit: habit,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HabitDetailScreen(habitId: habit.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
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
                  onTap: () => _showInsightDetails(context, insight),
                  semanticLabel: 'Open observation ${insight.title}',
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
                      const SizedBox(height: 4),
                      Text(
                        'Tap for details',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
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

  void _showInsightDetails(BuildContext context, BehaviorInsight insight) {
    final theme = Theme.of(context);
    final icon = switch (insight.kind) {
      InsightKind.progress => Icons.trending_down_rounded,
      InsightKind.pattern => Icons.query_stats_rounded,
      InsightKind.privacy => Icons.lock_outline_rounded,
      InsightKind.context => Icons.lightbulb_outline_rounded,
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(insight.title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(insight.body, style: theme.textTheme.bodyLarge),
            if (insight.habitsNoticed.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Habits noticed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final habit in insight.habitsNoticed)
                    Chip(label: Text(habit)),
                ],
              ),
            ],
            if (insight.suggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Suggestions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final suggestion in insight.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(suggestion)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
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
