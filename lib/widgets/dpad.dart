import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Dpad extends StatelessWidget {
  const Dpad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onSelect,
    super.key,
  });

  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    const size = 236.0;
    final colors = Theme.of(context).colorScheme;
    final enabled = onUp != null ||
        onDown != null ||
        onLeft != null ||
        onRight != null ||
        onSelect != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.48,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: const GradientRotation(math.pi / 4),
              colors: [
                colors.surfaceContainerHigh,
                colors.surfaceContainerLowest,
                colors.surfaceContainerHigh,
                colors.surfaceContainerLowest,
                colors.surfaceContainerHigh,
              ],
            ),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.04),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _DpadDividerPainter(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 78,
                    top: 4,
                    child: _DirectionControl(
                      icon: Icons.keyboard_arrow_up_rounded,
                      label: 'Up',
                      onPressed: onUp,
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 83,
                    child: _DirectionControl(
                      icon: Icons.keyboard_arrow_right_rounded,
                      label: 'Right',
                      onPressed: onRight,
                    ),
                  ),
                  Positioned(
                    left: 78,
                    bottom: 4,
                    child: _DirectionControl(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: 'Down',
                      onPressed: onDown,
                    ),
                  ),
                  Positioned(
                    left: 3,
                    top: 83,
                    child: _DirectionControl(
                      icon: Icons.keyboard_arrow_left_rounded,
                      label: 'Left',
                      onPressed: onLeft,
                    ),
                  ),
                  Center(child: _SelectControl(onPressed: onSelect)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionControl extends StatelessWidget {
  const _DirectionControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: SizedBox(
        width: 80,
        height: 70,
        child: InkResponse(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          radius: 42,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          child: Icon(
            icon,
            size: 36,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SelectControl extends StatelessWidget {
  const _SelectControl({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'OK',
      child: Material(
        color: colors.surfaceContainerLowest,
        elevation: 5,
        shadowColor: colors.shadow.withValues(alpha: 0.28),
        shape: CircleBorder(
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onPressed!();
                },
          child: const SizedBox.square(
            dimension: 90,
            child: Center(
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DpadDividerPainter extends CustomPainter {
  const _DpadDividerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const innerRadius = 54.0;
    const outerRadius = 104.0;
    for (final angle in const [
      math.pi / 4,
      3 * math.pi / 4,
      5 * math.pi / 4,
      7 * math.pi / 4,
    ]) {
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * innerRadius,
        center + Offset(math.cos(angle), math.sin(angle)) * outerRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DpadDividerPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
