import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/models.dart';
import '../../services/export_service.dart';
import '../../state/app_controller.dart';
import '../habit/entry_editor_sheet.dart';
import '../habit/habit_detail_screen.dart';
import '../logging/quick_log_sheet.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';
import '../widgets/tracker_focus_bar.dart';

enum HistorySort { newest, oldest, quantityHigh, quantityLow }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  HistorySort _sort = HistorySort.newest;
  DateTimeRange? _range;
  String _query = '';
  String? _focusedHabitId;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
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
    final filterHabits = _historyFilterHabits(state);
    final validFocusId =
        filterHabits.any((habit) => habit.id == _focusedHabitId)
        ? _focusedHabitId
        : null;
    final entries = state == null
        ? const <UsageEntry>[]
        : _filteredEntries(state);
    final hasFilters =
        _query.isNotEmpty || _range != null || validFocusId != null;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('History')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: MotionReveal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HistoryControls(
                    controller: _searchController,
                    sort: _sort,
                    range: _range,
                    exporting: _exporting,
                    onSortChanged: (value) => setState(() => _sort = value),
                    onPickRange: _pickRange,
                    onClearRange: () => setState(() => _range = null),
                    onExportCsv: state == null
                        ? null
                        : () => _export(
                            state.copyWith(entries: entries),
                            xlsx: false,
                          ),
                    onExportXlsx: state == null
                        ? null
                        : () => _export(
                            state.copyWith(entries: entries),
                            xlsx: true,
                          ),
                  ),
                  if (filterHabits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TrackerFocusBar(
                      habits: filterHabits,
                      selectedHabitId: validFocusId,
                      allLabel: 'All logs',
                      onSelected: (value) =>
                          setState(() => _focusedHabitId = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (state == null || entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              child: Center(
                child: _HistoryEmptyState(
                  loading: state == null,
                  hasAnyLogs: state?.entries.isNotEmpty ?? false,
                  hasFilters: hasFilters,
                  onClearFilters: hasFilters ? _clearFilters : null,
                  onLog: state == null
                      ? null
                      : () => showQuickLogSheet(context),
                ),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TableHeader(count: entries.length),
            ),
          ),
          SliverList.separated(
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final habit = state.habits.firstWhere(
                (item) => item.id == entry.habitId,
                orElse: () => Habit(
                  id: entry.habitId,
                  name: 'Unknown',
                  category: HabitCategory.custom,
                  unit: 'units',
                  colorValue: 0xFF7E8A97,
                  createdAt: entry.loggedAt,
                ),
              );
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  index == entries.length - 1 ? 120 : 0,
                ),
                child: MotionReveal(
                  delay: Duration(milliseconds: (index % 8) * 24),
                  child: _HistoryRow(
                    entry: entry,
                    habit: habit,
                    onEdit: () => showEntryEditorSheet(
                      context,
                      entry: entry,
                      habit: habit,
                    ),
                    onOpenHabit: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HabitDetailScreen(habitId: habit.id),
                      ),
                    ),
                    onDelete: () => _deleteEntryWithUndo(entry),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _range = null;
      _sort = HistorySort.newest;
      _focusedHabitId = null;
    });
  }

  List<UsageEntry> _filteredEntries(AppState state) {
    final habitsById = {for (final habit in state.habits) habit.id: habit};
    final focusedHabitId = habitsById.containsKey(_focusedHabitId)
        ? _focusedHabitId
        : null;
    final entries = state.entries.where((entry) {
      final habit = habitsById[entry.habitId];
      final inSearch =
          _query.isEmpty ||
          (habit?.name.toLowerCase().contains(_query) ?? false) ||
          (entry.trigger?.toLowerCase().contains(_query) ?? false) ||
          (entry.note?.toLowerCase().contains(_query) ?? false);
      final inRange =
          _range == null ||
          (!entry.loggedAt.isBefore(_range!.start) &&
              !entry.loggedAt.isAfter(
                _range!.end.add(const Duration(days: 1)),
              ));
      final inFocus = focusedHabitId == null || entry.habitId == focusedHabitId;
      return inSearch && inRange && inFocus;
    }).toList();

    entries.sort((a, b) {
      return switch (_sort) {
        HistorySort.newest => b.loggedAt.compareTo(a.loggedAt),
        HistorySort.oldest => a.loggedAt.compareTo(b.loggedAt),
        HistorySort.quantityHigh => b.quantity.compareTo(a.quantity),
        HistorySort.quantityLow => a.quantity.compareTo(b.quantity),
      };
    });
    return entries;
  }

  List<Habit> _historyFilterHabits(AppState? state) {
    if (state == null) return const <Habit>[];
    final usedHabitIds = state.entries.map((entry) => entry.habitId).toSet();
    final habits = state.habits
        .where((habit) => usedHabitIds.contains(habit.id))
        .toList(growable: false);
    habits.sort((a, b) {
      if (a.archived != b.archived) return a.archived ? 1 : -1;
      return a.name.compareTo(b.name);
    });
    return habits;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _export(AppState state, {required bool xlsx}) async {
    setState(() => _exporting = true);
    try {
      final result = xlsx
          ? await ExportService.exportXlsx(state)
          : await ExportService.exportCsv(state);
      await ExportService.shareExport(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.format} export prepared.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteEntryWithUndo(UsageEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    await ref.read(appControllerProvider.notifier).deleteEntry(entry.id);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Log cleared from history.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(appControllerProvider.notifier).restoreEntry(entry);
          },
        ),
      ),
    );
  }
}

