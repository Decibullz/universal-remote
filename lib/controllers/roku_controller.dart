import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';
import 'package:universal_tv_remote/models/tv_input_info.dart';
import 'package:universal_tv_remote/services/io_http.dart';

class RokuController implements TvRemoteController {
  RokuController(this.device);

  static bool identifiesRokuDevice(String deviceInfo) {
    final hasDeviceInfo = RegExp(
      r'<device-info(?:\s|>)',
      caseSensitive: false,
    ).hasMatch(deviceInfo);
    final hasRokuVendor = RegExp(
      r'<vendor-name>\s*roku\b',
      caseSensitive: false,
    ).hasMatch(deviceInfo);
    final hasRokuDeviceName = RegExp(
      r'<(?:friendly-model-name|default-device-name|friendly-device-name)>[^<]*\broku\b',
      caseSensitive: false,
    ).hasMatch(deviceInfo);

    return hasDeviceInfo && (hasRokuVendor || hasRokuDeviceName);
  }

  final TvDevice device;

  bool _connected = false;
  List<TvAppInfo>? _apps;

  Uri _uri(String path) => Uri.parse('http://${device.host}:8060$path');

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    final response = await IoHttp.request(
      _uri('/query/device-info'),
      timeout: const Duration(seconds: 3),
    );

    if (response.statusCode != 200 || !identifiesRokuDevice(response.body)) {
      throw const TvRemoteException(
        'This device did not respond as a Roku TV.',
      );
    }

    _connected = true;
  }

  Future<void> _keypress(String key) async {
    final response = await IoHttp.request(
      _uri('/keypress/${Uri.encodeComponent(key)}'),
      method: 'POST',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) {
        throw const TvRemoteException(
          'Roku blocked remote control. On the TV set Settings > System > '
          'Advanced system settings > Control by mobile apps to Enabled.',
        );
      }
      throw TvRemoteException(
        'Roku command failed (${response.statusCode}).',
      );
    }
  }

  @override
  Future<void> up() => _keypress('Up');

  @override
  Future<void> down() => _keypress('Down');

  @override
  Future<void> left() => _keypress('Left');

  @override
  Future<void> right() => _keypress('Right');

  @override
  Future<void> select() => _keypress('Select');

  @override
  Future<void> back() => _keypress('Back');

  @override
  Future<void> home() => _keypress('Home');

  @override
  Future<void> menu() => _keypress('Info');

  @override
  Future<List<TvInputInfo>> getInputs() async {
    final apps = await getApps();
    return apps
        .where((app) => app.id.toLowerCase().startsWith('tvinput.'))
        .map((app) => TvInputInfo(id: app.id, title: app.title))
        .toList(growable: false);
  }

  @override
  Future<void> switchInput(TvInputInfo input) {
    return _launchApp(TvAppInfo(id: input.id, title: input.title));
  }

  @override
  Future<void> volumeUp() => _keypress('VolumeUp');

  @override
  Future<void> volumeDown() => _keypress('VolumeDown');

  @override
  Future<void> mute() => _keypress('VolumeMute');

  @override
  Future<void> playPause() => _keypress('Play');

  @override
  Future<void> powerOff() => _keypress('PowerOff');

  @override
  Future<void> sendText(String text) async {
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      await _keypress('Lit_$character');
    }
  }

  @override
  Future<void> backspace() => _keypress('Backspace');

  @override
  Future<void> enter() => _keypress('Enter');

  @override
  Future<List<TvAppInfo>> getApps() async {
    if (_apps != null) {
      return _apps!;
    }

    final response = await IoHttp.request(_uri('/query/apps'));
    if (response.statusCode != 200) {
      throw TvRemoteException(
        'Roku app list failed (${response.statusCode}).',
      );
    }

    final appExpression = RegExp(
      r'<app\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</app>',
      caseSensitive: false,
      dotAll: true,
    );

    _apps = appExpression.allMatches(response.body).map((match) {
      return TvAppInfo(
        id: match.group(1)!,
        title: _decodeXml(match.group(2)!.trim()),
      );
    }).toList(growable: false);

    return _apps!;
  }

  String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  @override
  Future<void> launchFavorite(TvFavorite favorite) async {
    final apps = await getApps();
    final app = _findFavorite(apps, favorite);
    if (app == null) {
      throw TvRemoteException(
        '${favorite.label} was not found on this Roku TV.',
      );
    }

    await _launchApp(app);
  }

  @override
  Future<void> launchApp(TvAppInfo app) async {
    final legacyFavorite = _legacyFavorite(app);
    if (legacyFavorite != null) {
      await launchFavorite(legacyFavorite);
      return;
    }

    await _launchApp(app);
  }

  Future<void> _launchApp(TvAppInfo app) async {
    final response = await IoHttp.request(
      _uri('/launch/${Uri.encodeComponent(app.id)}'),
      method: 'POST',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TvRemoteException(
        'Roku could not launch ${app.title} '
        '(${response.statusCode}).',
      );
    }
  }

  TvFavorite? _legacyFavorite(TvAppInfo app) {
    for (final favorite in TvFavorite.values) {
      if (app.id == favorite.name) {
        return favorite;
      }
    }
    return null;
  }

  TvAppInfo? _findFavorite(List<TvAppInfo> apps, TvFavorite favorite) {
    final needles = switch (favorite) {
      TvFavorite.hulu => ['hulu'],
      TvFavorite.netflix => ['netflix'],
      TvFavorite.crunchyroll => ['crunchyroll'],
      TvFavorite.mlb => ['mlb', 'mlb.tv'],
    };

    for (final needle in needles) {
      for (final app in apps) {
        final title = app.title.toLowerCase();
        if (title == needle || title.contains(needle)) {
          return app;
        }
      }
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _apps = null;
  }
}
