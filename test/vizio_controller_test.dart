import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/controllers/vizio_controller.dart';

void main() {
  group('VizioController navigation codes', () {
    test('uses the newer port-7345 D-pad codes', () {
      final codes = VizioController.navigationCodesForPort(7345);

      expect(codes.up, 8);
      expect(codes.right, 7);
    });

    test('uses the older port-9000 D-pad codes', () {
      final codes = VizioController.navigationCodesForPort(9000);

      expect(codes.up, 3);
      expect(codes.right, 5);
    });
  });
}
