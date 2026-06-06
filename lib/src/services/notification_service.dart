import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/models.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be provided at startup.');
});

class NotificationService {
  static const _previewReminderId = 1001;
  static const _occasionalReminderId = 1002;
  static const _scheduledReminderCount = 12;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _timeZonesInitialized = false;

  Future<void> initialize() async {
    await configureLocalTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
  }

  Future<String> configureLocalTimezone({String? fallbackTimezone}) async {
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }

    var timezoneName = fallbackTimezone;
    try {
      timezoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      timezoneName ??= 'UTC';
    }

    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      timezoneName = 'UTC';
      tz.setLocalLocation(tz.getLocation(timezoneName));
    }

    return timezoneName;
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

  Future<ReminderScheduleResult> scheduleOccasionalReminders({
    required AppSettings settings,
  }) async {
    await cancelOccasionalReminders();

    final timezoneName = await configureLocalTimezone(
      fallbackTimezone: settings.reminderTimezone,
    );
    final now = tz.TZDateTime.now(tz.local);
    var anchor = _firstReminderAnchorAfter(now, settings);
    tz.TZDateTime? firstDelivery;

    for (var index = 0; index < _scheduledReminderCount; index += 1) {
      final delivery = _moveOutOfQuietHours(anchor, settings);
      firstDelivery ??= delivery;

      try {
        await _plugin.zonedSchedule(
          id: _occasionalReminderId + index,
          scheduledDate: delivery,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: settings.hiddenNotifications
              ? 'Gentle check-in'
              : 'A gentle Stillpoint check-in',
          body: settings.hiddenNotifications
              ? 'Open the app when you have a quiet moment.'
              : 'All local. Nobody is judging. Log only what feels useful.',
          notificationDetails: _reminderDetails(),
          payload: 'occasional_check_in',
        );
      } on UnimplementedError {
        break;
      }

      anchor = tz.TZDateTime(
        tz.local,
        anchor.year,
        anchor.month,
        anchor.day + settings.reminderCadenceDays,
        settings.reminderHour,
        settings.reminderMinute,
      );
    }

    return ReminderScheduleResult(
      timezoneName: timezoneName,
      nextDelivery: firstDelivery,
    );
  }

  Future<void> cancelOccasionalReminders() async {
    for (var index = 0; index < _scheduledReminderCount; index += 1) {
      await _plugin.cancel(id: _occasionalReminderId + index);
    }
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

  static DateTime nextAllowedReminderAfter({
    required DateTime now,
    required AppSettings settings,
  }) {
    var anchor = DateTime(
      now.year,
      now.month,
      now.day,
      settings.reminderHour,
      settings.reminderMinute,
    );

    while (true) {
      final delivery = _moveDateTimeOutOfQuietHours(anchor, settings);
      if (delivery.isAfter(now)) return delivery;
      anchor = DateTime(
        anchor.year,
        anchor.month,
        anchor.day + settings.reminderCadenceDays,
        settings.reminderHour,
        settings.reminderMinute,
      );
    }
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

  static tz.TZDateTime _firstReminderAnchorAfter(
    tz.TZDateTime now,
    AppSettings settings,
  ) {
    var anchor = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.reminderHour,
      settings.reminderMinute,
    );

    while (!_moveOutOfQuietHours(anchor, settings).isAfter(now)) {
      anchor = tz.TZDateTime(
        tz.local,
        anchor.year,
        anchor.month,
        anchor.day + settings.reminderCadenceDays,
        settings.reminderHour,
        settings.reminderMinute,
      );
    }
    return anchor;
  }

  static tz.TZDateTime _moveOutOfQuietHours(
    tz.TZDateTime value,
    AppSettings settings,
  ) {
    if (!settings.isInQuietHours(value.hour * 60 + value.minute)) return value;

    final wrapsMidnight = settings.quietStartMinutes > settings.quietEndMinutes;
    final afterQuietStart =
        value.hour * 60 + value.minute >= settings.quietStartMinutes;
    final dayOffset = wrapsMidnight && afterQuietStart ? 1 : 0;
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day + dayOffset,
      settings.quietEndHour,
      settings.quietEndMinute,
    );
  }

  static DateTime _moveDateTimeOutOfQuietHours(
    DateTime value,
    AppSettings settings,
  ) {
    if (!settings.isInQuietHours(value.hour * 60 + value.minute)) return value;

    final wrapsMidnight = settings.quietStartMinutes > settings.quietEndMinutes;
    final afterQuietStart =
        value.hour * 60 + value.minute >= settings.quietStartMinutes;
    final dayOffset = wrapsMidnight && afterQuietStart ? 1 : 0;
    return DateTime(
      value.year,
      value.month,
      value.day + dayOffset,
      settings.quietEndHour,
      settings.quietEndMinute,
    );
  }
}

class ReminderScheduleResult {
  const ReminderScheduleResult({
    required this.timezoneName,
    required this.nextDelivery,
  });

  final String timezoneName;
  final DateTime? nextDelivery;
}
