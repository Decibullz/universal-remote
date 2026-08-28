import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/services/favorite_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses the legacy four apps as defaults', () async {
    final favorites = await FavoriteStore.instance.load('new-tv');

    expect(
      favorites.map((favorite) => favorite.title),
      ['Netflix', 'Hulu', 'Crunchyroll', 'MLB'],
    );
  });

  test('saves a different set of favorites for each TV', () async {
    const livingRoom = [
      TvAppInfo(id: '1', title: 'YouTube'),
      TvAppInfo(id: '2', title: 'Netflix'),
      TvAppInfo(id: '3', title: 'Hulu'),
      TvAppInfo(id: '4', title: 'Plex'),
    ];
    const bedroom = [
      TvAppInfo(id: 'a', title: 'Disney+'),
      TvAppInfo(id: 'b', title: 'Max'),
      TvAppInfo(id: 'c', title: 'Prime Video'),
      TvAppInfo(id: 'd', title: 'Spotify'),
    ];

    await FavoriteStore.instance.save('living-room', livingRoom);
    await FavoriteStore.instance.save('bedroom', bedroom);

    expect(
      (await FavoriteStore.instance.load('living-room'))
          .map((favorite) => favorite.title),
      livingRoom.map((favorite) => favorite.title),
    );
    expect(
      (await FavoriteStore.instance.load('bedroom'))
          .map((favorite) => favorite.title),
      bedroom.map((favorite) => favorite.title),
    );
  });
}
