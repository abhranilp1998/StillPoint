import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../../core/models.dart';
import '../../services/security_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({
    super.key,
    required this.settings,
    required this.onUnlocked,
    this.onPinHashUpgraded,
  });

  final AppSettings settings;
  final VoidCallback onUnlocked;
  final Future<void> Function(String upgradedHash)? onPinHashUpgraded;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();

  String? _message;
  DateTime? _retryAvailableAt;
  Timer? _retryTimer;
  bool _verifyingPin = false;

  @override
  void initState() {
    super.initState();
    _loadRetryState();
    if (widget.settings.biometricLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _tryBiometric();
        });
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinLocked = _isPinLocked;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text('Private space', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock when you are ready.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.settings.pinLock &&
                      widget.settings.pinHash != null) ...[
                    const SizedBox(height: 22),
                    TextField(
                      controller: _pinController,
                      enabled: !pinLocked && !_verifyingPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'PIN',
                      ),
                      onSubmitted: (_) => _tryPin(),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (widget.settings.biometricLock)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tryBiometric,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Biometric'),
                          ),
                        ),
                      if (widget.settings.biometricLock &&
                          widget.settings.pinLock)
                        const SizedBox(width: 10),
                      if (widget.settings.pinLock)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: pinLocked || _verifyingPin
                                ? null
                                : _tryPin,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Unlock'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _tryBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();

      debugPrint(
        '[local_auth] canCheckBiometrics=$canCheck '
        'isDeviceSupported=$isSupported '
        'available=$available',
      );

      if (!isSupported) {
        if (mounted) {
          setState(
            () => _message = 'No screen lock set up on this device.',
          );
        }
        return;
      }

      if (canCheck && available.isEmpty) {
        if (mounted) {
          setState(
            () => _message =
                'No biometrics enrolled. Add a fingerprint in device settings.',
          );
        }
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock your private tracker',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Stillpoint — Private space',
            cancelButton: 'Use PIN instead',
          ),
        ],
      );
      if (didAuthenticate) {
        await ref.read(securityServiceProvider).clearFailedPinAttempts();
        widget.onUnlocked();
      }
    } catch (e, st) {
      debugPrint('[local_auth] Error: $e\n$st');
      if (mounted) {
        setState(() => _message = 'Biometric error: $e');
      }
    }
  }

  Future<void> _tryPin() async {
    final expected = widget.settings.pinHash;
    if (expected == null) return;
    final pin = _pinController.text.trim();
    final security = ref.read(securityServiceProvider);
    if (!security.isPinFormat(pin)) {
      setState(() => _message = 'Use 4-8 digits.');
      return;
    }

    setState(() => _verifyingPin = true);
    final result = await security.verifyPin(pin: pin, expectedHash: expected);
    if (!mounted) return;

    if (result.matches) {
      if (result.upgradedHash != null && widget.onPinHashUpgraded != null) {
        await widget.onPinHashUpgraded!(result.upgradedHash!);
        if (!mounted) return;
      }
      widget.onUnlocked();
      return;
    }

    _pinController.clear();
    final retryAvailableAt = result.retryAvailableAt;
    setState(() {
      _verifyingPin = false;
      _applyRetryState(retryAvailableAt);
      _message = retryAvailableAt == null
          ? 'That PIN did not match.'
          : _lockoutMessage(retryAvailableAt);
    });
  }

  bool get _isPinLocked =>
      _retryAvailableAt != null && _retryAvailableAt!.isAfter(DateTime.now());

  Future<void> _loadRetryState() async {
    final retryAvailableAt = await ref
        .read(securityServiceProvider)
        .currentRetryAvailableAt();
    if (!mounted) return;
    setState(() {
      _applyRetryState(retryAvailableAt);
      if (_isPinLocked) {
        _message = _lockoutMessage(_retryAvailableAt!);
      }
    });
  }

  void _applyRetryState(DateTime? retryAvailableAt) {
    _retryAvailableAt = retryAvailableAt;
    _retryTimer?.cancel();
    if (!_isPinLocked) return;

    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final activeUntil = _retryAvailableAt;
      if (activeUntil == null || !activeUntil.isAfter(DateTime.now())) {
        timer.cancel();
        setState(() {
          _retryAvailableAt = null;
          _message = null;
        });
        return;
      }
      setState(() => _message = _lockoutMessage(activeUntil));
    });
  }

  String _lockoutMessage(DateTime retryAvailableAt) {
    final remaining = retryAvailableAt.difference(DateTime.now()).inSeconds;
    final seconds = remaining <= 0 ? 1 : remaining + 1;
    return 'Wait $seconds second${seconds == 1 ? '' : 's'} before trying again.';
  }
}
