import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/services/wake_on_lan_service.dart';

void main() {
  group('WakeOnLanService', () {
    test('normalizes common MAC address formats', () {
      expect(
        WakeOnLanService.normalizeMac('aa-bb-cc-dd-ee-ff'),
        'AA:BB:CC:DD:EE:FF',
      );
      expect(WakeOnLanService.normalizeMac('not-a-mac'), isNull);
    });

    test('finds unique MAC addresses in nested TV responses', () {
      final addresses = WakeOnLanService.findMacAddresses({
        'wifiInfo': {'macAddress': '20:3d:bd:de:49:12'},
        'wiredInfo': {'macAddress': 'E8-5B-5B-82-6D-3C'},
        'duplicate': '20:3D:BD:DE:49:12',
        'empty': '00:00:00:00:00:00',
      });

      expect(addresses, ['20:3D:BD:DE:49:12', 'E8:5B:5B:82:6D:3C']);
    });

    test('builds the standard 102-byte magic packet', () {
      final packet = WakeOnLanService.magicPacket('01:23:45:67:89:AB');

      expect(packet.length, 102);
      expect(packet.take(6), everyElement(0xff));
      for (var offset = 6; offset < packet.length; offset += 6) {
        expect(
          packet.sublist(offset, offset + 6),
          [0x01, 0x23, 0x45, 0x67, 0x89, 0xab],
        );
      }
    });

    test('derives a broadcast address for the scanned Wi-Fi subnet', () {
      expect(
        WakeOnLanService.directedBroadcastFor('192.168.50.23'),
        '192.168.50.255',
      );
      expect(WakeOnLanService.directedBroadcastFor('tv.local'), isNull);
    });
  });
}
