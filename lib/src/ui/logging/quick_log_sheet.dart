import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/quantity_math.dart';
import '../../state/app_controller.dart';
import '../widgets/habit_visuals.dart';

Future<void> showQuickLogSheet(BuildContext context, {Habit? initialHabit}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) =>
        QuickLogSheet(initialHabit: initialHabit, launcherContext: context),
  );
}

Future<void> showAddHabitSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => const AddHabitSheet(),
  );
}

class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key, this.initialHabit, this.launcherContext});

  final Habit? initialHabit;
  final BuildContext? launcherContext;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  Habit? _habit;
  double _quantity = 1;
  int? _mood;
  int? _craving;
  int? _stress;
  String? _trigger;
  bool _showContext = false;
  bool _saving = false;

  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _habit = widget.initialHabit;
    _quantity = defaultQuantityFor(widget.initialHabit);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final habits = state?.activeHabits ?? const <Habit>[];
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _habit == null
              ? _HabitPicker(
                  habits: habits,
                  onHabitSelected: (habit) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _habit = habit;
                      _quantity = defaultQuantityFor(habit);
                    });
                  },
                  onAddCustom: () {
                    final launcherContext = widget.launcherContext;
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (launcherContext?.mounted ?? false) {
                        showAddHabitSheet(launcherContext!);
                      }
                    });
                  },
                )
              : Column(
                  key: const ValueKey('logger'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Choose habit',
                          onPressed: () => setState(() => _habit = null),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _habit!.name,
                            style: theme.textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _QuantityPicker(
                      habit: _habit!,
                      quantity: _quantity,
                      onChanged: (value) => setState(() => _quantity = value),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showContext = !_showContext),
                      icon: Icon(
                        _showContext
                            ? Icons.expand_less_rounded
                            : Icons.add_circle_outline_rounded,
                      ),
                      label: Text(
                        _showContext ? 'Less context' : 'Add context',
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _ContextFields(
                        mood: _mood,
                        craving: _craving,
                        stress: _stress,
                        trigger: _trigger,
                        noteController: _noteController,
                        onMood: (value) => setState(() => _mood = value),
                        onCraving: (value) => setState(() => _craving = value),
                        onStress: (value) => setState(() => _stress = value),
                        onTrigger: (value) => setState(() => _trigger = value),
                      ),
                      crossFadeState: _showContext
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 180),
                      sizeCurve: Curves.easeOutCubic,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Save log'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_habit == null) return;
    setState(() => _saving = true);
    await ref
        .read(appControllerProvider.notifier)
        .logEntry(
          habit: _habit!,
          quantity: _quantity,
          mood: _mood,
          craving: _craving,
          stress: _stress,
          trigger: _trigger,
          note: _noteController.text,
        );
    HapticFeedback.lightImpact();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged. Your pattern stays visible.')),
      );
    }
  }
}

class _HabitPicker extends StatelessWidget {
  const _HabitPicker({
    required this.habits,
    required this.onHabitSelected,
    required this.onAddCustom,
  });

  final List<Habit> habits;
  final ValueChanged<Habit> onHabitSelected;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('habitPicker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick log', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Choose what you want to record. All local, no judgment.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: habits.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 74,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return AddTrackerTile(onTap: onAddCustom);
            }
            final habit = habits[index - 1];
            return HabitPill(
              habit: habit,
              onTap: () => onHabitSelected(habit),
              compact: true,
            );
          },
        ),
      ],
    );
  }
}

class _QuantityPicker extends StatelessWidget {
  const _QuantityPicker({
    required this.habit,
    required this.quantity,
    required this.onChanged,
  });

  final Habit habit;
  final double quantity;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = quantityPresetsFor(habit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in presets)
              ChoiceChip(
                selected: sameQuantity(quantity, value),
                label: Text(formatQuantity(value)),
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Decrease',
              onPressed: canDecreaseQuantity(habit, quantity)
                  ? () => onChanged(decreaseQuantity(habit, quantity))
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${formatQuantity(quantity)} ${habit.unit}',
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Increase',
              onPressed: () => onChanged(increaseQuantity(habit, quantity)),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContextFields extends StatelessWidget {
  const _ContextFields({
    required this.mood,
    required this.craving,
    required this.stress,
    required this.trigger,
    required this.noteController,
    required this.onMood,
    required this.onCraving,
    required this.onStress,
    required this.onTrigger,
  });

  final int? mood;
  final int? craving;
  final int? stress;
  final String? trigger;
  final TextEditingController noteController;
  final ValueChanged<int?> onMood;
  final ValueChanged<int?> onCraving;
  final ValueChanged<int?> onStress;
  final ValueChanged<String?> onTrigger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScaleChips(
          title: 'Mood',
          value: mood,
          labels: const ['Heavy', 'Low', 'Steady', 'Clear', 'Light'],
          onChanged: onMood,
        ),
        const SizedBox(height: 12),
        _ScaleChips(
          title: 'Craving',
          value: craving,
          labels: const ['Quiet', 'Mild', 'Moderate', 'Strong', 'Intense'],
          onChanged: onCraving,
        ),
        const SizedBox(height: 12),
        _ScaleChips(
          title: 'Stress',
          value: stress,
          labels: const ['Quiet', 'Mild', 'Moderate', 'Strong', 'Intense'],
          onChanged: onStress,
        ),
        const SizedBox(height: 12),
        _TriggerChips(trigger: trigger, onChanged: onTrigger),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'Optional context',
          ),
        ),
      ],
    );
  }
}

class _ScaleChips extends StatelessWidget {
  const _ScaleChips({
    required this.title,
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final String title;
  final int? value;
  final List<String> labels;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < labels.length; i++)
              ChoiceChip(
                label: Text(labels[i]),
                selected: value == i + 1,
                onSelected: (_) => onChanged(value == i + 1 ? null : i + 1),
              ),
          ],
        ),
      ],
    );
  }
}

class _TriggerChips extends StatelessWidget {
  const _TriggerChips({required this.trigger, required this.onChanged});

  final String? trigger;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const triggers = [
      'Stress',
      'Social',
      'Sleep',
      'Boredom',
      'Work',
      'Evening',
      'Pain',
      'Celebration',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Context', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in triggers)
              ChoiceChip(
                label: Text(item),
                selected: trigger == item,
                onSelected: (_) => onChanged(trigger == item ? null : item),
              ),
          ],
        ),
      ],
    );
  }
}

class AddHabitSheet extends ConsumerStatefulWidget {
  const AddHabitSheet({super.key});

  @override
  ConsumerState<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<AddHabitSheet> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController(text: 'units');
  final _costController = TextEditingController();
  HabitCategory _category = HabitCategory.custom;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom tracker',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Name the pattern in your own words. You can change it later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HabitCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final category in HabitCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _unitController.text = value.defaultUnit;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cost per unit',
                prefixText: '\$',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Add tracker'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(appControllerProvider.notifier)
        .addCustomHabit(
          name: name,
          category: _category,
          unit: _unitController.text,
          costPerUnit: double.tryParse(_costController.text.trim()),
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker added. It is yours to shape.')),
      );
    }
  }
}
