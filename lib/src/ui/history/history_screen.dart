import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../services/export_service.dart';
import '../../state/app_controller.dart';
import '../habit/entry_editor_sheet.dart';
import '../habit/habit_detail_screen.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/habit_visuals.dart';

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
    final entries = state == null
        ? const <UsageEntry>[]
        : _filteredEntries(state);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('History')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: _HistoryControls(
              controller: _searchController,
              sort: _sort,
              range: _range,
              exporting: _exporting,
              onSortChanged: (value) => setState(() => _sort = value),
              onPickRange: _pickRange,
              onClearRange: () => setState(() => _range = null),
              onExportCsv: state == null
                  ? null
                  : () =>
                        _export(state.copyWith(entries: entries), xlsx: false),
              onExportXlsx: state == null
                  ? null
                  : () => _export(state.copyWith(entries: entries), xlsx: true),
            ),
          ),
        ),
        if (state == null || entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state == null
                      ? 'Loading local history.'
                      : 'No logs match this view.',
                  textAlign: TextAlign.center,
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
                child: _HistoryRow(
                  entry: entry,
                  habit: habit,
                  onEdit: () =>
                      showEntryEditorSheet(context, entry: entry, habit: habit),
                  onOpenHabit: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HabitDetailScreen(habitId: habit.id),
                    ),
                  ),
                  onDelete: () => ref
                      .read(appControllerProvider.notifier)
                      .deleteEntry(entry.id),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  List<UsageEntry> _filteredEntries(AppState state) {
    final habitsById = {for (final habit in state.habits) habit.id: habit};
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
      return inSearch && inRange;
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
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search logs',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<HistorySort>(
                value: sort,
                borderRadius: BorderRadius.circular(8),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: HistorySort.newest,
                    child: Text('Newest'),
                  ),
                  DropdownMenuItem(
                    value: HistorySort.oldest,
                    child: Text('Oldest'),
                  ),
                  DropdownMenuItem(
                    value: HistorySort.quantityHigh,
                    child: Text('Most quantity'),
                  ),
                  DropdownMenuItem(
                    value: HistorySort.quantityLow,
                    child: Text('Least quantity'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
              FilterChip(
                selected: range != null,
                avatar: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  range == null
                      ? 'Date range'
                      : '${DateFormat.MMMd().format(range!.start)}-${DateFormat.MMMd().format(range!.end)}',
                ),
                onSelected: (_) => onPickRange(),
              ),
              if (range != null)
                IconButton.outlined(
                  tooltip: 'Clear range',
                  onPressed: onClearRange,
                  icon: const Icon(Icons.close_rounded),
                ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : onExportCsv,
                icon: const Icon(Icons.description_outlined),
                label: const Text('CSV'),
              ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : onExportXlsx,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('XLSX'),
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
        ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onEdit,
      child: CalmCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(habit.colorValue).withValues(alpha: .16),
              child: Icon(
                habitIcon(habit.category),
                color: Color(habit.colorValue),
              ),
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
                      Text(
                        '${entry.quantity.toStringAsFixed(entry.quantity == entry.quantity.roundToDouble() ? 0 : 1)} ${habit.unit}',
                        style: theme.textTheme.labelLarge,
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
      ),
    );
  }
}
