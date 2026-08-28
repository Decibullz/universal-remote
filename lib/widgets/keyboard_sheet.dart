import 'package:flutter/material.dart';
import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';

class KeyboardSheet extends StatefulWidget {
  const KeyboardSheet({
    required this.controller,
    super.key,
  });

  final TvRemoteController controller;

  @override
  State<KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<KeyboardSheet> {
  final _textController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, inset + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Type on TV',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Focus a text box on the TV first, then type here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: true,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _run(_send),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Search, username, title...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : () => _run(_send),
              icon: const Icon(Icons.send),
              label: const Text('Send text'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sending
                        ? null
                        : () => _run(widget.controller.backspace),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Backspace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _sending ? null : () => _run(widget.controller.enter),
                    icon: const Icon(Icons.keyboard_return),
                    label: const Text('Enter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    await widget.controller.sendText(text);
    _textController.clear();
  }
}
