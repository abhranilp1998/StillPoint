import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/habit_library.dart';
import '../../core/models.dart';
import '../../core/quantity_math.dart';
import '../../services/notification_service.dart';
import '../../services/sanctuary_attention_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../habit/entry_editor_sheet.dart';
import '../support/support_screen.dart';
import '../widgets/habit_visuals.dart';
import '../widgets/money_currency_prompt.dart';

Future<void> showQuickLogSheet(BuildContext context, {Habit? initialHabit}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: AppTheme.sheetRadius,
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
      borderRadius: AppTheme.sheetRadius,
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
  bool _quantityTouched = false;
  String? _seededHabitId;

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
    final entries = state?.entries ?? const <UsageEntry>[];
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    _seedQuantityFromHistory(entries);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            if (MediaQuery.disableAnimationsOf(context)) {
              return FadeTransition(opacity: animation, child: child);
            }
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _habit == null
              ? _HabitPicker(
                  habits: habits,
                  onHabitSelected: (habit) {
                    HapticFeedback.selectionClick();
                    _selectHabit(habit, entries);
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
                      recentQuantity: _recentQuantityFor(_habit!, entries),
                      onChanged: (value) => setState(() {
                        _quantity = value;
                        _quantityTouched = true;
                      }),
                      onSetUnitCost: _setUnitCost,
                    ),
                    const SizedBox(height: 12),
                    _LoggingHint(habit: _habit!),
                    const SizedBox(height: 8),
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
                        habit: _habit!,
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: _saving
                              ? const SizedBox.square(
                                  key: ValueKey('saving'),
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_rounded,
                                  key: ValueKey('ready'),
                                ),
                        ),
                        label: const Text('Save log'),
                      ),
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
    final entry = await ref
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
      final habit = _habit!;
      final launcherContext = widget.launcherContext;
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final snackContext = launcherContext?.mounted ?? false
            ? launcherContext!
            : null;
        if (snackContext == null) return;
        _showPostLogSnackBar(snackContext, entry, habit);
      });
    }
  }

  void _selectHabit(Habit habit, List<UsageEntry> entries) {
    setState(() {
      _habit = habit;
      _quantity =
          _recentQuantityFor(habit, entries) ?? defaultQuantityFor(habit);
      _quantityTouched = false;
      _seededHabitId = habit.id;
    });
  }

  void _seedQuantityFromHistory(List<UsageEntry> entries) {
    final habit = _habit;
    if (habit == null ||
        _quantityTouched ||
        _seededHabitId == habit.id ||
        entries.isEmpty) {
      return;
    }

    final quantity = _recentQuantityFor(habit, entries);
    if (quantity == null) {
      _seededHabitId = habit.id;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _habit?.id != habit.id || _quantityTouched) return;
      setState(() {
        _quantity = quantity;
        _seededHabitId = habit.id;
      });
    });
  }

  double? _recentQuantityFor(Habit habit, List<UsageEntry> entries) {
    return latestEntryForHabit(habit, entries)?.quantity;
  }

  Future<void> _setUnitCost() async {
    final habit = _habit;
    if (habit == null) return;
    final state = ref
        .read(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    if (state != null && !state.settings.moneyCurrencySetupCompleted) {
      await showMoneyCurrencyPrompt(context, ref);
      if (!mounted) return;
    }
    final cost = await _askForUnitCost(context, habit);
    if (cost == null) return;
    final nextHabit = cost <= 0
        ? habit.copyWith(clearCostPerUnit: true)
        : habit.copyWith(costPerUnit: cost);
    await ref.read(appControllerProvider.notifier).updateHabit(nextHabit);
    if (!mounted) return;
    setState(() => _habit = nextHabit);
  }
}

class _QuantityPreset {
  const _QuantityPreset(this.label, this.value);

  final String label;
  final double value;
}

List<_QuantityPreset> _loggingPresetsFor(Habit habit, double? recentQuantity) {
  final base = quantityPresetsFor(habit);
  final usual = base[((base.length - 1) / 2).floor()];
  final items = [
    _QuantityPreset('Small', base.first),
    if (recentQuantity != null) _QuantityPreset('Last used', recentQuantity),
    _QuantityPreset('Usual', usual),
    _QuantityPreset('Heavy', base.last),
  ];
  final seen = <double>{};
  return [
    for (final item in items)
      if (seen.add(normalizeQuantity(item.value))) item,
  ];
}

