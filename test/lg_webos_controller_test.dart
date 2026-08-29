import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/controllers/lg_webos_controller.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_brand.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_status.dart';
import 'package:universal_tv_remote/services/credential_store.dart';

void main() {
  test('launches an LG app whose catalog ID matches a legacy favorite ID',
      () async {
    final requests = <(String, Map<String, dynamic>)>[];
    final controller = LgWebOsController(
      const TvDevice(
        id: 'living-room-lg',
        name: 'Living Room',
        brand: TvBrand.lgWebOs,
        host: '192.0.2.1',
      ),
      CredentialStore.instance,
      requestHandler: (uri, payload) async {
        requests.add((uri, payload));
        if (uri == 'com.webos.applicationManager/listLaunchPoints') {
          return {
            'launchPoints': [
              {'id': 'hulu', 'title': 'Hulu'},
            ],
          };
        }
        return const <String, dynamic>{};
      },
    );

    await controller
        .launchApp(const TvAppInfo(id: 'hulu', title: 'Hulu'))
        .timeout(const Duration(seconds: 1));

    expect(
      requests.map((request) => request.$1),
      [
        'com.webos.applicationManager/listLaunchPoints',
        'system.launcher/launch',
      ],
    );
    expect(requests.last.$2, {'id': 'hulu'});
  });

  test('reports LG power and foreground app status', () async {
    final controller = LgWebOsController(
      const TvDevice(
        id: 'living-room-lg',
        name: 'Living Room',
        brand: TvBrand.lgWebOs,
        host: '192.0.2.1',
      ),
      CredentialStore.instance,
      requestHandler: (uri, payload) async {
        if (uri == 'com.webos.service.tvpower/power/getPowerState') {
          return {'state': 'Active'};
        }
        if (uri == 'com.webos.applicationManager/getForegroundAppInfo') {
          return {'appId': 'hulu', 'appName': 'Hulu'};
        }
        return const <String, dynamic>{};
      },
    );

    final status = await controller.getStatus();

    expect(status.powerState, TvPowerState.on);
    expect(status.currentApp, 'Hulu');
  });
}
