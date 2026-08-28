import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';

class FavoriteAppButton extends StatelessWidget {
  const FavoriteAppButton({
    required this.favorite,
    required this.onPressed,
    super.key,
  });

  final TvFavorite favorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (mark, brandColor, markSize) = switch (favorite) {
      TvFavorite.hulu => ('hulu', const Color(0xFF1CE783), 14.0),
      TvFavorite.netflix => ('N', const Color(0xFFE50914), 23.0),
      TvFavorite.crunchyroll => ('◔', const Color(0xFFF47521), 25.0),
      TvFavorite.mlb => ('MLB', const Color(0xFF3382D5), 13.0),
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
                          letterSpacing: favorite == TvFavorite.mlb ? -0.5 : 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    favorite.label,
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
}
