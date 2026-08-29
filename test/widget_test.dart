import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Key;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_tv_remote/app.dart';

void main() {
  testWidgets('shows the empty remote state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const UniversalTvRemoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Tv Remote'), findsOneWidget);
    expect(find.text('No TVs yet'), findsOneWidget);
    expect(find.text('Add TV'), findsOneWidget);
  });

  testWidgets('lays out the remote controls on an iPhone-sized screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'tv_remote.devices': '[{"id":"living-room","name":"Living Room","brand":"roku",'
          '"host":"127.0.0.1","port":8060,"model":"Test TV"}]',
      'tv_remote.selected_device': 'living-room',
    });

    await tester.pumpWidget(const UniversalTvRemoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Keyboard'), findsOneWidget);
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Play / Pause'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.byKey(const Key('tv-status-panel')), findsOneWidget);
    expect(find.byKey(const Key('tv-power-status')), findsOneWidget);
    expect(find.byKey(const Key('tv-current-app')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('tv-status-panel'))).height,
      greaterThan(0),
    );

    final dpadWidths = <double>[];
    for (final viewport in const [
      Size(375, 667),
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pump();

      final topBounds = tester.getRect(
        find.byKey(const Key('remote-top-controls')),
      );
      final dpadBounds = tester.getRect(
        find.byKey(const Key('remote-dpad')),
      );
      final bottomBounds = tester.getRect(
        find.byKey(const Key('remote-bottom-controls')),
      );

      expect(topBounds.bottom, lessThanOrEqualTo(dpadBounds.top));
      expect(dpadBounds.bottom, lessThanOrEqualTo(bottomBounds.top));
      expect(dpadBounds.center.dx, closeTo(viewport.width / 2, 0.1));
      expect(bottomBounds.bottom, lessThan(viewport.height));
      dpadWidths.add(dpadBounds.width);
    }

    expect(dpadWidths.first, lessThan(dpadWidths[1]));
    expect(dpadWidths[1], lessThan(dpadWidths[2]));
    expect(dpadWidths[2], lessThan(dpadWidths.last));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press edits and removes a favorite on the remote', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'tv_remote.devices': '[{"id":"living-room","name":"Living Room","brand":"roku",'
          '"host":"127.0.0.1","port":8060,"model":"Test TV"}]',
      'tv_remote.selected_device': 'living-room',
    });

    await tester.pumpWidget(const UniversalTvRemoteApp());
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('favorite-app-netflix')),
    );
    await tester.pump();

    expect(find.byKey(const Key('editable-favorites-row')), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(
      find.byKey(const Key('remove-favorite-netflix')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('remove-favorite-netflix')));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.byKey(const Key('editable-favorites-row')), findsNothing);
    expect(find.byKey(const Key('favorite-app-netflix')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
