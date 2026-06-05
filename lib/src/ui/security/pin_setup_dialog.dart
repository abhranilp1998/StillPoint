import 'package:flutter/material.dart';

import '../../services/security_service.dart';

Future<String?> showPinSetupDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _PinSetupDialog(),
  );
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN'),
      content: TextField(
        controller: _controller,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final pin = _controller.text.trim();
            if (!SecurityService.isPinFormat(pin)) {
              setState(() => error = 'Use 4-8 digits.');
              return;
            }
            Navigator.pop(context, pin);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
