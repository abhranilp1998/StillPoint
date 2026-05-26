import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../services/analytics_service.dart';
import '../../state/app_controller.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final analytics = ref.watch(analyticsProvider);
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Patterns')),
        SliverToBoxAdapter(
          child: ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryGrid(analytics: analytics),
                const SizedBox(height: 16),
                AnalyticsHeatmap(analytics: analytics),
                const SizedBox(height: 16),
                _HourlyChart(analytics: analytics),
                const SizedBox(height: 16),
                _TriggerPanel(analytics: analytics),
                const SizedBox(height: 16),
                if (state != null) _ReductionPlanner(state: state),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    return GridView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      children: [
        MetricTile(
          label: 'Week total',
          value: analytics.weekTotal.toStringAsFixed(0),
          icon: Icons.calendar_month_rounded,
        ),
        MetricTile(
          label: 'Previous week',
          value: analytics.previousWeekTotal.toStringAsFixed(0),
          icon: Icons.history_rounded,
        ),
        MetricTile(
          label: 'Target days',
          value: analytics.currentTargetDays == 0
              ? 'Flexible'
              : analytics.currentTargetDays.toString(),
          icon: Icons.flag_outlined,
        ),
        MetricTile(
          label: 'Total logs',
          value: analytics.totalLogs.toString(),
          icon: Icons.receipt_long_outlined,
        ),
        MetricTile(
          label: 'Could stay with you',
          value: analytics.habitsWithCost == 0
              ? 'Set cost'
              : '\$${analytics.weekEstimatedCost.toStringAsFixed(2)}',
          icon: Icons.savings_outlined,
        ),
        MetricTile(
          label: 'Costed trackers',
          value: analytics.habitsWithCost.toString(),
          icon: Icons.price_check_rounded,
        ),
      ],
    );
  }
}

enum HeatmapMode { usage, mood, cravings, pause }

class AnalyticsHeatmap extends StatefulWidget {
  const AnalyticsHeatmap({super.key, required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  State<AnalyticsHeatmap> createState() => _AnalyticsHeatmapState();
}

class _AnalyticsHeatmapState extends State<AnalyticsHeatmap> {
  HeatmapMode _mode = HeatmapMode.usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Heatmap',
            trailing: DropdownButton<HeatmapMode>(
              value: _mode,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: const [
                DropdownMenuItem(
                  value: HeatmapMode.usage,
                  child: Text('Usage'),
                ),
                DropdownMenuItem(value: HeatmapMode.mood, child: Text('Mood')),
                DropdownMenuItem(
                  value: HeatmapMode.cravings,
                  child: Text('Cravings'),
                ),
                DropdownMenuItem(
                  value: HeatmapMode.pause,
                  child: Text('Pauses'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _mode = value);
              },
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = (constraints.maxWidth - 7 * 5) / 8;
              return Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final cell in widget.analytics.heatmap)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: cellSize.clamp(18, 40),
                      height: cellSize.clamp(18, 40),
                      decoration: BoxDecoration(
                        color: _colorFor(theme, cell),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: .28,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _caption,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String get _caption => switch (_mode) {
    HeatmapMode.usage => 'Darker cells show higher daily quantity.',
    HeatmapMode.mood => 'Cells use mood signals when they were logged.',
    HeatmapMode.cravings => 'Cells use craving intensity when it was logged.',
    HeatmapMode.pause => 'Quiet days stay visible without resetting progress.',
  };

  Color _colorFor(ThemeData theme, HeatmapCell cell) {
    if (_mode == HeatmapMode.pause) {
      return cell.quantity == 0
          ? theme.colorScheme.primary.withValues(alpha: .42)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: .58);
    }
    final intensity = switch (_mode) {
      HeatmapMode.usage => cell.intensity,
      HeatmapMode.mood =>
        widget.analytics.daily
            .firstWhere((day) => day.day == cell.day)
            .averageMood
            .round(),
      HeatmapMode.cravings =>
        widget.analytics.daily
            .firstWhere((day) => day.day == cell.day)
            .averageCraving
            .round(),
      HeatmapMode.pause => cell.intensity,
    };

    if (intensity <= 0) {
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: .42);
    }

    final base = switch (_mode) {
      HeatmapMode.usage => theme.colorScheme.primary,
      HeatmapMode.mood => theme.colorScheme.tertiary,
      HeatmapMode.cravings => theme.colorScheme.secondary,
      HeatmapMode.pause => theme.colorScheme.primary,
    };
    return base.withValues(alpha: .18 + intensity.clamp(1, 5) * .14);
  }
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = analytics.hourly.fold<double>(
      1,
      (value, bucket) => bucket.quantity > value ? bucket.quantity : value,
    );

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Time of day'),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                alignment: BarChartAlignment.spaceBetween,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .32,
                    ),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 6,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        _hourLabel(value.toInt()),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (final bucket in analytics.hourly)
                    BarChartGroupData(
                      x: bucket.hour,
                      barRods: [
                        BarChartRodData(
                          toY: bucket.quantity,
                          color: theme.colorScheme.secondary,
                          width: 7,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(int hour) {
    return switch (hour) {
      0 => '12a',
      6 => '6a',
      12 => '12p',
      18 => '6p',
      _ => '',
    };
  }
}

class _TriggerPanel extends StatelessWidget {
  const _TriggerPanel({required this.analytics});

  final AnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Context links'),
          const SizedBox(height: 8),
          if (analytics.triggers.isEmpty)
            Text(
              'Add optional context while logging to see trigger associations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final trigger in analytics.triggers) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withValues(alpha: .7),
                  child: const Icon(Icons.tag_rounded),
                ),
                title: Text(trigger.name),
                subtitle: Text('${trigger.logs} logs'),
                trailing: Text(trigger.quantity.toStringAsFixed(0)),
              ),
              if (trigger != analytics.triggers.last)
                Divider(color: theme.colorScheme.outlineVariant),
            ],
        ],
      ),
    );
  }
}

class _ReductionPlanner extends ConsumerWidget {
  const _ReductionPlanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Reduction modes'),
          const SizedBox(height: 8),
          Text(
            'Targets are flexible; progress history stays intact.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final habit in state.activeHabits.take(5))
            _HabitGoalRow(habit: habit),
        ],
      ),
    );
  }
}

class _HabitGoalRow extends ConsumerWidget {
  const _HabitGoalRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: .34,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    habitIcon(habit.category),
                    color: Color(habit.colorValue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownButton<ReductionMode>(
                    value: habit.reductionMode,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      for (final mode in ReductionMode.values)
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                    ],
                    onChanged: (mode) {
                      if (mode == null) return;
                      ref
                          .read(appControllerProvider.notifier)
                          .updateHabit(habit.copyWith(reductionMode: mode));
                    },
                  ),
                ],
              ),
              if (habit.reductionMode != ReductionMode.monitor) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: (habit.dailyTarget ?? 3).clamp(0, 30).toDouble(),
                        min: 0,
                        max: 30,
                        divisions: 30,
                        label: (habit.dailyTarget ?? 3).round().toString(),
                        onChanged: (value) {
                          ref
                              .read(appControllerProvider.notifier)
                              .updateHabit(habit.copyWith(dailyTarget: value));
                        },
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        '${(habit.dailyTarget ?? 3).round()} ${habit.unit}',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  habit.reductionMode.calmDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
