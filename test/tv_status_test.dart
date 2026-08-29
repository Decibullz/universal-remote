import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/controllers/lg_webos_controller.dart';
import 'package:universal_tv_remote/controllers/roku_controller.dart';
import 'package:universal_tv_remote/controllers/vizio_controller.dart';
import 'package:universal_tv_remote/models/tv_status.dart';

void main() {
  group('TV status parsing', () {
    test('reads Roku power and active app', () {
      final status = RokuController.statusFromXml(
        '<device-info><power-mode>PowerOn</power-mode></device-info>',
        '<active-app><app id="12">Netflix</app></active-app>',
      );

      expect(status.powerState, TvPowerState.on);
      expect(status.currentApp, 'Netflix');
    });

    test('does not report a Roku app while the display is off', () {
      final status = RokuController.statusFromXml(
        '<device-info><power-mode>DisplayOff</power-mode></device-info>',
        '<active-app><app id="12">Netflix</app></active-app>',
      );

      expect(status.powerState, TvPowerState.off);
      expect(status.currentApp, isNull);
    });

    test('reads LG power states', () {
      expect(
        LgWebOsController.powerStateFromPayload({'state': 'Active'}),
        TvPowerState.on,
      );
      expect(
        LgWebOsController.powerStateFromPayload({'state': 'Suspend'}),
        TvPowerState.off,
      );
    });

    test('reads Vizio numeric power states', () {
      expect(
        VizioController.powerStateFromResponse({
          'ITEMS': [
            {'VALUE': 1},
          ],
        }),
        TvPowerState.on,
      );
      expect(
        VizioController.powerStateFromResponse({
          'ITEMS': [
            {'VALUE': 0},
          ],
        }),
        TvPowerState.off,
      );
    });
  });
}
