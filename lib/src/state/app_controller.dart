import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../data/habit_repository.dart';
import '../services/analytics_service.dart';
import '../services/insight_engine.dart';

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

final analyticsProvider = Provider<AnalyticsSnapshot>((ref) {
  final appState = ref
      .watch(appControllerProvider)
      .maybeWhen(data: (state) => state, orElse: () => null);
  return AnalyticsService.buildSnapshot(appState ?? AppState.initial());
});

final insightsProvider = Provider<List<BehaviorInsight>>((ref) {
  final appState = ref
      .watch(appControllerProvider)
      .maybeWhen(data: (state) => state, orElse: () => null);
  final analytics = ref.watch(analyticsProvider);
  return InsightEngine.generate(appState ?? AppState.initial(), analytics);
});

class AppController extends AsyncNotifier<AppState> {
  static const _uuid = Uuid();

  late HabitRepository _repository;

  @override
  Future<AppState> build() async {
    _repository = ref.watch(habitRepositoryProvider);
    return _repository.load();
  }

  Future<AppState> _current() async {
    return state.maybeWhen(data: (state) => state, orElse: () => null) ??
        await future;
  }

  Future<UsageEntry> logEntry({
    required Habit habit,
    required double quantity,
    int? mood,
    int? craving,
    int? stress,
    String? trigger,
    String? note,
    DateTime? loggedAt,
  }) async {
    final current = await _current();
    final entry = UsageEntry(
      id: _uuid.v4(),
      habitId: habit.id,
      loggedAt: loggedAt ?? DateTime.now(),
      quantity: quantity,
      mood: mood,
      craving: craving,
      stress: stress,
      trigger: trigger?.trim().isEmpty ?? true ? null : trigger!.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      unitCost: habit.costPerUnit == null || habit.costPerUnit! <= 0
          ? null
          : habit.costPerUnit,
    );

    final next = current.copyWith(entries: [...current.entries, entry]);
    state = AsyncData(next);
    await _repository.save(next);
    return entry;
  }

  Future<void> repeatLastEntry() async {
    final current = await _current();
    final last = current.lastEntry;
    if (last == null) return;

    final nextEntry = last.copyWith(id: _uuid.v4(), loggedAt: DateTime.now());
    final next = current.copyWith(entries: [...current.entries, nextEntry]);
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> deleteEntry(String entryId) async {
    final current = await _current();
    final next = current.copyWith(
      entries: current.entries.where((entry) => entry.id != entryId).toList(),
    );
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> updateEntry(UsageEntry updatedEntry) async {
    final current = await _current();
    final next = current.copyWith(
      entries: [
        for (final entry in current.entries)
          if (entry.id == updatedEntry.id) updatedEntry else entry,
      ],
    );
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> addCustomHabit({
    required String name,
    required HabitCategory category,
    required String unit,
    double? costPerUnit,
  }) async {
    final current = await _current();
    final palette = [
      0xFF6A8F7A,
      0xFF4F8DAA,
      0xFFC77D57,
      0xFFB88A44,
      0xFF8C6A93,
      0xFF5B7F95,
    ];
    final habit = Habit(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      unit: unit.trim().isEmpty ? category.defaultUnit : unit.trim(),
      colorValue: palette[current.habits.length % palette.length],
      createdAt: DateTime.now(),
      costPerUnit: costPerUnit == null || costPerUnit <= 0 ? null : costPerUnit,
    );

    final next = current.copyWith(habits: [...current.habits, habit]);
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> updateHabit(Habit habit) async {
    final current = await _current();
    final next = current.copyWith(
      habits: [
        for (final existing in current.habits)
          if (existing.id == habit.id) habit else existing,
      ],
    );
    state = AsyncData(next);
    await _repository.save(next);
  }

  Future<void> updateSettings(AppSettings settings) async {
    final current = await _current();
    final next = current.copyWith(settings: settings);
    state = AsyncData(next);
    await _repository.save(next);
  }
}