Future<double?> _askForCustomQuantity(
  BuildContext context,
  Habit habit,
  double current,
) async {
  final controller = TextEditingController(text: formatQuantity(current));
  String? error;
  final result = await showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Custom quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: habit.unit, errorText: error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                setDialogState(() => error = 'Use a number 0 or higher.');
                return;
              }
              Navigator.pop(context, normalizeQuantity(value));
            },
            child: const Text('Use'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}

Future<double?> _askForUnitCost(BuildContext context, Habit habit) async {
  final controller = TextEditingController(
    text: habit.costPerUnit == null ? '' : habit.costPerUnit!.toString(),
  );
  final suggestedCost = HabitLibrary.defaultUnitCostFor(habit.category);
  String? error;
  final result = await showDialog<double?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
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
                prefixText: AppSettings.defaultMoneyCurrencySymbol,
                hintText: suggestedCost == null
                    ? 'Leave blank to remove'
                    : 'Try ${suggestedCost.toStringAsFixed(2)} if useful',
                errorText: error,
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
                  'Use starter estimate ${formatMoney(suggestedCost)}',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                Navigator.pop(context, 0);
                return;
              }
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                setDialogState(() => error = 'Use a number 0 or higher.');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}

class _LogCostPreview extends StatelessWidget {
  const _LogCostPreview({
    required this.habit,
    required this.cost,
    required this.onSetUnitCost,
  });

