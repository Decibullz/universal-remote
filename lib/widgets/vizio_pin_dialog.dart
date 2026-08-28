import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showVizioPinDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const VizioPinDialog(),
  );
}

class VizioPinDialog extends StatefulWidget {
  const VizioPinDialog({super.key});

  @override
  State<VizioPinDialog> createState() => _VizioPinDialogState();
}

class _VizioPinDialogState extends State<VizioPinDialog> {
  String _pin = '';

  void _submit([String? submittedValue]) {
    final value = (submittedValue ?? _pin).trim();
    if (value.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Vizio PIN'),
      content: TextField(
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 8,
        decoration: const InputDecoration(
          labelText: 'PIN shown on TV',
        ),
        onChanged: (value) {
          setState(() => _pin = value.trim());
        },
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _pin.isEmpty ? null : _submit,
          child: const Text('Pair'),
        ),
      ],
    );
  }
}
