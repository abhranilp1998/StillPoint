import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/habit_library.dart';
import '../../core/models.dart';
import '../../state/app_controller.dart';
import '../habit/habit_detail_screen.dart';
import '../logging/quick_log_sheet.dart';
import 'starter_tracker_sheet.dart';
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
    final allHabits = state?.habits ?? const <Habit>[];
    final habits = allHabits
        .where((habit) => HabitLibrary.matchesHabit(habit, _query))
        .toList(growable: false);
    habits.sort((a, b) {
      if (a.archived != b.archived) return a.archived ? 1 : -1;
      return a.name.compareTo(b.name);
    });
    final activeHabits = habits
        .where((habit) => !habit.archived)
        .toList(growable: false);
    final archivedHabits = habits
        .where((habit) => habit.archived)
        .toList(growable: false);
    final hasSearch = _query.isNotEmpty;
    final needsStarterFlow =
        state != null &&
        state.activeHabits.isEmpty &&
        state.archivedHabits.isNotEmpty;

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
                  else if (hasSearch && habits.isEmpty)
                    EmptyStateCard(
                      icon: Icons.search_off_rounded,
                      title: 'No trackers match',
                      body:
                          'Try another name, category, or friendly term like weed, cigs, coffee, vape, or betting.',
                      action: FilledButton.icon(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Clear search'),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (needsStarterFlow && !hasSearch) ...[
                          EmptyStateCard(
                            icon: Icons.tune_rounded,
                            title: 'Start with a smaller set',
                            body:
                                'Pick 3 trackers to begin. The rest stay hidden until you want them.',
                            action: FilledButton.icon(
                              onPressed: () => showStarterTrackerSheet(context),
                              icon: const Icon(Icons.checklist_rounded),
                              label: const Text('Pick 3 to start'),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        _TrackerSection(
                          title: 'Active now',
                          subtitle: activeHabits.isEmpty
                              ? 'Nothing visible yet. Bring back a few presets or add a custom tracker.'
                              : 'These show up in quick log, Patterns, and Home.',
                          emptyTitle: 'No active trackers',
                          emptyBody:
                              'Show a hidden tracker or add a custom one when something becomes useful to notice.',
                          habits: activeHabits,
                          entries: state.entries,
                          onTapHabit: _openHabit,
                          trailingBuilder: (habit) => IconButton(
                            tooltip: 'Hide tracker',
                            onPressed: () =>
                                _setArchived(habit, archived: true),
                            icon: const Icon(Icons.visibility_off_outlined),
                          ),
                          footer: AddTrackerTile(
                            onTap: () => showAddHabitSheet(context),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _TrackerSection(
                          title: 'Hidden for later',
                          subtitle:
                              'Presets stay local with their history intact. Bring them back anytime.',
                          emptyTitle: 'Nothing hidden',
                          emptyBody:
                              'Every tracker is already visible right now.',
                          habits: archivedHabits,
                          entries: state.entries,
                          onTapHabit: _openHabit,
                          trailingBuilder: (habit) => IconButton(
                            tooltip: 'Show tracker',
                            onPressed: () =>
                                _setArchived(habit, archived: false),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                          headerAction: archivedHabits.isEmpty || hasSearch
                              ? null
                              : TextButton.icon(
                                  onPressed: () =>
                                      showStarterTrackerSheet(context),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Show some'),
                                ),
                        ),
                      ],
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

  void _openHabit(Habit habit) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HabitDetailScreen(habitId: habit.id),
      ),
    );
  }

  Future<void> _setArchived(Habit habit, {required bool archived}) async {
    await ref
        .read(appControllerProvider.notifier)
        .setHabitArchived(habit, archived: archived);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          archived
              ? '${habit.name} hidden from the active tracker set.'
              : '${habit.name} is visible again.',
        ),
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

class _TrackerSection extends StatelessWidget {
  const _TrackerSection({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyBody,
    required this.habits,
    required this.entries,
    required this.onTapHabit,
    required this.trailingBuilder,
    this.headerAction,
    this.footer,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyBody;
  final List<Habit> habits;
  final List<UsageEntry> entries;
  final ValueChanged<Habit> onTapHabit;
  final Widget Function(Habit habit) trailingBuilder;
  final Widget? headerAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (headerAction != null) ...[headerAction!],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        if (habits.isEmpty)
          EmptyStateCard(
            icon: Icons.grid_view_rounded,
            title: emptyTitle,
            body: emptyBody,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = switch (constraints.maxWidth) {
                > 900 => 4,
                > 620 => 3,
                _ => 2,
              };
              final itemCount = habits.length + (footer == null ? 0 : 1);
              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 116,
                ),
                itemBuilder: (context, index) {
                  if (footer != null && index == itemCount - 1) {
                    return footer!;
                  }
                  final habit = habits[index];
                  return TrackerTile(
                    habit: habit,
                    subtitle: habit.archived ? 'Hidden for now' : null,
                    lastEntry: latestEntryForHabit(habit, entries),
                    trailing: trailingBuilder(habit),
                    onTap: () => onTapHabit(habit),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
