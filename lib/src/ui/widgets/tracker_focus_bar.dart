import 'package:flutter/material.dart';

import '../../core/models.dart';

class TrackerFocusBar extends StatelessWidget {
  const TrackerFocusBar({
    super.key,
    required this.habits,
    required this.selectedHabitId,
    required this.onSelected,
    this.allLabel = 'All trackers',
  });

  final List<Habit> habits;
  final String? selectedHabitId;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(allLabel),
            selected: selectedHabitId == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final habit in habits) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(habit.name),
              selected: selectedHabitId == habit.id,
              onSelected: (_) =>
                  onSelected(selectedHabitId == habit.id ? null : habit.id),
            ),
          ],
        ],
      ),
    );
  }
}
