import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import 'adaptive_scaffold.dart';

IconData habitIcon(HabitCategory category) {
  return switch (category) {
    HabitCategory.cigarettes => Icons.smoking_rooms_outlined,
    HabitCategory.vaping => Icons.air_outlined,
    HabitCategory.alcohol => Icons.local_bar_outlined,
    HabitCategory.cannabis => Icons.grass_outlined,
    HabitCategory.opioids => Icons.medication_liquid_outlined,
    HabitCategory.cocaine => Icons.bolt_rounded,
    HabitCategory.methamphetamine => Icons.offline_bolt_outlined,
    HabitCategory.benzodiazepines => Icons.nightlight_round,
    HabitCategory.sedatives => Icons.bedtime_outlined,
    HabitCategory.hallucinogens => Icons.blur_on_rounded,
    HabitCategory.inhalants => Icons.air_rounded,
    HabitCategory.syntheticCannabinoids => Icons.biotech_outlined,
    HabitCategory.coughMedicine => Icons.medical_services_outlined,
    HabitCategory.kratom => Icons.eco_outlined,
    HabitCategory.otherDrugs => Icons.science_outlined,
    HabitCategory.drugs => Icons.science_outlined,
    HabitCategory.pills => Icons.medication_outlined,
    HabitCategory.recreationalSubstances => Icons.spa_outlined,
    HabitCategory.caffeine => Icons.coffee_outlined,
    HabitCategory.gambling => Icons.casino_outlined,
    HabitCategory.doomscrolling => Icons.phone_android_outlined,
    HabitCategory.pornography => Icons.visibility_off_outlined,
    HabitCategory.prescriptionMisuse => Icons.medication_liquid_outlined,
    HabitCategory.custom => Icons.tune_outlined,
  };
}

class HabitPill extends StatelessWidget {
  const HabitPill({
    super.key,
    required this.habit,
    required this.onTap,
    this.compact = false,
  });

  final Habit habit;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(habit.colorValue);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 52 : 68),
      child: CalmCard(
        onTap: onTap,
        semanticLabel: 'Log ${habit.name}',
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? .20 : .10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              habitIcon(habit.category),
              color: color,
              size: compact ? 20 : 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                habit.name,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? theme.textTheme.labelLarge
                    : theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackerTile extends StatelessWidget {
  const TrackerTile({
    super.key,
    required this.habit,
    required this.onTap,
    this.subtitle,
    this.lastEntry,
    this.trailing,
  });

  final Habit habit;
  final VoidCallback onTap;
  final String? subtitle;
  final UsageEntry? lastEntry;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(habit.colorValue);
    final logged = lastEntry;
    return CalmCard(
      onTap: onTap,
      semanticLabel: 'Open ${habit.name}',
      padding: const EdgeInsets.all(14),
      color: color.withValues(
        alpha: theme.brightness == Brightness.dark ? .18 : .08,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    habitIcon(habit.category),
                    color: color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
          const Spacer(),
          Text(
            logged == null
                ? (subtitle ?? habit.reductionMode.label)
                : _formatQuantity(logged.quantity, habit.unit),
            style: theme.textTheme.labelLarge?.copyWith(
              color: logged == null ? theme.colorScheme.onSurface : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                logged == null
                    ? Icons.radio_button_unchecked_rounded
                    : Icons.schedule_rounded,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  logged == null
                      ? 'No logs yet'
                      : 'Last ${_formatLastLogged(logged.loggedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double value, String unit) {
    final quantity = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$quantity $unit';
  }

  String _formatLastLogged(DateTime loggedAt) {
    final now = DateTime.now();
    final diff = now.difference(loggedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 24 && loggedAt.day == now.day) {
      return DateFormat('h:mm a').format(loggedAt);
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (loggedAt.year == yesterday.year &&
        loggedAt.month == yesterday.month &&
        loggedAt.day == yesterday.day) {
      return 'yesterday';
    }
    if (diff.inDays < 7) return DateFormat.E().format(loggedAt);
    return DateFormat.MMMd().format(loggedAt);
  }
}

UsageEntry? latestEntryForHabit(Habit habit, List<UsageEntry> entries) {
  UsageEntry? latest;
  for (final entry in entries) {
    if (entry.habitId != habit.id) continue;
    if (latest == null || entry.loggedAt.isAfter(latest.loggedAt)) {
      latest = entry;
    }
  }
  return latest;
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: .34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class AddTrackerTile extends StatelessWidget {
  const AddTrackerTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      onTap: onTap,
      semanticLabel: 'Add custom tracker',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: .38),
      child: Row(
        children: [
          Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Custom tracker', style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Create what you need',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 12),
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
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
