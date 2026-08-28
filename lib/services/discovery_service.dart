import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:universal_tv_remote/controllers/roku_controller.dart';
import 'package:universal_tv_remote/models/discovered_tv.dart';
import 'package:universal_tv_remote/models/tv_brand.dart';
import 'package:universal_tv_remote/services/io_http.dart';

class DiscoveryService {
  const DiscoveryService();

  Future<List<DiscoveredTv>> scan({
    void Function(int checked, int total)? onProgress,
  }) async {
    final localIp = await _findPrivateIpv4();
    if (localIp == null) {
      throw StateError(
        'Could not determine this phone\'s local Wi-Fi IPv4 address.',
      );
    }

    final octets = localIp.split('.');
    if (octets.length != 4) {
      throw StateError('Unsupported local IPv4 address: $localIp');
    }

    // Intentionally scan the current /24 using unicast connections rather
    // than SSDP multicast. This works on a physical iPhone without Apple's
    // restricted multicast-networking entitlement.
    final prefix = '${octets[0]}.${octets[1]}.${octets[2]}.';
    final hosts = [
      for (var last = 1; last <= 254; last++) '$prefix$last',
    ]..remove(localIp);

    final found = <DiscoveredTv>[];
    var checked = 0;
    const batchSize = 24;

    for (var start = 0; start < hosts.length; start += batchSize) {
      final end =
          start + batchSize < hosts.length ? start + batchSize : hosts.length;
      final batch = hosts.sublist(start, end);
      final results = await Future.wait(batch.map(_probeHost));

      for (final result in results) {
        if (result != null) {
          final duplicate = found.any(
            (existing) =>
                existing.host == result.host && existing.brand == result.brand,
          );
          if (!duplicate) {
            found.add(result);
          }
        }
      }

      checked += batch.length;
      onProgress?.call(checked, hosts.length);
    }

    return found;
  }

  Future<String?> _findPrivateIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final ip = address.address;
        if (_isPrivate(ip)) {
          return ip;
        }
      }
    }
    return null;
  }

  bool _isPrivate(String ip) {
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((value) => value == null)) {
      return false;
    }

    final a = p[0]!;
    final b = p[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  Future<DiscoveredTv?> _probeHost(String host) async {
    final roku = await _probeRoku(host);
    if (roku != null) {
      return roku;
    }

    final vizio = await _probeVizio(host);
    if (vizio != null) {
      return vizio;
    }

    return _probeLg(host);
  }

  Future<DiscoveredTv?> _probeRoku(String host) async {
    try {
      final response = await IoHttp.request(
        Uri.parse('http://$host:8060/query/device-info'),
        timeout: const Duration(milliseconds: 450),
      );

      if (response.statusCode != 200 ||
          !RokuController.identifiesRokuDevice(response.body)) {
        return null;
      }

      String? tag(String name) {
        final match = RegExp(
          '<$name>(.*?)</$name>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(response.body);
        return match?.group(1)?.trim();
      }

      final model = tag('model-name');
      final friendly = tag('friendly-device-name') ??
          tag('user-device-name') ??
          model ??
          'Roku TV';

      return DiscoveredTv(
        host: host,
        brand: TvBrand.roku,
        suggestedName: friendly,
        model: model,
        port: 8060,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DiscoveredTv?> _probeVizio(String host) async {
    for (final port in const [7345, 9000]) {
      try {
        final response = await IoHttp.request(
          Uri.parse('https://$host:$port/state/device/deviceinfo'),
          allowBadCertificate: true,
          timeout: const Duration(milliseconds: 500),
        );

        if (response.statusCode >= 500 || response.body.isEmpty) {
          continue;
        }

        String? model;
        String? name;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final items = decoded['ITEMS'];
            if (items is List && items.isNotEmpty && items.first is Map) {
              final item = Map<String, dynamic>.from(items.first as Map);
              final value = item['VALUE'];
              if (value is Map) {
                final map = Map<String, dynamic>.from(value);
                model = (map['MODEL_NAME'] ?? map['MODEL'])?.toString();
                name = (map['NAME'] ?? map['DEVICE_NAME'])?.toString();
              }
            }
          }
        } catch (_) {
          // A valid SmartCast HTTP response is enough for discovery.
        }

        return DiscoveredTv(
          host: host,
          brand: TvBrand.vizio,
          suggestedName: name?.isNotEmpty == true ? name! : 'Vizio TV',
          model: model,
          port: port,
        );
      } catch (_) {
        // Try the next SmartCast port.
      }
    }
    return null;
  }

  Future<DiscoveredTv?> _probeLg(String host) async {
    const endpoints = [
      (urlScheme: 'ws', port: 3000, timeoutMs: 800),
      (urlScheme: 'wss', port: 3001, timeoutMs: 1200),
    ];

    for (final endpoint in endpoints) {
      final found = await _probeLgEndpoint(
        host,
        scheme: endpoint.urlScheme,
        port: endpoint.port,
        timeout: Duration(milliseconds: endpoint.timeoutMs),
      );
      if (found) {
        return DiscoveredTv(
          host: host,
          brand: TvBrand.lgWebOs,
          suggestedName: 'LG TV',
          port: endpoint.port,
        );
      }
    }

    return null;
  }

  Future<bool> _probeLgEndpoint(
    String host, {
    required String scheme,
    required int port,
    required Duration timeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback = (_, __, ___) => true;
    WebSocket? socket;

    try {
      socket = await WebSocket.connect(
        '$scheme://$host:$port',
        customClient: client,
      ).timeout(timeout);
      socket.add(jsonEncode({
        'id': 'hello',
        'type': 'hello',
        'payload': <String, dynamic>{},
      }));

      final response = await socket.first.timeout(timeout);
      return identifiesLgHello(response);
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {
        // The probe may have timed out or the TV may have closed the socket.
      }
      client.close(force: true);
    }
  }

  static bool identifiesLgHello(Object? response) {
    if (response is! String) {
      return false;
    }

    try {
      final decoded = jsonDecode(response);
      return decoded is Map && decoded['type'] == 'hello';
    } catch (_) {
      return false;
    }
  }

  Future<int?> resolveVizioPort(String host) async {
    final result = await _probeVizio(host);
    return result?.port;
  }
}
