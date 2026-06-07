import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models.dart';
import '../../services/notification_service.dart';
import '../../services/security_service.dart';
import '../../state/app_controller.dart';
import '../security/pin_setup_dialog.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/money_currency_prompt.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref
        .watch(appControllerProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final settings = state?.settings ?? const AppSettings();
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Privacy')),
        SliverToBoxAdapter(
          child: ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyHeader(settings: settings),
                const SizedBox(height: 16),
                _SecurityCard(settings: settings),
                const SizedBox(height: 16),
                _NotificationCard(settings: settings),
                const SizedBox(height: 16),
                _AppearanceCard(settings: settings),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: .55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: theme.colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(height: 14),
          Text('Local-first by default', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            settings.offlineMode
                ? 'All local. Nobody is judging. Your logs stay on this device with an encrypted Hive box.'
                : 'Local storage remains active; online sync can be layered behind your consent.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: .76,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'App lock'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Biometric lock'),
            subtitle: const Text('Use device authentication when available.'),
            value: settings.biometricLock,
            onChanged: (value) => _toggleBiometric(context, ref, value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PIN lock'),
            subtitle: const Text('Keep a simple local fallback.'),
            value: settings.pinLock,
            onChanged: (value) => _togglePin(context, ref, value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offline mode'),
            subtitle: const Text(
              'Keep core logging available without network.',
            ),
            value: settings.offlineMode,
            onChanged: (value) => ref
                .read(appControllerProvider.notifier)
                .updateSettings(settings.copyWith(offlineMode: value)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (!value) {
      await ref
          .read(appControllerProvider.notifier)
          .updateSettings(settings.copyWith(biometricLock: false));
      return;
    }

    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    if (!supported && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock is unavailable here.')),
      );
      return;
    }

    await ref
        .read(appControllerProvider.notifier)
        .updateSettings(settings.copyWith(biometricLock: true));
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (!value) {
      await ref
          .read(appControllerProvider.notifier)
          .updateSettings(
            settings.copyWith(pinLock: false, clearPinHash: true),
          );
      return;
    }

    final pin = await showPinSetupDialog(context);
    if (pin == null) return;
    await ref
        .read(appControllerProvider.notifier)
        .updateSettings(
          settings.copyWith(
            pinLock: true,
            pinHash: SecurityService.hashPin(pin),
          ),
        );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Gentle reminders'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Occasional check-ins'),
            subtitle: const Text(
              'Opt-in warm reminders about every few days. No streak pressure.',
            ),
            value: settings.softReminders,
            onChanged: (value) => _toggleReminders(context, ref, value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hidden content'),
            subtitle: const Text(
              'Sensitive details stay out of notifications.',
            ),
            value: settings.hiddenNotifications,
            onChanged: (value) => _saveReminderSettings(
              context,
              ref,
              settings.copyWith(hiddenNotifications: value),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outlineVariant),
          _ReminderTimeRow(
            settings: settings,
            onTap: () => _pickReminderTime(context, ref),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.nights_stay_outlined),
            title: const Text('Quiet hours'),
            subtitle: Text(_quietHoursSummary(context, settings)),
            value: settings.quietHours,
            onChanged: (value) => _saveReminderSettings(
              context,
              ref,
              settings.copyWith(quietHours: value),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: settings.quietHours ? 1 : .46,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: settings.quietHours
                        ? () => _pickQuietTime(context, ref, start: true)
                        : null,
                    icon: const Icon(Icons.bedtime_outlined),
                    label: Text(
                      'Start ${_timeLabel(context, settings.quietStartHour, settings.quietStartMinute)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: settings.quietHours
                        ? () => _pickQuietTime(context, ref, start: false)
                        : null,
                    icon: const Icon(Icons.wb_twilight_outlined),
                    label: Text(
                      'End ${_timeLabel(context, settings.quietEndHour, settings.quietEndMinute)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _TimezoneRow(
            settings: settings,
            onRefresh: () => _refreshTimezone(context, ref),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: settings.softReminders
                  ? () => ref
                        .read(notificationServiceProvider)
                        .showSoftReminder(
                          hiddenContent: settings.hiddenNotifications,
                        )
                  : null,
              icon: const Icon(Icons.notifications_none_rounded),
              label: const Text('Preview reminder'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (!value) {
      await ref.read(notificationServiceProvider).cancelOccasionalReminders();
      await ref
          .read(appControllerProvider.notifier)
          .updateSettings(settings.copyWith(softReminders: false));
      return;
    }

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications stayed off.')),
      );
      return;
    }

    await _saveReminderSettings(
      context,
      ref,
      settings.copyWith(softReminders: true),
      showNextReminder: true,
    );
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked == null || !context.mounted) return;

    await _saveReminderSettings(
      context,
      ref,
      settings.copyWith(
        reminderHour: picked.hour,
        reminderMinute: picked.minute,
      ),
      showNextReminder: settings.softReminders,
    );
  }

  Future<void> _pickQuietTime(
    BuildContext context,
    WidgetRef ref, {
    required bool start,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: start ? settings.quietStartHour : settings.quietEndHour,
        minute: start ? settings.quietStartMinute : settings.quietEndMinute,
      ),
    );
    if (picked == null || !context.mounted) return;

    await _saveReminderSettings(
      context,
      ref,
      start
          ? settings.copyWith(
              quietStartHour: picked.hour,
              quietStartMinute: picked.minute,
            )
          : settings.copyWith(
              quietEndHour: picked.hour,
              quietEndMinute: picked.minute,
            ),
      showNextReminder: settings.softReminders,
    );
  }

  Future<void> _refreshTimezone(BuildContext context, WidgetRef ref) async {
    final timezoneName = await ref
        .read(notificationServiceProvider)
        .configureLocalTimezone(fallbackTimezone: settings.reminderTimezone);
    if (!context.mounted) return;
    await _saveReminderSettings(
      context,
      ref,
      settings.copyWith(reminderTimezone: timezoneName),
      showNextReminder: settings.softReminders,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Timezone set to $timezoneName.')));
    }
  }

  Future<void> _saveReminderSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings next, {
    bool showNextReminder = false,
  }) async {
    ReminderScheduleResult? scheduleResult;
    if (next.softReminders) {
      scheduleResult = await ref
          .read(notificationServiceProvider)
          .scheduleOccasionalReminders(settings: next);
      next = next.copyWith(reminderTimezone: scheduleResult.timezoneName);
    }

    await ref.read(appControllerProvider.notifier).updateSettings(next);
    if (!context.mounted || !showNextReminder) return;

    final nextDelivery = scheduleResult?.nextDelivery;
    if (nextDelivery == null) return;
    final formatted = DateFormat.MMMd().add_jm().format(nextDelivery);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Next gentle check-in: $formatted.')),
    );
  }

  String _quietHoursSummary(BuildContext context, AppSettings settings) {
    if (!settings.quietHours) return 'Reminders can arrive any time.';
    return '${_timeLabel(context, settings.quietStartHour, settings.quietStartMinute)} to '
        '${_timeLabel(context, settings.quietEndHour, settings.quietEndMinute)}';
  }
}

