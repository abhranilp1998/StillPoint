import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be provided at startup.');
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
  }

  Future<void> showSoftReminder({required bool hiddenContent}) async {
    const android = AndroidNotificationDetails(
      'mindful_recovery_soft_reminders',
      'Soft reminders',
      channelDescription: 'Optional, neutral reminders for logging patterns.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const ios = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.passive,
    );

    await _plugin.show(
      id: 1001,
      title: hiddenContent
          ? 'Mindful check-in'
          : 'Would you like to log today?',
      body: hiddenContent
          ? 'Open the app when you have a quiet moment.'
          : 'You usually log around this time.',
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
    );
  }
}
