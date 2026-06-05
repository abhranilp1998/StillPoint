import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be provided at startup.');
});

class NotificationService {
  static const _previewReminderId = 1001;
  static const _occasionalReminderId = 1002;

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

  Future<bool> requestPermissions() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    return androidGranted ?? iosGranted ?? true;
  }

  Future<void> scheduleOccasionalReminders({
    required bool hiddenContent,
  }) async {
    await cancelOccasionalReminders();
    await _plugin.periodicallyShowWithDuration(
      id: _occasionalReminderId,
      repeatDurationInterval: const Duration(days: 3),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: hiddenContent ? 'Gentle check-in' : 'A gentle Stillpoint check-in',
      body: hiddenContent
          ? 'Open the app when you have a quiet moment.'
          : 'All local. Nobody is judging. Log only what feels useful.',
      notificationDetails: _reminderDetails(),
      payload: 'occasional_check_in',
    );
  }

  Future<void> cancelOccasionalReminders() {
    return _plugin.cancel(id: _occasionalReminderId);
  }

  Future<void> showSoftReminder({required bool hiddenContent}) async {
    await _plugin.show(
      id: _previewReminderId,
      title: hiddenContent ? 'Mindful check-in' : 'You are allowed to go slow',
      body: hiddenContent
          ? 'Open the app when you have a quiet moment.'
          : 'A tiny log is enough. All local, no judgment.',
      notificationDetails: _reminderDetails(),
    );
  }

  NotificationDetails _reminderDetails() {
    const android = AndroidNotificationDetails(
      'mindful_recovery_soft_reminders',
      'Gentle check-ins',
      channelDescription:
          'Optional, warm reminders for calm local self-check-ins.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const ios = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.passive,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }
}
