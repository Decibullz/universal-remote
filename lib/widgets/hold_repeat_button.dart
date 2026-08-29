import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoldRepeatButton extends StatefulWidget {
  const HoldRepeatButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
    this.initialRepeatDelay = const Duration(milliseconds: 360),
    this.repeatInterval = const Duration(milliseconds: 125),
  });

  final String semanticsLabel;
  final Future<void> Function()? onPressed;
  final Widget child;
  final Duration initialRepeatDelay;
  final Duration repeatInterval;

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _repeatTimer;
  bool _commandInFlight = false;
  bool _held = false;

  @override
  void didUpdateWidget(HoldRepeatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) {
      _stopRepeating();
    }
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  void _startRepeating() {
    if (widget.onPressed == null || _held) {
      return;
    }
    _held = true;
    HapticFeedback.selectionClick();
    unawaited(_invoke());
    _repeatTimer = Timer(widget.initialRepeatDelay, () {
      if (!_held) {
        return;
      }
      unawaited(_invoke());
      _repeatTimer = Timer.periodic(
        widget.repeatInterval,
        (_) => unawaited(_invoke()),
      );
    });
  }

  void _stopRepeating() {
    _held = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  Future<void> _invoke() async {
    final action = widget.onPressed;
    if (action == null || _commandInFlight) {
      return;
    }
    _commandInFlight = true;
    try {
      await action();
    } finally {
      _commandInFlight = false;
    }
  }

  Future<void> _activateOnce() async {
    HapticFeedback.selectionClick();
    await _invoke();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel,
      onTap: enabled ? _activateOnce : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () {} : null,
        onTapDown: enabled ? (_) => _startRepeating() : null,
        onTapUp: enabled ? (_) => _stopRepeating() : null,
        onTapCancel: enabled ? _stopRepeating : null,
        child: widget.child,
      ),
    );
  }
}
