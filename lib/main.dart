import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/app.dart';
import 'src/data/habit_repository.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Hive.initFlutter();

  final repository = await HiveHabitRepository.open();
  final notifications = NotificationService();
  await notifications.initialize();
  final initialState = await repository.load();
  if (initialState.settings.privacyConsentCompleted &&
      initialState.settings.softReminders) {
    final result = await notifications.scheduleOccasionalReminders(
      settings: initialState.settings,
      state: initialState,
    );
    if (result.timezoneName != initialState.settings.reminderTimezone) {
      await repository.save(
        initialState.copyWith(
          settings: initialState.settings.copyWith(
            reminderTimezone: result.timezoneName,
          ),
        ),
      );
    }
  } else {
    await notifications.cancelOccasionalReminders();
  }

  runApp(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const StillpointApp(),
    ),
  );
}
