import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stillpoint/src/core/currency.dart';
import 'package:stillpoint/src/core/models.dart';
import 'package:stillpoint/src/data/habit_repository.dart';
import 'package:stillpoint/src/state/app_controller.dart';

void main() {
  test('money formatter uses the rupee display symbol by default', () {
    expect(formatMoney(12.5), '₹12.50');
  });

  test(
    'confirming currency cosmetically keeps saved numbers unchanged',
    () async {
      final repository = _MemoryHabitRepository(_stateWithMoney());
      final container = ProviderContainer(
        overrides: [habitRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(appControllerProvider.future);
      await container
          .read(appControllerProvider.notifier)
          .confirmMoneyCurrency();

      final state = container.read(appControllerProvider).requireValue;
      expect(state.settings.moneyCurrencySetupCompleted, isTrue);
      expect(state.habits.first.costPerUnit, 10);
      expect(state.entries.first.unitCost, 4);
      expect(repository.saved.habits.first.costPerUnit, 10);
    },
  );

  test(
    'currency conversion multiplies tracker and log cost snapshots',
    () async {
      final repository = _MemoryHabitRepository(_stateWithMoney());
      final container = ProviderContainer(
        overrides: [habitRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(appControllerProvider.future);
      await container
          .read(appControllerProvider.notifier)
          .confirmMoneyCurrency(conversionRate: 2);

      final state = container.read(appControllerProvider).requireValue;
      expect(state.settings.moneyCurrencySetupCompleted, isTrue);
      expect(state.habits.first.costPerUnit, 20);
      expect(state.entries.first.unitCost, 8);
      expect(repository.saved.habits.first.costPerUnit, 20);
    },
  );
}

AppState _stateWithMoney() {
  final habit = Habit(
    id: 'coffee',
    name: 'Coffee',
    category: HabitCategory.caffeine,
    unit: 'cups',
    colorValue: 0xFFB88A44,
    createdAt: DateTime(2026),
    costPerUnit: 10,
  );
  return AppState(
    habits: [habit],
    entries: [
      UsageEntry(
        id: 'entry',
        habitId: habit.id,
        loggedAt: DateTime(2026, 6, 8),
        quantity: 2,
        unitCost: 4,
      ),
    ],
    settings: const AppSettings(),
  );
}

class _MemoryHabitRepository implements HabitRepository {
  _MemoryHabitRepository(this.saved);

  AppState saved;

  @override
  Future<AppState> load() async => saved;

  @override
  Future<void> save(AppState state) async {
    saved = state;
  }
}
