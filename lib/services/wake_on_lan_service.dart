import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class WakeOnLanService {
  const WakeOnLanService();

  static final RegExp _macPattern = RegExp(
    r'(?<![0-9A-Fa-f])(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f])',
  );

  static String? normalizeMac(String value) {
    final compact = value.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (compact.length != 12) {
      return null;
    }
    return [
      for (var index = 0; index < compact.length; index += 2)
        compact.substring(index, index + 2).toUpperCase(),
    ].join(':');
  }

  static List<String> findMacAddresses(Object? value) {
    final addresses = <String>{};

    void visit(Object? current) {
      if (current is Map) {
        for (final entry in current.entries) {
          visit(entry.key);
          visit(entry.value);
        }
        return;
      }
      if (current is Iterable) {
        for (final item in current) {
          visit(item);
        }
        return;
      }
      if (current is! String) {
        return;
      }
      for (final match in _macPattern.allMatches(current)) {
        final normalized = normalizeMac(match.group(0)!);
        if (normalized != null && normalized != '00:00:00:00:00:00') {
          addresses.add(normalized);
        }
      }
    }

    visit(value);
    return List.unmodifiable(addresses);
  }

  static Uint8List magicPacket(String macAddress) {
    final normalized = normalizeMac(macAddress);
    if (normalized == null) {
      throw const FormatException('Invalid MAC address.');
    }

    final macBytes = normalized
        .split(':')
        .map((part) => int.parse(part, radix: 16))
        .toList(growable: false);
    return Uint8List.fromList([
      ...List<int>.filled(6, 0xff),
      for (var repeat = 0; repeat < 16; repeat++) ...macBytes,
    ]);
  }

  static String? directedBroadcastFor(String host) {
    final parts = host.split('.');
    if (parts.length != 4 ||
        parts.any((part) {
          final number = int.tryParse(part);
          return number == null || number < 0 || number > 255;
        })) {
      return null;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  Future<void> wake(
    Iterable<String> macAddresses, {
    String? targetHost,
  }) async {
    final addresses = macAddresses
        .map(normalizeMac)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (addresses.isEmpty) {
      throw const FormatException('No valid wake address is available.');
    }

    final targets = <String>{'255.255.255.255'};
    final directed =
        targetHost == null ? null : directedBroadcastFor(targetHost);
    if (directed != null) {
      targets.add(directed);
    }

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    socket.broadcastEnabled = true;
    try {
      for (var repeat = 0; repeat < 3; repeat++) {
        for (final macAddress in addresses) {
          final packet = magicPacket(macAddress);
          for (final target in targets) {
            final destination = InternetAddress(target);
            socket.send(packet, destination, 9);
            socket.send(packet, destination, 7);
          }
        }
        if (repeat < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    } finally {
      socket.close();
    }
  }
}
