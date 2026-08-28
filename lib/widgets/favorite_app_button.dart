import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:simple_icons/simple_icons.dart';
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
                    width: 54,
                    height: 25,
                    child: StreamingServiceLogo(
                      app: app,
                      fallbackColor: colors.primary,
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
}

class StreamingServiceLogo extends StatelessWidget {
  const StreamingServiceLogo({
    required this.app,
    required this.fallbackColor,
    super.key,
  });

  final TvAppInfo app;
  final Color fallbackColor;

  static String? brandIdFor(TvAppInfo app) => _resolve(app)?.id;

  @override
  Widget build(BuildContext context) {
    final logo = _resolve(app);
    final fallback = _buildFallback(logo);
    final iconUri = Uri.tryParse(app.iconUrl ?? '');
    final canLoadTvIcon = iconUri != null &&
        (iconUri.scheme == 'http' || iconUri.scheme == 'https');

    if (!canLoadTvIcon) {
      return fallback;
    }

    return Image.network(
      iconUri.toString(),
      key: Key('favorite-logo-network-${logo?.id ?? 'app'}'),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : fallback;
      },
    );
  }

  Widget _buildFallback(_ServiceLogo? logo) {
    if (logo?.asset != null) {
      final artwork = SvgPicture.asset(
        logo!.asset!,
        key: Key('favorite-logo-${logo.id}'),
        fit: BoxFit.contain,
      );

      if (!logo.lightBackground) {
        return artwork;
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: artwork,
        ),
      );
    }

    if (logo?.icon != null) {
      return Icon(
        logo!.icon,
        key: Key('favorite-logo-${logo.id}'),
        size: 24,
        color: logo.color ?? fallbackColor,
      );
    }

    return Center(
      child: Text(
        _initials(app.title),
        key: const Key('favorite-logo-generic'),
        style: TextStyle(
          color: fallbackColor,
          fontSize: 17,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  static _ServiceLogo? _resolve(TvAppInfo app) {
    final title = _compact(app.title);
    final searchable = _compact('${app.title} ${app.id}');

    for (final logo in _serviceLogos) {
      if (logo.exactTitles.contains(title) ||
          logo.aliases.any(searchable.contains)) {
        return logo;
      }
    }

    return null;
  }

  static String _compact(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp('[^a-z0-9]'), '');

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

class _ServiceLogo {
  const _ServiceLogo({
    required this.id,
    required this.aliases,
    this.exactTitles = const [],
    this.asset,
    this.icon,
    this.color,
    this.lightBackground = false,
  });

  final String id;
  final List<String> aliases;
  final List<String> exactTitles;
  final String? asset;
  final IconData? icon;
  final Color? color;
  final bool lightBackground;
}

const _serviceLogos = [
  _ServiceLogo(
    id: 'youtube-tv',
    aliases: ['youtubetv'],
    icon: SimpleIcons.youtubetv,
    color: Color(0xFFFF0000),
  ),
  _ServiceLogo(
    id: 'netflix',
    aliases: ['netflix'],
    icon: SimpleIcons.netflix,
    color: Color(0xFFE50914),
  ),
  _ServiceLogo(
    id: 'hulu',
    aliases: ['hulu'],
    asset: 'assets/logos/hulu.svg',
  ),
  _ServiceLogo(
    id: 'disney-plus',
    aliases: ['disneyplus', 'disney'],
    asset: 'assets/logos/disney.svg',
  ),
  _ServiceLogo(
    id: 'prime-video',
    aliases: ['primevideo', 'amazonprimevideo', 'amazonvideo'],
    asset: 'assets/logos/prime-video.svg',
  ),
  _ServiceLogo(
    id: 'peacock',
    aliases: ['peacocktv', 'peacock'],
    asset: 'assets/logos/peacock.svg',
    lightBackground: true,
  ),
  _ServiceLogo(
    id: 'pluto-tv',
    aliases: ['plutotv', 'pluto'],
    asset: 'assets/logos/pluto-tv.svg',
  ),
  _ServiceLogo(
    id: 'sling-tv',
    aliases: ['slingtv', 'sling'],
    asset: 'assets/logos/sling-tv.svg',
  ),
  _ServiceLogo(
    id: 'espn-plus',
    aliases: ['espnplus'],
    exactTitles: ['espn'],
    asset: 'assets/logos/espn-plus.svg',
    lightBackground: true,
  ),
  _ServiceLogo(
    id: 'max',
    aliases: ['hbomax', 'hbonow', 'maxstreaming'],
    exactTitles: ['max', 'hbo'],
    icon: SimpleIcons.max,
    color: Color(0xFF3953FF),
  ),
  _ServiceLogo(
    id: 'apple-tv-plus',
    aliases: ['appletv'],
    exactTitles: ['tvplus'],
    icon: SimpleIcons.appletv,
  ),
  _ServiceLogo(
    id: 'paramount-plus',
    aliases: ['paramountplus', 'paramount'],
    icon: SimpleIcons.paramountplus,
    color: Color(0xFF0064FF),
  ),
  _ServiceLogo(
    id: 'youtube',
    aliases: ['youtube'],
    icon: SimpleIcons.youtube,
    color: Color(0xFFFF0000),
  ),
  _ServiceLogo(
    id: 'crunchyroll',
    aliases: ['crunchyroll'],
    icon: SimpleIcons.crunchyroll,
    color: Color(0xFFFF5E00),
  ),
  _ServiceLogo(
    id: 'fubo',
    aliases: ['fubotv', 'fubo'],
    icon: SimpleIcons.fubo,
    color: Color(0xFFFF4B00),
  ),
  _ServiceLogo(
    id: 'tubi',
    aliases: ['tubitv', 'tubi'],
    icon: SimpleIcons.tubi,
    color: Color(0xFF7408FF),
  ),
  _ServiceLogo(
    id: 'roku-channel',
    aliases: ['therokuchannel', 'rokuchannel'],
    icon: SimpleIcons.roku,
    color: Color(0xFF662D91),
  ),
  _ServiceLogo(
    id: 'plex',
    aliases: ['plex'],
    icon: SimpleIcons.plex,
    color: Color(0xFFEBB000),
  ),
  _ServiceLogo(
    id: 'fandango-at-home',
    aliases: ['fandangoathome', 'vudu'],
    icon: SimpleIcons.fandango,
    color: Color(0xFFFF7900),
  ),
  _ServiceLogo(
    id: 'mubi',
    aliases: ['mubi'],
    icon: SimpleIcons.mubi,
  ),
  _ServiceLogo(
    id: 'spotify',
    aliases: ['spotify'],
    icon: SimpleIcons.spotify,
    color: Color(0xFF1ED760),
  ),
  _ServiceLogo(
    id: 'mlb',
    aliases: ['mlbtv'],
    exactTitles: ['mlb'],
    icon: SimpleIcons.mlb,
    color: Color(0xFF3382D5),
  ),
  _ServiceLogo(
    id: 'dazn',
    aliases: ['dazn'],
    icon: SimpleIcons.dazn,
  ),
  _ServiceLogo(
    id: 'starz',
    aliases: ['starz'],
    icon: SimpleIcons.starz,
    color: Color(0xFF00BCEB),
  ),
  _ServiceLogo(
    id: 'showtime',
    aliases: ['showtime'],
    icon: SimpleIcons.showtime,
    color: Color(0xFFFF1B2D),
  ),
  _ServiceLogo(
    id: 'nba',
    aliases: ['nbaleaguepass'],
    exactTitles: ['nba'],
    icon: SimpleIcons.nba,
    color: Color(0xFF1D428A),
  ),
  _ServiceLogo(
    id: 'nhl',
    aliases: ['nhltv'],
    exactTitles: ['nhl'],
    icon: SimpleIcons.nhl,
  ),
];
