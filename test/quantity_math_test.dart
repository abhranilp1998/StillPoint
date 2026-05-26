import 'package:adaptive_recovery_tracker/src/core/models.dart';
import 'package:adaptive_recovery_tracker/src/core/quantity_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Habit habit({
    HabitCategory category = HabitCategory.custom,
    String unit = 'units',
  }) {
    return Habit(
      id: 'habit',
      name: 'Habit',
      category: category,
      unit: unit,
      colorValue: 0xFF6A8F7A,
      createdAt: DateTime(2026),
    );
  }

  test('custom duration units use duration presets and increments', () {
    final minutes = habit(unit: 'minutes');

    expect(defaultQuantityFor(minutes), 5);
    expect(quantityPresetsFor(minutes), [5, 15, 30, 60]);
    expect(increaseQuantity(minutes, 5), 15);
    expect(increaseQuantity(minutes, 60), 65);
  });

  test('dose-like custom units preserve half-step calculations', () {
    final doses = habit(unit: 'doses');

    expect(quantityPresetsFor(doses), [.5, 1, 2]);
    expect(decreaseQuantity(doses, 1), .5);
    expect(increaseQuantity(doses, .5), 1);
    expect(increaseQuantity(doses, 2), 2.5);
  });

  test('editor controls can step down to zero without going negative', () {
    final doses = habit(unit: 'pills');

    expect(decreaseQuantity(doses, .5, allowZero: true), 0);
    expect(canDecreaseQuantity(doses, 0, allowZero: true), isFalse);
  });
}
