import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';
import 'package:universal_tv_remote/models/tv_input_info.dart';
import 'package:universal_tv_remote/services/credential_store.dart';
import 'package:universal_tv_remote/services/io_http.dart';
import 'package:universal_tv_remote/services/vizio_app_catalog.dart';
import 'package:uuid/uuid.dart';

class VizioPairingSession {
  const VizioPairingSession({
    required this.deviceId,
    required this.requestToken,
    required this.challengeType,
  });

  final String deviceId;
  final int requestToken;
  final int challengeType;
}

class VizioController implements TvRemoteController {
  VizioController(this.device, this.credentials);

  final TvDevice device;
  final CredentialStore credentials;
  final VizioAppCatalog _catalog = VizioAppCatalog();

  String? _authToken;
  bool _connected = false;

  int get _port => device.port ?? 7345;

  Uri _uri(String path) => Uri.parse('https://${device.host}:$_port$path');

  @override
  bool get isConnected => _connected;

  Future<Map<String, dynamic>?> _request(
    String path, {
    String method = 'GET',
    Object? body,
    bool auth = true,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final headers = <String, String>{};
    if (auth && _authToken != null) {
      headers['AUTH'] = _authToken!;
    }

    final response = await IoHttp.request(
      _uri(path),
      method: method,
      headers: headers,
      jsonBody: body,
      allowBadCertificate: true,
      timeout: timeout,
    );

    final json = response.jsonObject;
    String? status;
    final rawStatus = json?['STATUS'];
    if (rawStatus is Map) {
      status = rawStatus['RESULT']?.toString();
    }

    if (response.statusCode >= 400 || (status != null && status.toUpperCase() == 'FAILURE')) {
      throw TvRemoteException(
        'Vizio command failed (${response.statusCode}${status == null ? '' : ', $status'}).',
      );
    }

    return json;
  }

  @override
  Future<void> connect() async {
    _authToken = await credentials.read(device.id, 'vizio_auth_token');
    if (_authToken == null || _authToken!.isEmpty) {
      throw const PairingRequiredException(
        'This Vizio TV needs to be paired first.',
      );
    }

    await _request('/state/device/power_mode');
    _connected = true;
  }

  Future<VizioPairingSession> startPairing() async {
    var deviceId = await credentials.read(device.id, 'vizio_device_id');
    deviceId ??= Uuid().v4();
    await credentials.write(device.id, 'vizio_device_id', deviceId);

    final response = await _request(
      '/pairing/start',
      method: 'PUT',
      auth: false,
      body: {
        'DEVICE_ID': deviceId,
        'DEVICE_NAME': 'Tv Remote',
      },
    );

    final item = response?['ITEM'];
    if (item is! Map) {
      throw const TvRemoteException(
        'Vizio did not return pairing information.',
      );
    }

    final token = int.tryParse(item['PAIRING_REQ_TOKEN'].toString());
    final challenge = int.tryParse(item['CHALLENGE_TYPE'].toString());
    if (token == null || challenge == null) {
      throw const TvRemoteException('Vizio pairing response was incomplete.');
    }

    return VizioPairingSession(
      deviceId: deviceId,
      requestToken: token,
      challengeType: challenge,
    );
  }

  Future<void> completePairing(
    VizioPairingSession session,
    String pin,
  ) async {
    final response = await _request(
      '/pairing/pair',
      method: 'PUT',
      auth: false,
      body: {
        'DEVICE_ID': session.deviceId,
        'CHALLENGE_TYPE': session.challengeType,
        'RESPONSE_VALUE': pin,
        'PAIRING_REQ_TOKEN': session.requestToken,
      },
    );

    final item = response?['ITEM'];
    final token = item is Map ? item['AUTH_TOKEN']?.toString() : null;
    if (token == null || token.isEmpty) {
      throw const TvRemoteException(
        'Vizio pairing failed. Check the PIN shown on the TV.',
      );
    }

    _authToken = token;
    await credentials.write(device.id, 'vizio_auth_token', token);
    _connected = true;
  }

  Future<void> _key(int codeset, int code) async {
    await _request(
      '/key_command/',
      method: 'PUT',
      body: {
        'KEYLIST': [
          {
            'CODESET': codeset,
            'CODE': code,
            'ACTION': 'KEYPRESS',
          }
        ]
      },
    );
  }

  @override
  Future<void> up() => _key(3, 3);

  @override
  Future<void> down() => _key(3, 0);

  @override
  Future<void> left() => _key(3, 1);

  @override
  Future<void> right() => _key(3, 5);

  @override
  Future<void> select() => _key(3, 2);

  @override
  Future<void> back() => _key(4, 0);

  @override
  Future<void> home() => _key(4, 3);

  @override
  Future<void> menu() => _key(4, 8);

  @override
  Future<List<TvInputInfo>> getInputs() async {
    final response = await _request(
      '/menu_native/dynamic/tv_settings/devices/name_input',
    );
    final items = response?['ITEMS'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final id = map['NAME']?.toString();
          final hash = int.tryParse(map['HASHVAL'].toString());
          final value = map['VALUE'];
          final customName = value is Map ? value['NAME']?.toString().trim() : null;
          if (id == null || id.isEmpty || hash == null) {
            return null;
          }
          final title = customName == null || customName.isEmpty ? id : '$id • $customName';
          return TvInputInfo(id: id, title: title, stateToken: hash);
        })
        .whereType<TvInputInfo>()
        .toList(growable: false);
  }

