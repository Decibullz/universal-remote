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

    final dpadBounds = tester.getRect(
      find.byKey(const Key('remote-dpad')),
    );
    final bottomControlsBounds = tester.getRect(
      find.byKey(const Key('remote-bottom-controls')),
    );

    expect(dpadBounds.center.dx, closeTo(195, 0.1));
    expect(dpadBounds.center.dy, closeTo(422, 0.1));
    expect(bottomControlsBounds.bottom, closeTo(840, 0.1));
    expect(tester.takeException(), isNull);
  });
}
