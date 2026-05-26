import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../state/app_controller.dart';
import '../habit/habit_detail_screen.dart';
import '../logging/quick_log_sheet.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

class TrackerCatalogScreen extends ConsumerWidget {
  const TrackerCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final habits = state?.activeHabits ?? const <Habit>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Trackers'),
            actions: [
              IconButton(
                tooltip: 'Add custom tracker',
                onPressed: () => showAddHabitSheet(context),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: ScreenPadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SoftMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Choose what fits',
                    body:
                        'These are starting points. Add a custom tracker whenever your real pattern needs its own name.',
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = switch (constraints.maxWidth) {
                        > 900 => 4,
                        > 620 => 3,
                        _ => 2,
                      };
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: habits.length + 1,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 90,
                        ),
                        itemBuilder: (context, index) {
                          if (index == habits.length) {
                            return AddTrackerTile(
                              onTap: () => showAddHabitSheet(context),
                            );
                          }
                          final habit = habits[index];
                          return TrackerTile(
                            habit: habit,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    HabitDetailScreen(habitId: habit.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
