import 'dart:math';

import 'models.dart';

const _epsilon = .000001;

List<double> quantityPresetsFor(Habit habit) {
  return switch (habit.category) {
    HabitCategory.doomscrolling => const [5, 15, 30, 60],
    HabitCategory.caffeine => const [1, 2, 3],
    HabitCategory.alcohol => const [1, 2, 3, 4],
    HabitCategory.cigarettes => const [1, 2, 5],
    HabitCategory.pills ||
    HabitCategory.prescriptionMisuse ||
    HabitCategory.opioids ||
    HabitCategory.benzodiazepines ||
    HabitCategory.sedatives ||
    HabitCategory.coughMedicine ||
    HabitCategory.kratom => const [.5, 1, 2],
    HabitCategory.custom => _customUnitPresets(habit.unit),
    _ => const [1, 2, 3],
  };
}

double defaultQuantityFor(Habit? habit) {
  if (habit == null) return 1;
  return switch (habit.category) {
    HabitCategory.doomscrolling => 15,
    HabitCategory.caffeine => 1,
    HabitCategory.gambling => 1,
    HabitCategory.pills ||
    HabitCategory.prescriptionMisuse ||
    HabitCategory.opioids ||
    HabitCategory.benzodiazepines ||
    HabitCategory.sedatives ||
    HabitCategory.coughMedicine ||
    HabitCategory.kratom => 1,
    HabitCategory.custom when _isDurationUnit(habit.unit) => 5,
    HabitCategory.custom when _isDoseUnit(habit.unit) => 1,
    _ => 1,
  };
}

double increaseQuantity(Habit habit, double quantity) {
  final presetIndex = _matchingPresetIndex(habit, quantity);
  final presets = quantityPresetsFor(habit);
  if (presetIndex != null && presetIndex < presets.length - 1) {
    return presets[presetIndex + 1];
  }
  return normalizeQuantity(quantity + quantityStepFor(habit));
}

double decreaseQuantity(
  Habit habit,
  double quantity, {
  bool allowZero = false,
}) {
  final presets = quantityPresetsFor(habit);
  final minimum = allowZero ? 0.0 : presets.first;
  final presetIndex = _matchingPresetIndex(habit, quantity);

  if (presetIndex != null) {
    if (presetIndex > 0) return presets[presetIndex - 1];
    return minimum;
  }

  return normalizeQuantity(max(minimum, quantity - quantityStepFor(habit)));
}

bool canDecreaseQuantity(
  Habit habit,
  double quantity, {
  bool allowZero = false,
}) {
  final minimum = allowZero ? 0.0 : quantityPresetsFor(habit).first;
  return quantity > minimum + _epsilon;
}

bool sameQuantity(double a, double b) => (a - b).abs() < _epsilon;

String formatQuantity(double value) {
  final normalized = normalizeQuantity(value);
  return sameQuantity(normalized, normalized.roundToDouble())
      ? normalized.toInt().toString()
      : normalized.toStringAsFixed(1);
}

double normalizeQuantity(double value) => (value * 10).roundToDouble() / 10;

List<double> _customUnitPresets(String unit) {
  if (_isDurationUnit(unit)) return const [5, 15, 30, 60];
  if (_isDoseUnit(unit)) return const [.5, 1, 2];
  return const [1, 2, 3];
}

double quantityStepFor(Habit habit) {
  if (habit.category == HabitCategory.doomscrolling ||
      _isDurationUnit(habit.unit)) {
    return 5;
  }
  if (habit.category == HabitCategory.pills ||
      habit.category == HabitCategory.prescriptionMisuse ||
      habit.category == HabitCategory.opioids ||
      habit.category == HabitCategory.benzodiazepines ||
      habit.category == HabitCategory.sedatives ||
      habit.category == HabitCategory.coughMedicine ||
      habit.category == HabitCategory.kratom ||
      _isDoseUnit(habit.unit)) {
    return .5;
  }
  return 1;
}

int? _matchingPresetIndex(Habit habit, double quantity) {
  final presets = quantityPresetsFor(habit);
  for (var index = 0; index < presets.length; index++) {
    if (sameQuantity(presets[index], quantity)) return index;
  }
  return null;
}

bool _isDurationUnit(String unit) {
  final normalized = _normalizedUnit(unit);
  return normalized == 'min' ||
      normalized == 'mins' ||
      normalized == 'minute' ||
      normalized == 'minutes' ||
      normalized == 'hr' ||
      normalized == 'hrs' ||
      normalized == 'hour' ||
      normalized == 'hours';
}

bool _isDoseUnit(String unit) {
  final normalized = _normalizedUnit(unit);
  return normalized == 'pill' ||
      normalized == 'pills' ||
      normalized == 'tablet' ||
      normalized == 'tablets' ||
      normalized == 'capsule' ||
      normalized == 'capsules' ||
      normalized == 'dose' ||
      normalized == 'doses';
}

String _normalizedUnit(String unit) => unit.trim().toLowerCase();
