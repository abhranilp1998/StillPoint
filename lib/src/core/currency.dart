import 'models.dart';

String formatMoney(double value, {AppSettings? settings}) {
  final symbol =
      settings?.moneyCurrencySymbol ?? AppSettings.defaultMoneyCurrencySymbol;
  return '$symbol${value.toStringAsFixed(2)}';
}

bool hasSavedMoneyValues(AppState state) {
  return state.habits.any((habit) => (habit.costPerUnit ?? 0) > 0) ||
      state.entries.any((entry) => (entry.unitCost ?? 0) > 0);
}
