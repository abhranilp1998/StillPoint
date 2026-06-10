import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models.dart';
import '../../services/notification_service.dart';
import '../../services/security_service.dart';
import '../../state/app_controller.dart';
import '../security/pin_setup_dialog.dart';
import '../widgets/adaptive_scaffold.dart';

class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({
    super.key,
    required this.state,
    required this.settings,
    required this.onComplete,
  });

  final AppState state;
  final AppSettings settings;
  final VoidCallback onComplete;

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  late bool _useDeviceLock;
  late bool _wantsReminders;
  String? _pinHash;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _useDeviceLock = widget.settings.biometricLock;
    _pinHash = widget.settings.pinLock ? widget.settings.pinHash : null;
    _wantsReminders = widget.settings.softReminders;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: ScreenPadding(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MotionReveal(child: _PrivacyWelcomeCard()),
                    const SizedBox(height: 14),
                    const MotionReveal(
                      delay: Duration(milliseconds: 55),
                      child: _LocalStorageCard(),
                    ),
                    const SizedBox(height: 12),
                    MotionReveal(
                      delay: const Duration(milliseconds: 110),
                      child: _LockSetupCard(
                        pinEnabled: _pinHash != null,
                        deviceLockEnabled: _useDeviceLock,
                        onPinChanged: _setPinEnabled,
                        onDeviceLockChanged: _setDeviceLockEnabled,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MotionReveal(
                      delay: const Duration(milliseconds: 165),
                      child: _ReminderConsentCard(
                        wantsReminders: _wantsReminders,
                        onChanged: (value) =>
                            setState(() => _wantsReminders = value),
                      ),
                    ),
                    const SizedBox(height: 20),
                    MotionReveal(
                      delay: const Duration(milliseconds: 220),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _finish,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: _saving
                                ? SizedBox.square(
                                    key: const ValueKey('saving'),
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_rounded,
                                    key: ValueKey('ready'),
                                  ),
                          ),
                          label: Text(
                            _saving ? 'Saving choices' : 'Enter StillPoint',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setPinEnabled(bool value) async {
    if (!value) {
      setState(() => _pinHash = null);
      return;
    }

    final pin = await showPinSetupDialog(context);
    if (!mounted || pin == null) return;
    final pinHash = await ref.read(securityServiceProvider).hashPin(pin);
    if (!mounted) return;
    setState(() => _pinHash = pinHash);
  }

  Future<void> _setDeviceLockEnabled(bool value) async {
    if (!value) {
      setState(() => _useDeviceLock = false);
      return;
    }

    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!mounted) return;
      if (!supported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device unlock is unavailable here.')),
        );
        return;
      }
      setState(() => _useDeviceLock = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device unlock is unavailable here.')),
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    var remindersEnabled = false;
    var notificationError = false;
    final notifications = ref.read(notificationServiceProvider);

    try {
      var nextSettings = widget.settings.copyWith(
        privacyConsentCompleted: true,
        offlineMode: true,
        biometricLock: _useDeviceLock,
        pinLock: _pinHash != null,
        pinHash: _pinHash,
        clearPinHash: _pinHash == null,
        hiddenNotifications: true,
        softReminders: false,
      );

      if (_wantsReminders) {
        final granted = await notifications.requestPermissions();
        if (granted) {
          nextSettings = nextSettings.copyWith(softReminders: true);
          final scheduleResult = await notifications
              .scheduleOccasionalReminders(
                settings: nextSettings,
                state: widget.state.copyWith(settings: nextSettings),
              );
          nextSettings = nextSettings.copyWith(
            reminderTimezone: scheduleResult.timezoneName,
          );
          remindersEnabled = true;
        } else {
          notificationError = true;
          await notifications.cancelOccasionalReminders();
        }
      } else {
        await notifications.cancelOccasionalReminders();
      }

      nextSettings = nextSettings.copyWith(softReminders: remindersEnabled);
      await ref
          .read(appControllerProvider.notifier)
          .updateSettings(nextSettings);
      if (!mounted) return;
      if (notificationError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications stayed off. You can turn them on later.',
            ),
          ),
        );
      }
      widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save those choices yet.')),
      );
    }
  }
}

class _PrivacyWelcomeCard extends StatelessWidget {
  const _PrivacyWelcomeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CalmCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer.withValues(alpha: .76),
          scheme.secondaryContainer.withValues(alpha: .46),
          scheme.surfaceContainerHighest.withValues(alpha: .66),
        ],
      ),
      borderColor: scheme.primary.withValues(alpha: .22),
      glowColor: scheme.primary,
      glowIntensity: .24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                Icons.verified_user_outlined,
                color: scheme.primary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Your space stays yours', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'A few private, local-first choices before StillPoint opens.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalStorageCard extends StatelessWidget {
  const _LocalStorageCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: .5),
      glowColor: theme.colorScheme.primary,
      glowIntensity: .08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Local-first storage', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          _ConsentPoint(
            icon: Icons.storage_rounded,
            text:
                'Logs and settings are kept on this device in an encrypted local database.',
          ),
          const SizedBox(height: 8),
          const _ConsentPoint(
            icon: Icons.cloud_off_rounded,
            text: 'There is no cloud account or sync unless you add one later.',
          ),
          const SizedBox(height: 8),
          const _ConsentPoint(
            icon: Icons.notifications_off_rounded,
            text: 'Notifications stay off unless you choose reminders below.',
          ),
        ],
      ),
    );
  }
}

class _LockSetupCard extends StatelessWidget {
  const _LockSetupCard({
    required this.pinEnabled,
    required this.deviceLockEnabled,
    required this.onPinChanged,
    required this.onDeviceLockChanged,
  });

  final bool pinEnabled;
  final bool deviceLockEnabled;
  final ValueChanged<bool> onPinChanged;
  final ValueChanged<bool> onDeviceLockChanged;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Optional app lock'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set a local PIN'),
            subtitle: const Text('A simple fallback for private moments.'),
            value: pinEnabled,
            onChanged: onPinChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use device unlock'),
            subtitle: const Text('Use biometric or device authentication.'),
            value: deviceLockEnabled,
            onChanged: onDeviceLockChanged,
          ),
        ],
      ),
    );
  }
}

class _ReminderConsentCard extends StatelessWidget {
  const _ReminderConsentCard({
    required this.wantsReminders,
    required this.onChanged,
  });

  final bool wantsReminders;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Gentle reminders'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ask for notification permission'),
            subtitle: const Text(
              'Optional check-ins every few days, with hidden content.',
            ),
            value: wantsReminders,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onPrimaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