  final Habit habit;
  final double? cost;
  final VoidCallback onSetUnitCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCost = cost != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.tertiaryContainer.withValues(alpha: hasCost ? .48 : .22),
            scheme.surfaceContainerHighest.withValues(alpha: .54),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasCost
              ? scheme.tertiary.withValues(alpha: .28)
              : scheme.outlineVariant.withValues(alpha: .55),
        ),
        boxShadow: [
          if (hasCost)
            BoxShadow(
              color: scheme.tertiary.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(Icons.savings_outlined, color: scheme.tertiary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cost == null
                    ? 'Add a unit cost if money is part of the pattern.'
                    : 'This log adds about ${formatMoney(cost!)}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: hasCost ? FontWeight.w700 : null,
                ),
              ),
            ),
            TextButton(
              onPressed: onSetUnitCost,
              child: Text(cost == null ? 'Set cost' : 'Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggingHint extends StatelessWidget {
  const _LoggingHint({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                HabitLibrary.loggingHintFor(habit.category),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPostLogSnackBar(BuildContext context, UsageEntry entry, Habit habit) {
  final cost = entry.estimatedCostFor(habit);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 12),
      content: _PostLogSnackContent(entry: entry, habit: habit, cost: cost),
      action: SnackBarAction(
        label: 'Edit',
        onPressed: () =>
            showEntryEditorSheet(context, entry: entry, habit: habit),
      ),
    ),
  );
}

class _PostLogSnackContent extends ConsumerWidget {
  const _PostLogSnackContent({
    required this.entry,
    required this.habit,
    required this.cost,
  });

  final UsageEntry entry;
  final Habit habit;
  final double? cost;

  bool get _needsSupport => SanctuaryAttentionService.isHighNeedEntry(entry);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggers = HabitLibrary.contextChipsFor(habit.category).take(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cost == null
              ? 'Logged ${habit.name}.'
              : 'Logged ${habit.name} · ${formatMoney(cost!)}.',
        ),
        if (_needsSupport) ...[
          const SizedBox(height: 8),
          const Text(
            'That looked like a rougher moment. Want one gentle next step?',
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.spa_rounded, size: 16),
                label: const Text('Open Sanctuary'),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SanctuaryScreen(),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.timer_outlined, size: 16),
                label: const Text('Start 2 min pause'),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const SanctuaryScreen(initialPauseSeconds: 120),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.notifications_none_rounded, size: 16),
                label: const Text('Remind me in 15 min'),
                onPressed: () => _scheduleFollowUpReminder(context, ref),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Text('What triggered this?'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final trigger in triggers)
              ActionChip(
                label: Text(trigger),
                onPressed: () async {
                  await ref
                      .read(appControllerProvider.notifier)
                      .updateEntry(entry.copyWith(trigger: trigger));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added "$trigger" context.')),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _scheduleFollowUpReminder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref
        .read(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    if (state == null) return;

    final notifications = ref.read(notificationServiceProvider);
    final granted = await notifications.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification permission is needed for follow-up reminders.',
          ),
        ),
      );
      return;
    }

    final delivery = await notifications.scheduleFollowUpReminder(
      settings: state.settings,
      delay: const Duration(minutes: 15),
      trackerName: habit.name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivery == null
              ? 'Could not schedule that reminder right now.'
              : 'Reminder set for ${DateFormat('h:mm a').format(delivery)}.',
        ),
      ),
    );
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
    required this.recentQuantity,
    required this.onChanged,
    required this.onSetUnitCost,
  });

  final Habit habit;
  final double quantity;
  final double? recentQuantity;
  final ValueChanged<double> onChanged;
  final VoidCallback onSetUnitCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = _loggingPresetsFor(habit, recentQuantity);
    final matchedPreset = presets.any(
      (preset) => sameQuantity(quantity, preset.value),
    );
    final cost = habit.costPerUnit == null || habit.costPerUnit! <= 0
        ? null
        : quantity * habit.costPerUnit!;
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: .46),
            scheme.primaryContainer.withValues(alpha: .18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .44)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in presets)
                  ChoiceChip(
                    selected: sameQuantity(quantity, preset.value),
                    label: Text(
                      '${preset.label} ${formatQuantity(preset.value)}',
                    ),
                    onSelected: (_) => onChanged(preset.value),
                  ),
                ChoiceChip(
                  selected: !matchedPreset,
                  avatar: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Custom'),
                  onSelected: (_) async {
                    final value = await _askForCustomQuantity(
                      context,
                      habit,
                      quantity,
                    );
                    if (value != null) onChanged(value);
                  },
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        '${formatQuantity(quantity)} ${habit.unit}',
                        key: ValueKey(quantity),
                        style: theme.textTheme.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            const SizedBox(height: 12),
            _LogCostPreview(
              habit: habit,
              cost: cost,
              onSetUnitCost: onSetUnitCost,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextFields extends StatelessWidget {
  const _ContextFields({
    required this.mood,
    required this.craving,
    required this.stress,
    required this.trigger,
    required this.habit,
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
  final Habit habit;
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
        _TriggerChips(habit: habit, trigger: trigger, onChanged: onTrigger),
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
  const _TriggerChips({
    required this.habit,
    required this.trigger,
    required this.onChanged,
  });

  final Habit habit;
  final String? trigger;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Context', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in HabitLibrary.contextChipsFor(habit.category))
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
  bool _currencyPromptQueued = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    _scheduleCurrencyPrompt(state);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final suggestedCost = HabitLibrary.defaultUnitCostFor(_category);
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
                  _unitController.text = HabitLibrary.profileFor(
                    value,
                  ).defaultUnit;
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
                prefixText: AppSettings.defaultMoneyCurrencySymbol,
                hintText: 'Optional',
              ),
            ),
            if (suggestedCost != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    _costController.text = suggestedCost.toStringAsFixed(2);
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    'Use starter estimate ${formatMoney(suggestedCost)}',
                  ),
                ),
              ),
            ],
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

  void _scheduleCurrencyPrompt(AppState? state) {
    if (state == null ||
        state.settings.moneyCurrencySetupCompleted ||
        _currencyPromptQueued) {
      return;
    }

    _currencyPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final latest = ref
          .read(appControllerProvider)
          .maybeWhen(data: (state) => state, orElse: () => null);
      if (latest != null && !latest.settings.moneyCurrencySetupCompleted) {
        await showMoneyCurrencyPrompt(context, ref);
      }
      if (mounted) setState(() => _currencyPromptQueued = false);
    });
  }
}
