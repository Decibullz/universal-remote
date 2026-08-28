import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/services/discovery_service.dart';

void main() {
  group('DiscoveryService.selectPreferredPrivateIpv4', () {
    test('prefers iPhone Wi-Fi over cellular and VPN addresses', () {
      final selected = DiscoveryService.selectPreferredPrivateIpv4([
        (interfaceName: 'pdp_ip0', address: '10.20.30.40'),
        (interfaceName: 'utun2', address: '10.8.0.2'),
        (interfaceName: 'en0', address: '192.168.1.23'),
      ]);

      expect(selected, '192.168.1.23');
    });

    test('supports common Wi-Fi names and non-192.168 networks', () {
      final selected = DiscoveryService.selectPreferredPrivateIpv4([
        (interfaceName: 'ethernet0', address: '192.168.50.3'),
        (interfaceName: 'wlan0', address: '10.0.0.14'),
      ]);

      expect(selected, '10.0.0.14');
    });

    test('falls back to an unfamiliar private LAN interface', () {
      final selected = DiscoveryService.selectPreferredPrivateIpv4([
        (interfaceName: 'mystery0', address: '10.0.0.15'),
        (interfaceName: 'ethernet0', address: '192.168.1.30'),
      ]);

      expect(selected, '192.168.1.30');
    });

    test('rejects public and malformed addresses', () {
      final selected = DiscoveryService.selectPreferredPrivateIpv4([
        (interfaceName: 'en0', address: '8.8.8.8'),
        (interfaceName: 'en1', address: 'not-an-ip'),
      ]);

      expect(selected, isNull);
    });
  });

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
