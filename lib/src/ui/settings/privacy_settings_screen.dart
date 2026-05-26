import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models.dart';
import '../../services/notification_service.dart';
import '../../services/security_service.dart';
import '../../state/app_controller.dart';
import '../widgets/adaptive_scaffold.dart';

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

    final pin = await _askForPin(context);
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

  Future<String?> _askForPin(BuildContext context) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '4-8 digits',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (!SecurityService.isPinFormat(pin)) {
                  setDialogState(() => error = 'Use 4-8 digits.');
                  return;
                }
                Navigator.pop(context, pin);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onChanged: (value) async {
              final next = settings.copyWith(softReminders: value);
              if (value) {
                await ref
                    .read(notificationServiceProvider)
                    .requestPermissions();
                await ref
                    .read(notificationServiceProvider)
                    .scheduleOccasionalReminders(
                      hiddenContent: next.hiddenNotifications,
                    );
              } else {
                await ref
                    .read(notificationServiceProvider)
                    .cancelOccasionalReminders();
              }
              await ref
                  .read(appControllerProvider.notifier)
                  .updateSettings(next);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hidden content'),
            subtitle: const Text(
              'Sensitive details stay out of notifications.',
            ),
            value: settings.hiddenNotifications,
            onChanged: (value) async {
              final next = settings.copyWith(hiddenNotifications: value);
              if (next.softReminders) {
                await ref
                    .read(notificationServiceProvider)
                    .scheduleOccasionalReminders(hiddenContent: value);
              }
              await ref
                  .read(appControllerProvider.notifier)
                  .updateSettings(next);
            },
          ),
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
        ],
      ),
    );
  }
}
