import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/controllers/roku_controller.dart';

void main() {
  group('RokuController.identifiesRokuDevice', () {
    test('recognizes Roku-manufactured devices', () {
      const deviceInfo = '''
        <device-info>
          <vendor-name>Roku</vendor-name>
        </device-info>
      ''';

      expect(RokuController.identifiesRokuDevice(deviceInfo), isTrue);
    });

    test('recognizes third-party Roku TVs', () {
      const deviceInfo = '''
        <device-info>
          <vendor-name>TCL</vendor-name>
          <friendly-model-name>TCL•Roku TV</friendly-model-name>
        </device-info>
      ''';

      expect(RokuController.identifiesRokuDevice(deviceInfo), isTrue);
    });

    test('rejects unrelated device info', () {
      const deviceInfo = '''
        <device-info>
          <vendor-name>Example</vendor-name>
          <friendly-model-name>Example Smart TV</friendly-model-name>
        </device-info>
      ''';

      expect(RokuController.identifiesRokuDevice(deviceInfo), isFalse);
    });
  });
}
