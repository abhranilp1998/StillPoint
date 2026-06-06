import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/habit_library.dart';
import '../../core/models.dart';
import '../../services/guidance_service.dart';
import '../../state/app_controller.dart';
import '../logging/quick_log_sheet.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';
import 'entry_editor_sheet.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final habit = state.habits.firstWhere(
      (item) => item.id == habitId,
      orElse: () => Habit(
        id: habitId,
        name: 'Tracker',
        category: HabitCategory.custom,
        unit: 'units',
        colorValue: 0xFF7E8A97,
        createdAt: DateTime.now(),
      ),
    );
    final entries =
        state.entries.where((entry) => entry.habitId == habit.id).toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final profile = GuidanceService.profileFor(habit.category);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(habit.name),
            actions: [
              IconButton(
                tooltip: 'Quick log',
                onPressed: () =>
                    showQuickLogSheet(context, initialHabit: habit),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: ScreenPadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MotionReveal(
                    child: _HabitHero(habit: habit, entries: entries),
                  ),
                  const SizedBox(height: 16),
                  MotionReveal(
                    delay: const Duration(milliseconds: 60),
                    child: _DetailChart(entries: entries),
                  ),
                  const SizedBox(height: 16),
                  MotionReveal(
                    delay: const Duration(milliseconds: 120),
                    child: _RiskCard(profile: profile),
                  ),
                  const SizedBox(height: 16),
                  MotionReveal(
                    delay: const Duration(milliseconds: 180),
                    child: _ResourcesCard(
                      habit: habit,
                      entries: entries,
                      profile: profile,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MotionReveal(
                    delay: const Duration(milliseconds: 240),
                    child: _RecentLogs(habit: habit, entries: entries),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitHero extends ConsumerWidget {
  const _HabitHero({required this.habit, required this.entries});

  final Habit habit;
  final List<UsageEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = entries.totalQuantity;
    final estimatedCost = entries.fold<double>(
      0,
      (value, entry) => value + (entry.estimatedCostFor(habit) ?? 0),
    );
    final last = entries.isEmpty
        ? 'No logs yet'
        : DateFormat('MMM d, h:mm a').format(entries.first.loggedAt);
    return CalmCard(
      color: Color(
        habit.colorValue,
      ).withValues(alpha: theme.brightness == Brightness.dark ? .22 : .12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Color(habit.colorValue).withValues(alpha: .18),
                child: Icon(
                  habitIcon(habit.category),
                  color: Color(habit.colorValue),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text(
                      habit.reductionMode.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.65,
            ),
            children: [
              MetricTile(
                label: 'Total logged',
                value: _format(total),
                icon: Icons.summarize_outlined,
              ),
              MetricTile(
                label: 'Entries',
                value: entries.length.toString(),
                icon: Icons.receipt_long_outlined,
              ),
              MetricTile(
                label: 'Last log',
                value: last,
                icon: Icons.schedule_rounded,
              ),
              MetricTile(
                label: 'Unit',
                value: habit.unit,
                icon: Icons.straighten_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CostReflectionPanel(
            habit: habit,
            entries: entries,
            estimatedCost: estimatedCost,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _editCost(context, ref),
              icon: const Icon(Icons.attach_money_rounded),
              label: Text(
                habit.costPerUnit == null ? 'Set unit cost' : 'Edit unit cost',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  Future<void> _editCost(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: habit.costPerUnit == null ? '' : habit.costPerUnit!.toString(),
    );
    final suggestedCost = HabitLibrary.defaultUnitCostFor(habit.category);
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cost for ${habit.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cost per ${habit.unit}',
                prefixText: '\$',
                hintText: suggestedCost == null
                    ? 'Leave blank to remove'
                    : 'Try ${suggestedCost.toStringAsFixed(2)} if useful',
              ),
            ),
            if (suggestedCost != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  controller.text = suggestedCost.toStringAsFixed(2);
                },
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  'Use local estimate \$${suggestedCost.toStringAsFixed(2)}',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, double.tryParse(controller.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (result == 'cancel') return;
    if (result == null) {
      await ref
          .read(appControllerProvider.notifier)
          .updateHabit(habit.copyWith(clearCostPerUnit: true));
      return;
    }
    final cost = result as double?;
    if (cost == null || cost <= 0) return;
    await ref
        .read(appControllerProvider.notifier)
        .updateHabit(habit.copyWith(costPerUnit: cost));
  }
}

class _CostReflectionPanel extends StatelessWidget {
  const _CostReflectionPanel({
    required this.habit,
    required this.entries,
    required this.estimatedCost,
  });

  final Habit habit;
  final List<UsageEntry> entries;
  final double estimatedCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCost = habit.costPerUnit != null && habit.costPerUnit! > 0;
    return CalmCard(
      padding: const EdgeInsets.all(16),
      glowColor: scheme.tertiary,
      glowIntensity: hasCost ? .26 : .08,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.tertiaryContainer.withValues(alpha: hasCost ? .48 : .22),
          scheme.surfaceContainerHighest.withValues(alpha: .58),
        ],
      ),
      borderColor: scheme.tertiary.withValues(alpha: hasCost ? .30 : .16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.savings_outlined, color: scheme.tertiary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Could stay with you',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                hasCost ? _formatMoney(estimatedCost) : 'Set cost',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasCost
                ? 'This is an estimate, not a verdict. It turns the pattern into one more choice you can see.'
                : 'Add a unit cost if money is part of this pattern. The app will keep it local.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.attach_money_rounded, size: 17),
                label: Text(
                  hasCost
                      ? '${_formatMoney(habit.costPerUnit!)} per ${habit.unit}'
                      : 'No unit cost yet',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                label: Text(
                  '${entries.length} log${entries.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChart extends StatelessWidget {
  const _DetailChart({required this.entries});

  final List<UsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [
      for (var i = 13; i >= 0; i--) DateTime.now().subtract(Duration(days: i)),
    ];
    final totals = [
      for (final day in days)
        entries
            .where(
              (entry) =>
                  entry.loggedAt.year == day.year &&
                  entry.loggedAt.month == day.month &&
                  entry.loggedAt.day == day.day,
            )
            .fold<double>(0, (total, entry) => total + entry.quantity),
    ];
    final maxY = totals.fold<double>(1, (a, b) => a > b ? a : b);
    return CalmCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.secondaryContainer.withValues(alpha: .20),
          theme.colorScheme.surfaceContainerLow.withValues(alpha: .96),
        ],
      ),
      borderColor: theme.colorScheme.secondary.withValues(alpha: .14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Last 14 days'),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .34,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: [
                  for (var index = 0; index < totals.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: totals[index],
                          width: 12,
                          borderRadius: BorderRadius.circular(5),
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entries.isEmpty
                ? 'This will fill in as you log.'
                : 'Daily totals help show timing without judging the day.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.profile});

  final RiskProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      color: theme.colorScheme.errorContainer.withValues(alpha: .22),
      glowColor: theme.colorScheme.error,
      glowIntensity: .08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(profile.title, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(profile.riskSummary),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(profile.cooldown)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final step in profile.immediateSteps)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({
    required this.habit,
    required this.entries,
    required this.profile,
  });

  final Habit habit;
  final List<UsageEntry> entries;
  final RiskProfile profile;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Help and search',
            trailing: IconButton(
              tooltip: 'Search web',
              onPressed: () =>
                  GuidanceService.openSearch(habit: habit, entries: entries),
              icon: const Icon(Icons.travel_explore_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search uses your visible pattern context, such as habit, timing, and triggers. It opens outside the app.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final resource in profile.resources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(resource.title),
              subtitle: Text(resource.source),
              onTap: () => GuidanceService.openUri(resource.url),
            ),
        ],
      ),
    );
  }
}

class _RecentLogs extends StatelessWidget {
  const _RecentLogs({required this.habit, required this.entries});

  final Habit habit;
  final List<UsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recent logs'),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'No logs yet for this tracker.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final entry in entries.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${entry.quantity.toStringAsFixed(entry.quantity == entry.quantity.roundToDouble() ? 0 : 1)} ${habit.unit}',
                ),
                subtitle: Text(
                  [
                    DateFormat('MMM d, h:mm a').format(entry.loggedAt),
                    if (entry.trigger != null) entry.trigger!,
                    if (entry.mood != null) moodLabel(entry.mood),
                    if (entry.estimatedCostFor(habit) != null)
                      _formatMoney(entry.estimatedCostFor(habit)!),
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () =>
                    showEntryEditorSheet(context, entry: entry, habit: habit),
              ),
        ],
      ),
    );
  }
}

String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';