class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({required this.settings, required this.onTap});

  final AppSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_rounded),
      title: const Text('Preferred check-in time'),
      subtitle: Text(
        'Every ${settings.reminderCadenceDays} days near ${_timeLabel(context, settings.reminderHour, settings.reminderMinute)}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _TimezoneRow extends StatelessWidget {
  const _TimezoneRow({required this.settings, required this.onRefresh});

  final AppSettings settings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public_rounded),
      title: const Text('Timezone'),
      subtitle: Text(settings.reminderTimezone ?? 'Device timezone'),
      trailing: IconButton(
        tooltip: 'Refresh timezone',
        onPressed: onRefresh,
        icon: const Icon(Icons.sync_rounded),
      ),
    );
  }
}

String _timeLabel(BuildContext context, int hour, int minute) {
  return TimeOfDay(hour: hour, minute: minute).format(context);
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Comfort'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use system theme'),
            value: settings.useSystemTheme,
            onChanged: (value) => ref
                .read(appControllerProvider.notifier)
                .updateSettings(settings.copyWith(useSystemTheme: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            value: settings.darkMode,
            onChanged: settings.useSystemTheme
                ? null
                : (value) => ref
                      .read(appControllerProvider.notifier)
                      .updateSettings(settings.copyWith(darkMode: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Soften animations for low-attention moments.',
            ),
            value: settings.reduceMotion,
            onChanged: (value) => ref
                .read(appControllerProvider.notifier)
                .updateSettings(settings.copyWith(reduceMotion: value)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Money display'),
            subtitle: Text(
              settings.moneyCurrencySetupCompleted
                  ? 'Showing amounts as ${settings.moneyCurrencySymbol}.'
                  : 'Choose whether saved numbers stay the same or convert.',
            ),
            trailing: TextButton(
              onPressed: () =>
                  showMoneyCurrencyPrompt(context, ref, requireChoice: false),
              child: const Text('Review'),
            ),
          ),
        ],
      ),
    );
  }
}
