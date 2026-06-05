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
    await notifications.scheduleOccasionalReminders(
      hiddenContent: initialState.settings.hiddenNotifications,
    );
  } else {
    await notifications.cancelOccasionalReminders();
  }

  runApp(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const RecoveryApp(),
    ),
  );
}