class _HistoryControls extends StatelessWidget {
  const _HistoryControls({
    required this.controller,
    required this.sort,
    required this.range,
    required this.exporting,
    required this.onSortChanged,
    required this.onPickRange,
    required this.onClearRange,
    required this.onExportCsv,
    required this.onExportXlsx,
  });

  final TextEditingController controller;
  final HistorySort sort;
  final DateTimeRange? range;
  final bool exporting;
  final ValueChanged<HistorySort> onSortChanged;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportXlsx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search logs',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<HistorySort>(
                tooltip: 'Sort logs',
                initialValue: sort,
                onSelected: onSortChanged,
                icon: const Icon(Icons.sort_rounded),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: HistorySort.newest,
                    child: Text('Newest'),
                  ),
                  PopupMenuItem(
                    value: HistorySort.oldest,
                    child: Text('Oldest'),
                  ),
                  PopupMenuItem(
                    value: HistorySort.quantityHigh,
                    child: Text('Most quantity'),
                  ),
                  PopupMenuItem(
                    value: HistorySort.quantityLow,
                    child: Text('Least quantity'),
                  ),
                ],
              ),
              IconButton(
                tooltip: range == null ? 'Date range' : 'Change date range',
                onPressed: onPickRange,
                icon: Icon(
                  range == null
                      ? Icons.date_range_outlined
                      : Icons.date_range_rounded,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Export logs',
                enabled:
                    !exporting && (onExportCsv != null || onExportXlsx != null),
                icon: const Icon(Icons.ios_share_rounded),
                onSelected: (value) {
                  if (value == 'csv') onExportCsv?.call();
                  if (value == 'xlsx') onExportXlsx?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'csv',
                    child: ListTile(
                      leading: Icon(Icons.description_outlined),
                      title: Text('Export CSV'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'xlsx',
                    child: ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Export XLSX'),
                    ),
                  ),
                ],
              ),
              if (exporting)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (range != null || sort != HistorySort.newest) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (sort != HistorySort.newest)
                    InputChip(
                      avatar: const Icon(Icons.sort_rounded, size: 16),
                      label: Text(_sortLabel(sort)),
                      onDeleted: () => onSortChanged(HistorySort.newest),
                    ),
                  if (range != null)
                    InputChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(
                        '${DateFormat.MMMd().format(range!.start)}-${DateFormat.MMMd().format(range!.end)}',
                      ),
                      onDeleted: onClearRange,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sortLabel(HistorySort value) {
    return switch (value) {
      HistorySort.newest => 'Newest',
      HistorySort.oldest => 'Oldest',
      HistorySort.quantityHigh => 'Most quantity',
      HistorySort.quantityLow => 'Least quantity',
    };
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({
    required this.loading,
    required this.hasAnyLogs,
    required this.hasFilters,
    required this.onClearFilters,
    required this.onLog,
  });

  final bool loading;
  final bool hasAnyLogs;
  final bool hasFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const EmptyStateCard(
        icon: Icons.hourglass_empty_rounded,
        title: 'Loading local history',
        body: 'Your saved logs are opening from this device.',
      );
    }

    if (hasAnyLogs && hasFilters) {
      return EmptyStateCard(
        icon: Icons.filter_alt_off_outlined,
        title: 'No logs match these filters',
        body: 'Clear the filters or search for a different tracker or note.',
        action: FilledButton.icon(
          onPressed: onClearFilters,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Clear filters'),
        ),
      );
    }

    return EmptyStateCard(
      icon: Icons.receipt_long_outlined,
      title: 'No logs yet',
      body: 'When you record one moment, it will appear here for review.',
      action: OutlinedButton.icon(
        onPressed: onLog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log now'),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count log${count == 1 ? '' : 's'}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Icon(Icons.table_rows_rounded, color: theme.colorScheme.primary),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.habit,
    required this.onEdit,
    required this.onOpenHabit,
    required this.onDelete,
  });

  final UsageEntry entry;
  final Habit habit;
  final VoidCallback onEdit;
  final VoidCallback onOpenHabit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('MMM d, h:mm a').format(entry.loggedAt);
    final cost = entry.estimatedCostFor(habit);
    final color = Color(habit.colorValue);
    return CalmCard(
      onTap: onEdit,
      semanticLabel: 'Edit ${habit.name} log',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(
            alpha: theme.brightness == Brightness.dark ? .16 : .07,
          ),
          theme.colorScheme.surfaceContainerLow.withValues(alpha: .96),
        ],
      ),
      borderColor: color.withValues(alpha: .16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .16),
            child: Icon(habitIcon(habit.category), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.quantity.toStringAsFixed(entry.quantity == entry.quantity.roundToDouble() ? 0 : 1)} ${habit.unit}',
                          style: theme.textTheme.labelLarge,
                        ),
                        if (cost != null) _CostChip(value: formatMoney(cost)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(date),
                    if (entry.trigger != null) Text(entry.trigger!),
                    if (entry.mood != null)
                      Text('Mood ${moodLabel(entry.mood)}'),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Row actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'tracker') onOpenHabit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit log'),
                ),
              ),
              PopupMenuItem(
                value: 'tracker',
                child: ListTile(
                  leading: Icon(Icons.open_in_new_rounded),
                  title: Text('Tracker details'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Clear log'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: .58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.tertiary.withValues(alpha: .16)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined, size: 13, color: scheme.tertiary),
              const SizedBox(width: 4),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
