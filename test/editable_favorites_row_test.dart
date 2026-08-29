import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/widgets/editable_favorites_row.dart';

void main() {
  const favorites = [
    TvAppInfo(id: 'netflix', title: 'Netflix'),
    TvAppInfo(id: 'hulu', title: 'Hulu'),
    TvAppInfo(id: 'plex', title: 'Plex'),
    TvAppInfo(id: 'youtube', title: 'YouTube'),
  ];

  testWidgets('removes a favorite from the home-screen editor', (
    WidgetTester tester,
  ) async {
    List<TvAppInfo>? updated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableFavoritesRow(
            favorites: favorites,
            onChanged: (value) => updated = value,
          ),
        ),
      ),
    );

    expect(
      tester
          .getRect(find.byKey(const ValueKey('editable-favorite-youtube')))
          .right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('editable-favorites-row'))).right,
      ),
    );

    await tester.tap(find.byKey(const Key('remove-favorite-hulu')));
    await tester.pump();

    expect(updated, isNotNull);
    expect(updated!.map((app) => app.id), [
      'netflix',
      'plex',
      'youtube',
    ]);
  });

  testWidgets('reports the new order after a drag reorder', (
    WidgetTester tester,
  ) async {
    List<TvAppInfo>? updated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableFavoritesRow(
            favorites: favorites,
            onChanged: (value) => updated = value,
          ),
        ),
      ),
    );

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 3);

    expect(updated, isNotNull);
    expect(updated!.map((app) => app.id), [
      'hulu',
      'plex',
      'youtube',
      'netflix',
    ]);
  });
}
