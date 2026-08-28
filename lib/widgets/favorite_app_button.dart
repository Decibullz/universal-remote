import 'package:flutter/material.dart';
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
    final icon = switch (favorite) {
      TvFavorite.hulu => Icons.live_tv,
      TvFavorite.netflix => Icons.movie_outlined,
      TvFavorite.crunchyroll => Icons.animation,
      TvFavorite.mlb => Icons.sports_baseball,
    };

    return SizedBox(
      width: 86,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              favorite.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
