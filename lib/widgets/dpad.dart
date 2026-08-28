import 'package:flutter/material.dart';

class Dpad extends StatelessWidget {
  const Dpad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onSelect,
    super.key,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    const size = 70.0;

    Widget button(IconData icon, VoidCallback onPressed, {String? label}) {
      return SizedBox(
        width: size,
        height: size,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: label == null
              ? Icon(icon, size: 32)
              : Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
        ),
      );
    }

    return SizedBox(
      width: size * 3,
      child: Column(
        children: [
          button(Icons.keyboard_arrow_up, onUp),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              button(Icons.keyboard_arrow_left, onLeft),
              button(Icons.circle, onSelect, label: 'OK'),
              button(Icons.keyboard_arrow_right, onRight),
            ],
          ),
          button(Icons.keyboard_arrow_down, onDown),
        ],
      ),
    );
  }
}
