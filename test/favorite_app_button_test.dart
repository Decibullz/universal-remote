import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/widgets/favorite_app_button.dart';

void main() {
  test('recognizes major streaming-service names and aliases', () {
    const expectedBrands = {
      'Netflix': 'netflix',
      'Hulu': 'hulu',
      'Disney Plus': 'disney-plus',
      'Prime Video': 'prime-video',
      'Peacock': 'peacock',
      'Pluto TV': 'pluto-tv',
      'Sling TV': 'sling-tv',
      'ESPN+': 'espn-plus',
      'HBO Max': 'max',
      'Apple TV+': 'apple-tv-plus',
      'Paramount Plus': 'paramount-plus',
      'YouTube TV': 'youtube-tv',
      'YouTube': 'youtube',
      'Crunchyroll': 'crunchyroll',
      'FuboTV': 'fubo',
      'Tubi': 'tubi',
      'The Roku Channel': 'roku-channel',
      'Plex': 'plex',
      'Fandango at Home': 'fandango-at-home',
      'Vudu': 'fandango-at-home',
      'MUBI': 'mubi',
      'Spotify': 'spotify',
      'MLB.TV': 'mlb',
      'DAZN': 'dazn',
      'STARZ': 'starz',
      'SHOWTIME': 'showtime',
      'NBA League Pass': 'nba',
      'NHL.TV': 'nhl',
    };

    for (final entry in expectedBrands.entries) {
      final app = TvAppInfo(id: entry.key, title: entry.key);
      expect(
        StreamingServiceLogo.brandIdFor(app),
        entry.value,
        reason: 'Expected a real logo mapping for ${entry.key}',
      );
    }
  });

  testWidgets('renders SVG artwork instead of a text mark when available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 64,
            child: FavoriteAppButton(
              app: TvAppInfo(id: 'hulu', title: 'Hulu'),
              onPressed: null,
              onLongPress: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byKey(const Key('favorite-logo-hulu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all bundled service SVGs render successfully', (
    WidgetTester tester,
  ) async {
    const bundledApps = [
      TvAppInfo(id: 'hulu', title: 'Hulu'),
      TvAppInfo(id: 'disney', title: 'Disney Plus'),
      TvAppInfo(id: 'prime', title: 'Prime Video'),
      TvAppInfo(id: 'peacock', title: 'Peacock'),
      TvAppInfo(id: 'pluto', title: 'Pluto TV'),
      TvAppInfo(id: 'sling', title: 'Sling TV'),
      TvAppInfo(id: 'espn', title: 'ESPN+'),
    ];

    for (final app in bundledApps) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 64,
              child: StreamingServiceLogo(
                app: app,
                fallbackColor: Colors.indigo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget, reason: app.title);
      expect(tester.takeException(), isNull, reason: app.title);
    }
  });

  testWidgets('keeps initials as the unknown-app fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingServiceLogo(
            app: TvAppInfo(id: 'unknown', title: 'Local Cinema'),
            fallbackColor: Colors.indigo,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('favorite-logo-generic')), findsOneWidget);
    expect(find.text('LC'), findsOneWidget);
  });
}
