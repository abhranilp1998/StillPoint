import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models.dart';
import '../../services/security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.settings,
    required this.onUnlocked,
  });

  final AppSettings settings;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.settings.biometricLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                            onPressed: _tryPin,
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
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock your private tracker',
        biometricOnly: false,
      );
      if (didAuthenticate) widget.onUnlocked();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Biometric unlock is unavailable.');
      }
    }
  }

  void _tryPin() {
    final expected = widget.settings.pinHash;
    if (expected == null) return;
    if (SecurityService.hashPin(_pinController.text) == expected) {
      widget.onUnlocked();
    } else {
      setState(() => _message = 'That PIN did not match.');
    }
  }
}
