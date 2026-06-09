import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../state/app_controller.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

Future<void> showStarterTrackerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const StarterTrackerSheet(),
  );
}

class StarterTrackerSheet extends ConsumerStatefulWidget {
  const StarterTrackerSheet({super.key});

  @override
  ConsumerState<StarterTrackerSheet> createState() =>
      _StarterTrackerSheetState();
}

class _StarterTrackerSheetState extends ConsumerState<StarterTrackerSheet> {
  final Set<String> _selectedIds = <String>{};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final availableHabits = state?.archivedHabits ?? const <Habit>[];
    final firstRun = (state?.activeHabits.length ?? 0) == 0;
    final requiredCount = firstRun ? 3 : 1;
    final canSave = !_saving && _selectedIds.length >= requiredCount;
    final title = firstRun ? 'Pick 3 to start' : 'Show more trackers';
    final subtitle = firstRun
        ? 'Start small. You can bring back hidden presets anytime.'
        : 'Turn hidden presets back on whenever they would help.';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SoftMessage(
              icon: Icons.lock_outline_rounded,
              title: 'All presets stay local',
              body: firstRun
                  ? 'Choose the few trackers that feel useful right now. The rest stay hidden for later.'
                  : 'Hidden trackers keep their history. Showing them again does not lose data.',
            ),
            const SizedBox(height: 14),
            if (state == null)
              const EmptyStateCard(
                icon: Icons.hourglass_empty_rounded,
                title: 'Loading trackers',
                body: 'Your local tracker presets are opening.',
              )
            else if (availableHabits.isEmpty)
              const EmptyStateCard(
                icon: Icons.visibility_outlined,
                title: 'Nothing hidden right now',
                body:
                    'Every tracker is already visible. You can still add a custom one anytime.',
              )
            else ...[
              Text(
                firstRun
                    ? 'Choose exactly 3'
                    : 'Choose tracker${availableHabits.length == 1 ? '' : 's'} to show',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableHabits.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 84,
                ),
                itemBuilder: (context, index) {
                  final habit = availableHabits[index];
                  final selected = _selectedIds.contains(habit.id);
                  final limitReached =
                      firstRun && _selectedIds.length >= 3 && !selected;
                  return _StarterTrackerOption(
                    habit: habit,
                    selected: selected,
                    disabled: limitReached,
                    onTap: () => _toggle(habit.id, firstRun: firstRun),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canSave ? () => _save(availableHabits) : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    firstRun
                        ? 'Start with ${_selectedIds.length}/3'
                        : 'Show ${_selectedIds.length} tracker${_selectedIds.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggle(String habitId, {required bool firstRun}) {
    setState(() {
      if (_selectedIds.contains(habitId)) {
        _selectedIds.remove(habitId);
        return;
      }
      if (firstRun && _selectedIds.length >= 3) return;
      _selectedIds.add(habitId);
    });
  }

  Future<void> _save(List<Habit> availableHabits) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(appControllerProvider.notifier).activateHabits(_selectedIds);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final activatedNames = availableHabits
        .where((habit) => _selectedIds.contains(habit.id))
        .map((habit) => habit.name)
        .take(3)
        .join(', ');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          activatedNames.isEmpty
              ? 'Trackers updated.'
              : 'Now showing $activatedNames.',
        ),
      ),
    );
  }
}

class _StarterTrackerOption extends StatelessWidget {
  const _StarterTrackerOption({
    required this.habit,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Habit habit;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(habit.colorValue);
    return Opacity(
      opacity: disabled ? .45 : 1,
      child: CalmCard(
        onTap: disabled ? null : onTap,
        semanticLabel: 'Choose ${habit.name}',
        padding: const EdgeInsets.all(12),
        color: selected
            ? color.withValues(
                alpha: theme.brightness == Brightness.dark ? .24 : .16,
              )
            : color.withValues(
                alpha: theme.brightness == Brightness.dark ? .14 : .08,
              ),
        borderColor: selected
            ? color.withValues(alpha: .42)
            : color.withValues(alpha: .18),
        child: Row(
          children: [
            Icon(habitIcon(habit.category), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                habit.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
