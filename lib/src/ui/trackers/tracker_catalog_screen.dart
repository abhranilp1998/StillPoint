import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/habit_library.dart';
import '../../core/models.dart';
import '../../state/app_controller.dart';
import '../habit/habit_detail_screen.dart';
import '../logging/quick_log_sheet.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

class TrackerCatalogScreen extends ConsumerStatefulWidget {
  const TrackerCatalogScreen({super.key});

  @override
  ConsumerState<TrackerCatalogScreen> createState() =>
      _TrackerCatalogScreenState();
}

class _TrackerCatalogScreenState extends ConsumerState<TrackerCatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final allHabits = state?.activeHabits ?? const <Habit>[];
    final habits = allHabits
        .where((habit) => HabitLibrary.matchesHabit(habit, _query))
        .toList(growable: false);
    final hasSearch = _query.isNotEmpty;

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
                  _TrackerSearchCard(
                    controller: _searchController,
                    hasSearch: hasSearch,
                    onClear: () => _searchController.clear(),
                  ),
                  const SizedBox(height: 14),
                  if (state == null)
                    const EmptyStateCard(
                      icon: Icons.hourglass_empty_rounded,
                      title: 'Loading trackers',
                      body: 'Your local tracker list is opening.',
                    )
                  else if (habits.isEmpty)
                    EmptyStateCard(
                      icon: hasSearch
                          ? Icons.search_off_rounded
                          : Icons.add_circle_outline_rounded,
                      title: hasSearch
                          ? 'No trackers match'
                          : 'Add your first tracker',
                      body: hasSearch
                          ? 'Try another name, category, or friendly term like weed, cigs, coffee, vape, or betting.'
                          : 'Pick a starting point or create one that matches your real pattern.',
                      action: FilledButton.icon(
                        onPressed: hasSearch
                            ? () => _searchController.clear()
                            : () => showAddHabitSheet(context),
                        icon: Icon(
                          hasSearch ? Icons.close_rounded : Icons.add_rounded,
                        ),
                        label: Text(hasSearch ? 'Clear search' : 'Add tracker'),
                      ),
                    )
                  else
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 116,
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
                              lastEntry: latestEntryForHabit(
                                habit,
                                state.entries,
                              ),
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

class _TrackerSearchCard extends StatelessWidget {
  const _TrackerSearchCard({
    required this.controller,
    required this.hasSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: hasSearch
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          hintText: 'Search trackers',
          helperText: 'Try weed, cigs, coffee, vape, betting',
        ),
      ),
    );
  }
}
