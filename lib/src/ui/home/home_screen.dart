import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../services/analytics_service.dart';
import '../../services/guidance_service.dart';
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
                    MotionReveal(
                      child: _TodaySection(
                        state: state,
                        analytics: analytics,
                        insights: insights,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MotionReveal(
                      delay: const Duration(milliseconds: 55),
                      child: _QuickLogSection(habits: state.activeHabits),
                    ),
                    const SizedBox(height: 14),
                    MotionReveal(
                      delay: const Duration(milliseconds: 110),
                      child: _InsightStrip(insights: insights),
                    ),
                    const SizedBox(height: 14),
                    MotionReveal(
                      delay: const Duration(milliseconds: 165),
                      child: _TrackersSection(state: state),
                    ),
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

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.state,
    required this.analytics,
    required this.insights,
  });

  final AppState state;
  final AnalyticsSnapshot analytics;
  final List<BehaviorInsight> insights;

  @override
  Widget build(BuildContext context) {
    final promptSanctuary = _shouldPromptSanctuary(state, insights);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Today',
          trailing: _SanctuaryPromptButton(drawAttention: promptSanctuary),
        ),
        const SizedBox(height: 10),
        _HeroSummary(state: state, analytics: analytics),
        if (analytics.habitsWithCost > 0) ...[
          const SizedBox(height: 12),
          _MoneyReflectionCards(analytics: analytics),
        ],
      ],
    );
  }

  bool _shouldPromptSanctuary(AppState state, List<BehaviorInsight> insights) {
    final last = state.lastEntry;
    if (last != null) {
      final recent = DateTime.now().difference(last.loggedAt).inHours < 6;
      final elevatedCraving = (last.craving ?? 0) >= 4;
      final elevatedStress = (last.stress ?? 0) >= 4;
      final lowMood = last.mood != null && last.mood! <= 2;
      if (recent && (elevatedCraving || elevatedStress || lowMood)) {
        return true;
      }
    }

    final today = DateTime.now();
    final todayLogs = state.entries.where(
      (entry) =>
          entry.loggedAt.year == today.year &&
          entry.loggedAt.month == today.month &&
          entry.loggedAt.day == today.day,
    );
    if (todayLogs.length >= 4) return true;

    return insights.any(
      (insight) =>
          insight.kind == InsightKind.pattern ||
          insight.kind == InsightKind.money,
    );
  }
}

class _SanctuaryPromptButton extends StatelessWidget {
  const _SanctuaryPromptButton({required this.drawAttention});

  final bool drawAttention;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: drawAttention
          ? 'Open Sanctuary for a calmer pause'
          : 'Open Sanctuary',
      child: AttentionGlow(
        active: drawAttention,
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(18),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: drawAttention
                ? scheme.tertiaryContainer.withValues(alpha: .88)
                : scheme.surfaceContainerHighest.withValues(alpha: .72),
            foregroundColor: drawAttention
                ? scheme.onTertiaryContainer
                : scheme.onSurface,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SanctuaryScreen()),
          ),
          icon: Icon(
            drawAttention ? Icons.spa_rounded : Icons.self_improvement_rounded,
            size: 20,
          ),
          label: const Text('Sanctuary'),
        ),
      ),
    );
  }
}

class _MoneyReflectionCards extends StatelessWidget {
  const _MoneyReflectionCards({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        return GridView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 132,
          ),
          children: [
            _MoneyMetricTile(
              label: 'Today cost',
              value: _formatMoney(analytics.todayEstimatedCost),
              icon: Icons.today_outlined,
              emphasis: analytics.todayEstimatedCost > 0,
            ),
            _MoneyMetricTile(
              label: '7-day total',
              value: _formatMoney(analytics.sevenDayEstimatedCost),
              icon: Icons.date_range_outlined,
              emphasis: analytics.sevenDayEstimatedCost > 0,
            ),
            _MoneyMetricTile(
              label: 'Month-to-date',
              value: _formatMoney(analytics.monthEstimatedCost),
              icon: Icons.calendar_month_outlined,
              emphasis: analytics.monthEstimatedCost > 0,
            ),
            _MoneyMetricTile(
              label: analytics.topCostHabitName ?? 'Top cost tracker',
              value: analytics.topCostHabitName == null
                  ? 'None yet'
                  : _formatMoney(analytics.topCostHabitAmount),
              icon: Icons.savings_outlined,
              emphasis: analytics.topCostHabitAmount > 0,
            ),
          ],
        );
      },
    );
  }

  String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';
}

class _MoneyMetricTile extends StatelessWidget {
  const _MoneyMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.emphasis,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return CalmCard(
      padding: const EdgeInsets.all(14),
      glowColor: scheme.tertiary,
      glowIntensity: emphasis ? .35 : 0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.tertiaryContainer.withValues(alpha: isDark ? .26 : .46),
          scheme.surfaceContainerHighest.withValues(alpha: isDark ? .42 : .72),
        ],
      ),
      borderColor: scheme.tertiary.withValues(alpha: emphasis ? .30 : .16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, color: scheme.tertiary, size: 20),
            ),
          ),
          const Spacer(),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.primaryContainer.withValues(alpha: .82),
          theme.colorScheme.secondaryContainer.withValues(alpha: .44),
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: .58),
        ],
      ),
      borderColor: theme.colorScheme.primary.withValues(alpha: .22),
      glowColor: theme.colorScheme.primary,
      glowIntensity: analytics.todayTotal == 0 ? .18 : .32,
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

