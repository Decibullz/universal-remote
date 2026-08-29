import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/models/discovered_tv.dart';
import 'package:universal_tv_remote/models/tv_brand.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/screens/add_device_screen.dart';
import 'package:universal_tv_remote/services/discovery_service.dart';

void main() {
  testWidgets('locks the add-TV screen until Wi-Fi scanning completes', (
    WidgetTester tester,
  ) async {
    final discovery = _ControlledDiscoveryService();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AddDeviceScreen(discovery: discovery),
                  ),
                ),
                child: const Text('Open add TV'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open add TV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Wi-Fi'));
    await tester.pump();

    expect(find.byKey(const Key('tv-scan-progress')), findsOneWidget);
    expect(find.text('Scanning Wi-Fi'), findsOneWidget);
    expect(find.text('Checking 12 of 253 addresses'), findsOneWidget);
    expect(find.text('LG webOS').hitTestable(), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AddDeviceScreen), findsOneWidget);

    discovery.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tv-scan-progress')), findsNothing);
    expect(find.text('LG webOS').hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddDeviceScreen), findsNothing);
  });

  testWidgets('adds multiple discovered TVs from one scan', (
    WidgetTester tester,
  ) async {
    const existing = TvDevice(
      id: 'saved-roku',
      name: 'Bedroom',
      brand: TvBrand.roku,
      host: '192.168.1.20',
    );
    final paired = <TvDevice>[];
    AddDevicesResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<AddDevicesResult>(
                    MaterialPageRoute(
                      builder: (_) => AddDeviceScreen(
                        discovery: const _MultipleTvDiscoveryService(),
                        existingDevices: const [existing],
                        pairDevice: (device) async => paired.add(device),
                      ),
                    ),
                  );
                },
                child: const Text('Open add TV'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open add TV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Wi-Fi'));
    await tester.pumpAndSettle();

    expect(find.text('Add 2 selected TVs'), findsOneWidget);
    expect(find.textContaining('Already added'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-selected-tvs')));
    await tester.pumpAndSettle();

    expect(paired.map((device) => device.host), [
      '192.168.1.30',
      '192.168.1.40',
    ]);
    expect(result?.devices.length, 2);
    expect(find.byType(AddDeviceScreen), findsNothing);
  });
}

class _ControlledDiscoveryService extends DiscoveryService {
  final _result = Completer<List<DiscoveredTv>>();

  @override
  Future<List<DiscoveredTv>> scan({
    void Function(int checked, int total)? onProgress,
  }) {
    onProgress?.call(12, 253);
    return _result.future;
  }

  void complete() => _result.complete(const []);
}

class _MultipleTvDiscoveryService extends DiscoveryService {
  const _MultipleTvDiscoveryService();

  @override
  Future<List<DiscoveredTv>> scan({
    void Function(int checked, int total)? onProgress,
  }) async {
    onProgress?.call(253, 253);
    return const [
      DiscoveredTv(
        host: '192.168.1.20',
        brand: TvBrand.roku,
        suggestedName: 'Bedroom',
      ),
      DiscoveredTv(
        host: '192.168.1.30',
        brand: TvBrand.lgWebOs,
        suggestedName: 'Living Room',
      ),
      DiscoveredTv(
        host: '192.168.1.40',
        brand: TvBrand.vizio,
        suggestedName: 'Basement',
        port: 7345,
      ),
    ];
  }
}
