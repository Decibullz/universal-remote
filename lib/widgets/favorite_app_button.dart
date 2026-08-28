import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';

class FavoriteAppButton extends StatelessWidget {
  const FavoriteAppButton({
    required this.app,
    required this.onPressed,
    required this.onLongPress,
    super.key,
  });

  final TvAppInfo app;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = app.title.toLowerCase();
    final (mark, brandColor, markSize) = switch (title) {
      final value when value.contains('hulu') => (
          'hulu',
          const Color(0xFF1CE783),
          14.0,
        ),
      final value when value.contains('netflix') => (
          'N',
          const Color(0xFFE50914),
          23.0,
        ),
      final value when value.contains('crunchyroll') => (
          '◔',
          const Color(0xFFF47521),
          25.0,
        ),
      final value when value == 'mlb' || value.contains('mlb.tv') => (
          'MLB',
          const Color(0xFF3382D5),
          13.0,
        ),
      _ => (_initials(app.title), colors.primary, 17.0),
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.48 : 1,
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          onLongPress: onLongPress,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 25,
                    child: Center(
                      child: Text(
                        mark,
                        style: TextStyle(
                          color: brandColor,
                          fontSize: markSize,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: mark == 'MLB' ? -0.5 : 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    app.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'TV';
    }
    if (words.length == 1) {
      return words.first.characters.take(2).join().toUpperCase();
    }
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
}
