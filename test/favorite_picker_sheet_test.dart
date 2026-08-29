import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/widgets/favorite_picker_sheet.dart';

void main() {
  testWidgets('replaces one of four favorite apps', (
    WidgetTester tester,
  ) async {
    const apps = [
      TvAppInfo(id: '1', title: 'Netflix'),
      TvAppInfo(id: '2', title: 'Hulu'),
      TvAppInfo(id: '3', title: 'Plex'),
      TvAppInfo(id: '4', title: 'YouTube'),
      TvAppInfo(id: '5', title: 'Spotify'),
    ];
    List<TvAppInfo>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<List<TvAppInfo>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FavoritePickerSheet(
                    deviceName: 'Living Room',
                    initialFavorites: apps.take(4).toList(),
                    loadApps: () async => apps,
                  ),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);

    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.tap(find.text('Spotify'));
    await tester.pump();
    await tester.tap(find.text('Save favorites'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, hasLength(4));
    expect(result!.map((app) => app.title), contains('Spotify'));
    expect(result!.map((app) => app.title), isNot(contains('Netflix')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps currently selected apps at the top', (
    WidgetTester tester,
  ) async {
    const apps = [
      TvAppInfo(id: '1', title: 'Netflix'),
      TvAppInfo(id: '2', title: 'Hulu'),
      TvAppInfo(id: '3', title: 'Plex'),
      TvAppInfo(id: '4', title: 'YouTube'),
      TvAppInfo(id: '5', title: 'Spotify'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showModalBottomSheet<List<TvAppInfo>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FavoritePickerSheet(
                    deviceName: 'Living Room',
                    initialFavorites: [apps[4], apps[2]],
                    loadApps: () async => apps,
                  ),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final spotifyTop = tester.getTopLeft(find.text('Spotify')).dy;
    final plexTop = tester.getTopLeft(find.text('Plex')).dy;
    final huluTop = tester.getTopLeft(find.text('Hulu')).dy;
    expect(spotifyTop, lessThan(plexTop));
    expect(plexTop, lessThan(huluTop));

    await tester.tap(find.text('Hulu'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Hulu')).dy,
      lessThan(tester.getTopLeft(find.text('Netflix')).dy),
    );
  });
}
