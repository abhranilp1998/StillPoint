import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/quantity_math.dart';
import '../../state/app_controller.dart';

Future<void> showEntryEditorSheet(
  BuildContext context, {
  required UsageEntry entry,
  required Habit habit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => EntryEditorSheet(entry: entry, habit: habit),
  );
}

class EntryEditorSheet extends ConsumerStatefulWidget {
  const EntryEditorSheet({super.key, required this.entry, required this.habit});

  final UsageEntry entry;
  final Habit habit;

  @override
  ConsumerState<EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends ConsumerState<EntryEditorSheet> {
  late double _quantity;
  late int? _mood;
  late int? _craving;
  late int? _stress;
  late String? _trigger;
  late DateTime _loggedAt;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _quantity = widget.entry.quantity;
    _mood = widget.entry.mood;
    _craving = widget.entry.craving;
    _stress = widget.entry.stress;
    _trigger = widget.entry.trigger;
    _loggedAt = widget.entry.loggedAt;
    _noteController = TextEditingController(text: widget.entry.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final unitCost = _effectiveUnitCost;
    final cost = unitCost == null ? null : _quantity * unitCost;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Edit log', style: theme.textTheme.titleLarge),
                ),
                TextButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(DateFormat('MMM d, h:mm a').format(_loggedAt)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.habit.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Decrease',
                  onPressed:
                      canDecreaseQuantity(
                        widget.habit,
                        _quantity,
                        allowZero: true,
                      )
                      ? () => setState(
                          () => _quantity = decreaseQuantity(
                            widget.habit,
                            _quantity,
                            allowZero: true,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${formatQuantity(_quantity)} ${widget.habit.unit}',
                      style: theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Increase',
                  onPressed: () => setState(
                    () => _quantity = increaseQuantity(widget.habit, _quantity),
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EntryCostPreview(
              cost: cost,
              unitCost: unitCost,
              habit: widget.habit,
            ),
            const SizedBox(height: 14),
            _ScaleChips(
              title: 'Mood',
              value: _mood,
              labels: const ['Heavy', 'Low', 'Steady', 'Clear', 'Light'],
              onChanged: (value) => setState(() => _mood = value),
            ),
            const SizedBox(height: 12),
            _ScaleChips(
              title: 'Craving',
              value: _craving,
              labels: const ['Quiet', 'Mild', 'Moderate', 'Strong', 'Intense'],
              onChanged: (value) => setState(() => _craving = value),
            ),
            const SizedBox(height: 12),
            _ScaleChips(
              title: 'Stress',
              value: _stress,
              labels: const ['Quiet', 'Mild', 'Moderate', 'Strong', 'Intense'],
              onChanged: (value) => setState(() => _stress = value),
            ),
            const SizedBox(height: 12),
            _TriggerChips(
              trigger: _trigger,
              onChanged: (value) => setState(() => _trigger = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional context',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save changes'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Clear log',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(_loggedAt.year - 5),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: _loggedAt,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null) return;
    setState(() {
      _loggedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    await ref
        .read(appControllerProvider.notifier)
        .updateEntry(
          UsageEntry(
            id: widget.entry.id,
            habitId: widget.entry.habitId,
            loggedAt: _loggedAt,
            quantity: _quantity,
            mood: _mood,
            craving: _craving,
            stress: _stress,
            trigger: _trigger,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            unitCost: _effectiveUnitCost,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  double? get _effectiveUnitCost {
    final cost = widget.entry.unitCost ?? widget.habit.costPerUnit;
    if (cost == null || cost <= 0) return null;
    return cost;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this log?'),
        content: const Text('This removes the entry from local history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appControllerProvider.notifier).deleteEntry(widget.entry.id);
    if (mounted) Navigator.pop(context);
  }
}

class _EntryCostPreview extends StatelessWidget {
  const _EntryCostPreview({
    required this.cost,
    required this.unitCost,
    required this.habit,
  });

  final double? cost;
  final double? unitCost;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cost == null
                    ? 'No cost attached to this log.'
                    : '${_formatMoney(cost!)} for this log · ${_formatMoney(unitCost!)} per ${habit.unit}.',
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

String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
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
