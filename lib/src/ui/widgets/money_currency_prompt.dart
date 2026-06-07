import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/models.dart';
import '../../state/app_controller.dart';

bool shouldPromptForMoneyCurrency(AppState state) {
  return !state.settings.moneyCurrencySetupCompleted &&
      hasSavedMoneyValues(state);
}

Future<void> showMoneyCurrencyPrompt(
  BuildContext context,
  WidgetRef ref, {
  bool requireChoice = true,
}) async {
  final current = ref
      .read(appControllerProvider)
      .maybeWhen(data: (state) => state, orElse: () => null);
  if (current == null) return;
  if (current.settings.moneyCurrencySetupCompleted && requireChoice) return;

  final hasSavedValues = hasSavedMoneyValues(current);
  final rateController = TextEditingController();
  var convertValues = false;
  String? rateError;

  await showDialog<void>(
    context: context,
    barrierDismissible: !requireChoice,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> save({double? rate}) async {
          await ref
              .read(appControllerProvider.notifier)
              .confirmMoneyCurrency(conversionRate: rate);
          if (context.mounted) Navigator.pop(context);
        }

        return AlertDialog(
          title: const Text('Money display'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stillpoint now labels money as ${AppSettings.defaultMoneyCurrencySymbol}. Saved numbers can stay exactly as they are, with only the symbol changing.',
                ),
                if (hasSavedValues) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Convert saved values'),
                    subtitle: const Text(
                      'Use this only if old entries were meant as another currency and should be multiplied into the new display.',
                    ),
                    value: convertValues,
                    onChanged: (value) {
                      setDialogState(() {
                        convertValues = value;
                        rateError = null;
                      });
                    },
                  ),
                  if (convertValues) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: rateController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'New value for 1 old currency unit',
                        prefixText: AppSettings.defaultMoneyCurrencySymbol,
                        helperText:
                            'Example: enter 83 if 1 old unit should become ${AppSettings.defaultMoneyCurrencySymbol}83.',
                        errorText: rateError,
                      ),
                      onChanged: (_) {
                        if (rateError != null) {
                          setDialogState(() => rateError = null);
                        }
                      },
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'There are no saved money values yet, so there is nothing to convert.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!requireChoice)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            if (!convertValues || !hasSavedValues)
              FilledButton(
                onPressed: () => save(),
                child: Text(
                  hasSavedValues
                      ? 'Keep numbers'
                      : 'Use ${AppSettings.defaultMoneyCurrencySymbol} labels',
                ),
              )
            else
              FilledButton(
                onPressed: () {
                  final rate = double.tryParse(rateController.text.trim());
                  if (rate == null || rate <= 0) {
                    setDialogState(
                      () => rateError = 'Enter a conversion rate above 0.',
                    );
                    return;
                  }
                  save(rate: rate);
                },
                child: const Text('Convert values'),
              ),
          ],
        );
      },
    ),
  );

  rateController.dispose();
}
