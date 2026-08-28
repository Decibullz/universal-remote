import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/services/discovery_service.dart';

void main() {
  group('DiscoveryService.identifiesLgHello', () {
    test('recognizes a compact webOS hello response', () {
      expect(
        DiscoveryService.identifiesLgHello(
          '{"id":"hello","type":"hello","payload":{}}',
        ),
        isTrue,
      );
    });

    test('recognizes a response containing JSON whitespace', () {
      expect(
        DiscoveryService.identifiesLgHello(
          '{ "type": "hello", "payload": { "deviceName": "webOS TV" } }',
        ),
        isTrue,
      );
    });

    test('rejects non-LG and malformed responses', () {
      expect(
        DiscoveryService.identifiesLgHello('{"type":"response"}'),
        isFalse,
      );
      expect(DiscoveryService.identifiesLgHello('not json'), isFalse);
      expect(DiscoveryService.identifiesLgHello(<int>[1, 2, 3]), isFalse);
    });
  });
}