  @override
  Future<void> switchInput(TvInputInfo input) async {
    final hash = input.stateToken;
    if (hash == null) {
      throw const TvRemoteException('Vizio input information was incomplete.');
    }

    await _request(
      '/menu_native/dynamic/tv_settings/devices/current_input',
      method: 'PUT',
      body: {
        'REQUEST': 'MODIFY',
        'VALUE': input.id,
        'HASHVAL': hash,
      },
    );
  }

  @override
  Future<void> volumeUp() => _key(5, 1);

  @override
  Future<void> volumeDown() => _key(5, 0);

  @override
  Future<void> mute() => _key(5, 4);

  @override
  Future<void> playPause() => _key(2, 2);

  @override
  Future<void> powerOff() => _key(11, 0);

  @override
  Future<void> sendText(String text) async {
    final keyList = <Map<String, dynamic>>[];
    for (final rune in text.runes) {
      if (rune > 127) {
        throw const TvRemoteException(
          'Vizio SmartCast keyboard input supports ASCII characters only.',
        );
      }
      keyList.add({
        'CODESET': 0,
        'CODE': rune,
        'ACTION': 'KEYPRESS',
      });
    }

    if (keyList.isEmpty) {
      return;
    }

    await _request(
      '/key_command/',
      method: 'PUT',
      body: {'KEYLIST': keyList},
    );
  }

  @override
  Future<void> backspace() => _key(0, 8);

  @override
  Future<void> enter() => _key(0, 13);

  @override
  Future<List<TvAppInfo>> getApps() async {
    // Vizio maintains its launch catalog remotely rather than exposing a
    // simple installed-app endpoint on the TV.
    final catalogApps = await _catalog.listApps();
    if (catalogApps.isNotEmpty) {
      return catalogApps;
    }

    return TvFavorite.values
        .map((favorite) => TvAppInfo(
              id: favorite.name,
              title: favorite.label,
            ))
        .toList(growable: false);
  }

  @override
  Future<void> launchFavorite(TvFavorite favorite) async {
    await _launchCatalogApp(
      TvAppInfo(id: favorite.name, title: favorite.label),
    );
  }

  @override
  Future<void> launchApp(TvAppInfo app) => _launchCatalogApp(app);

  Future<void> _launchCatalogApp(TvAppInfo app) async {
    final config = await _catalog.resolveApp(app);
    if (config == null) {
      throw TvRemoteException(
        '${app.title} is not available in the current Vizio SmartCast catalog.',
      );
    }

    await _request(
      '/app/launch',
      method: 'PUT',
      body: {'VALUE': config.toLaunchValue()},
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }
}
