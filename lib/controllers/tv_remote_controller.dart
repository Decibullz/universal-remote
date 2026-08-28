import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';

abstract interface class TvRemoteController {
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();

  Future<void> up();
  Future<void> down();
  Future<void> left();
  Future<void> right();
  Future<void> select();

  Future<void> back();
  Future<void> home();

  Future<void> volumeUp();
  Future<void> volumeDown();
  Future<void> mute();

  Future<void> playPause();
  Future<void> powerOff();

  Future<void> sendText(String text);
  Future<void> backspace();
  Future<void> enter();

  Future<List<TvAppInfo>> getApps();
  Future<void> launchApp(TvAppInfo app);
  Future<void> launchFavorite(TvFavorite favorite);
}

class TvRemoteException implements Exception {
  const TvRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PairingRequiredException extends TvRemoteException {
  const PairingRequiredException(super.message);
}
