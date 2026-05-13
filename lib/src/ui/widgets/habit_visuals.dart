import 'package:flutter/material.dart';

import '../../core/models.dart';

IconData habitIcon(HabitCategory category) {
  return switch (category) {
    HabitCategory.cigarettes => Icons.smoking_rooms_outlined,
    HabitCategory.vaping => Icons.air_outlined,
    HabitCategory.alcohol => Icons.local_bar_outlined,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: theme.brightness == Brightness.dark ? .20 : .12,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .24)),
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
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
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