class _QuickLogSection extends StatelessWidget {
  const _QuickLogSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return EmptyStateCard(
        icon: Icons.add_circle_outline_rounded,
        title: 'No trackers yet',
        body: 'Add one small thing to track, then quick logs will appear here.',
        action: FilledButton.icon(
          onPressed: () => showAddHabitSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add tracker'),
        ),
      );
    }

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
  const _TrackersSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final habits = state.activeHabits;
    final visibleHabits = habits.take(6).toList(growable: false);
    if (habits.isEmpty) {
      return EmptyStateCard(
        icon: Icons.grid_view_rounded,
        title: 'Trackers will live here',
        body: 'Create a tracker when you know what would be useful to notice.',
        action: OutlinedButton.icon(
          onPressed: () => showAddHabitSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add tracker'),
        ),
      );
    }

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
                mainAxisExtent: 116,
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
                  lastEntry: latestEntryForHabit(habit, state.entries),
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

class _InsightStrip extends ConsumerWidget {
  const _InsightStrip({required this.insights});

  final List<BehaviorInsight> insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (insights.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Observations'),
          SizedBox(height: 10),
          EmptyStateCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Patterns need a little time',
            body:
                'A few logs with optional mood, craving, or context will make this space more useful.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Observations'),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final insight = insights[index];
              final baseColor = switch (insight.kind) {
                InsightKind.progress => theme.colorScheme.primaryContainer,
                InsightKind.pattern => theme.colorScheme.secondaryContainer,
                InsightKind.privacy => theme.colorScheme.tertiaryContainer,
                InsightKind.money => theme.colorScheme.tertiaryContainer,
                InsightKind.context => theme.colorScheme.surfaceContainerHigh,
              };
              return SizedBox(
                width: minOf(312, MediaQuery.sizeOf(context).width * .78),
                child: CalmCard(
                  onTap: () => _showInsightDetails(context, ref, insight),
                  semanticLabel: 'Open observation ${insight.title}',
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor.withValues(alpha: .58),
                      theme.colorScheme.surfaceContainerLow.withValues(
                        alpha: .86,
                      ),
                    ],
                  ),
                  borderColor: baseColor.withValues(alpha: .30),
                  glowColor: baseColor,
                  glowIntensity:
                      insight.isPinned || insight.kind == InsightKind.money
                      ? .22
                      : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_iconForInsight(insight)),
                          const Spacer(),
                          if (insight.isPinned)
                            Icon(
                              Icons.push_pin_rounded,
                              size: 17,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              insight.confidence ?? 'Tap for details',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
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

  void _showInsightDetails(
    BuildContext context,
    WidgetRef ref,
    BehaviorInsight insight,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = _iconForInsight(insight);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
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
            CalmCard(
              padding: const EdgeInsets.all(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: .58),
                  scheme.surfaceContainerHighest.withValues(alpha: .54),
                ],
              ),
              borderColor: scheme.primary.withValues(alpha: .18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: scheme.primary, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: insight.isPinned ? 'Unpin insight' : 'Pin insight',
                    onPressed: () async {
                      await ref
                          .read(appControllerProvider.notifier)
                          .toggleInsightPin(insight);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            insight.isPinned
                                ? 'Observation unpinned.'
                                : 'Observation pinned near the top.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      insight.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss insight',
                    onPressed: () async {
                      await ref
                          .read(appControllerProvider.notifier)
                          .dismissInsight(insight);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Observation hidden until the evidence changes.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(insight.body, style: theme.textTheme.bodyLarge),
            if (insight.confidence != null ||
                insight.evidenceSummary != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (insight.confidence != null)
                    Chip(
                      avatar: const Icon(Icons.insights_rounded, size: 17),
                      label: Text(insight.confidence!),
                    ),
                  if (insight.evidenceSummary != null)
                    Chip(
                      avatar: const Icon(Icons.fact_check_outlined, size: 17),
                      label: Text(insight.evidenceSummary!),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _InsightDetailBlock(
              title: 'Why am I seeing this?',
              icon: Icons.psychology_alt_outlined,
              child: Text(insight.why),
            ),
            const SizedBox(height: 12),
            _InsightDetailBlock(
              title: 'Suggested next action',
              icon: Icons.next_plan_outlined,
              child: Text(insight.nextAction),
            ),
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
            if (insight.searchQuery != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  final opened = await GuidanceService.openHarmReductionSearch(
                    insight.searchQuery!,
                  );
                  if (!context.mounted || opened) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the browser right now.'),
                    ),
                  );
                },
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Search harm-reduction info'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForInsight(BehaviorInsight insight) {
    return switch (insight.kind) {
      InsightKind.progress => Icons.trending_down_rounded,
      InsightKind.pattern => Icons.query_stats_rounded,
      InsightKind.privacy => Icons.lock_outline_rounded,
      InsightKind.money => Icons.savings_outlined,
      InsightKind.context => Icons.lightbulb_outline_rounded,
    };
  }
}

class _InsightDetailBlock extends StatelessWidget {
  const _InsightDetailBlock({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
