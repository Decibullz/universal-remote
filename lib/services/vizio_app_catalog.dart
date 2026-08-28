import 'dart:convert';

import 'package:universal_tv_remote/models/tv_favorite.dart';
import 'package:universal_tv_remote/services/io_http.dart';

class VizioAppConfig {
  const VizioAppConfig({
    required this.appId,
    required this.nameSpace,
    this.message,
  });

  final String appId;
  final int nameSpace;
  final String? message;

  Map<String, dynamic> toLaunchValue() => {
        'APP_ID': appId,
        'NAME_SPACE': nameSpace,
        'MESSAGE': message,
      };
}

class VizioAppCatalog {
  static const _catalogUrl =
      'https://scfs.vizio.com/appservice/vizio_apps_prod.json';
  static const _availabilityUrl =
      'https://scfs.vizio.com/appservice/app_availability_prod.json';

  static final Map<TvFavorite, VizioAppConfig> _legacyFallbacks = {
    TvFavorite.hulu: const VizioAppConfig(appId: '3', nameSpace: 2),
    TvFavorite.netflix: const VizioAppConfig(appId: '1', nameSpace: 3),
  };

  List<dynamic>? _catalog;
  List<dynamic>? _availability;

  Future<VizioAppConfig?> resolve(TvFavorite favorite) async {
    try {
      await _load();
      final target = favorite.label.toLowerCase();

      Map<String, dynamic>? record;
      for (final item in _catalog!.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().toLowerCase() ?? '';
        final matches = favorite == TvFavorite.mlb
            ? (name == 'mlb' || name == 'mlb.tv' || name.startsWith('mlb '))
            : name == target;
        if (matches) {
          record = map;
          break;
        }
      }

      if (record == null) {
        return _legacyFallbacks[favorite];
      }

      final catalogId = _coerceId(record['id']);
      if (catalogId == null) {
        return _legacyFallbacks[favorite];
      }

      for (final item in _availability!.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        if (_coerceId(map['id']) != catalogId) {
          continue;
        }

        final chipsets = map['chipsets'];
        if (chipsets is! Map) {
          continue;
        }

        // Prefer a wildcard payload. Otherwise choose the first available
        // chipset payload; SmartCast firmware varies by model, so this is
        // deliberately resolved at runtime instead of hard-coding app IDs.
        final groups = <dynamic>[];
        if (chipsets['*'] is List) {
          groups.addAll(chipsets['*'] as List);
        }
        for (final entry in chipsets.entries) {
          if (entry.key == '*' || entry.value is! List) {
            continue;
          }
          groups.addAll(entry.value as List);
        }

        for (final payloadRecord in groups.whereType<Map>()) {
          final encoded = payloadRecord['app_type_payload']?.toString();
          if (encoded == null || encoded.isEmpty) {
            continue;
          }
          final decoded = jsonDecode(encoded);
          if (decoded is! Map) {
            continue;
          }

          final appId = decoded['APP_ID']?.toString();
          final namespace = int.tryParse(decoded['NAME_SPACE'].toString());
          if (appId == null || namespace == null) {
            continue;
          }

          return VizioAppConfig(
            appId: appId,
            nameSpace: namespace,
            message: decoded['MESSAGE']?.toString(),
          );
        }
      }
    } catch (_) {
      // The SmartCast CDN is not required for basic remote control.
    }

    return _legacyFallbacks[favorite];
  }

  Future<void> _load() async {
    if (_catalog != null && _availability != null) {
      return;
    }

    final results = await Future.wait([
      IoHttp.request(Uri.parse(_catalogUrl), timeout: const Duration(seconds: 5)),
      IoHttp.request(
        Uri.parse(_availabilityUrl),
        timeout: const Duration(seconds: 5),
      ),
    ]);

    final catalogDecoded = jsonDecode(results[0].body);
    final availabilityDecoded = jsonDecode(results[1].body);

    _catalog = catalogDecoded is List ? catalogDecoded : const [];
    _availability =
        availabilityDecoded is List ? availabilityDecoded : const [];
  }

  String? _coerceId(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value?.toString();
  }
}
