import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';

class FavoriteStore {
  FavoriteStore._();

  static final FavoriteStore instance = FavoriteStore._();

  static const defaultFavorites = [
    TvAppInfo(id: 'netflix', title: 'Netflix'),
    TvAppInfo(id: 'hulu', title: 'Hulu'),
    TvAppInfo(id: 'crunchyroll', title: 'Crunchyroll'),
    TvAppInfo(id: 'mlb', title: 'MLB'),
  ];

  static const _keyPrefix = 'tv_remote.favorite_apps.';

  Future<List<TvAppInfo>> load(String deviceId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_keyPrefix$deviceId');
    if (encoded == null || encoded.isEmpty) {
      return defaultFavorites;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return defaultFavorites;
      }

      final favorites = decoded
          .whereType<Map>()
          .map((item) => TvAppInfo.fromJson(Map<String, dynamic>.from(item)))
          .where((app) => app.id.isNotEmpty && app.title.isNotEmpty)
          .take(4)
          .toList(growable: false);
      return favorites.length == 4 ? favorites : defaultFavorites;
    } catch (_) {
      return defaultFavorites;
    }
  }

  Future<void> save(String deviceId, List<TvAppInfo> favorites) async {
    if (favorites.length != 4) {
      throw ArgumentError.value(
        favorites.length,
        'favorites',
        'Exactly four favorites are required.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$deviceId',
      jsonEncode(favorites.map((favorite) => favorite.toJson()).toList()),
    );
  }

  Future<void> delete(String deviceId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix$deviceId');
  }
}
