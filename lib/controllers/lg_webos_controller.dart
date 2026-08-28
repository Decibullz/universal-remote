import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';
import 'package:universal_tv_remote/services/credential_store.dart';

class LgWebOsController implements TvRemoteController {
  LgWebOsController(this.device, this.credentials);

  final TvDevice device;
  final CredentialStore credentials;

  WebSocket? _socket;
  WebSocket? _inputSocket;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamSubscription<dynamic>? _inputSubscription;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  Completer<Map<String, dynamic>>? _registrationCompleter;
  int _requestId = 0;
  List<TvAppInfo>? _apps;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    try {
      await _connectAndHello();

      // Newer webOS releases may require system info before registration.
      try {
        await _request(
          'system/getSystemInfo',
          id: 'get_sys_info',
          timeout: const Duration(seconds: 4),
        );
      } catch (_) {
        // Some older TVs reject this before registration. Pairing can continue.
      }

      await _register();
      final pointer = await _request(
        'com.webos.service.networkinput/getPointerInputSocket',
      );
      final socketPath = pointer['socketPath'] as String?;
      if (socketPath == null || socketPath.isEmpty) {
        throw const TvRemoteException(
          'LG TV did not return its remote input socket.',
        );
      }

      _inputSocket = await _connectAbsoluteSocket(socketPath);
      _inputSubscription = _inputSocket!.listen(
        (_) {},
        onError: (_) {},
      );
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> _connectAndHello() async {
    final endpoints = [
      ('ws://${device.host}:3000', const Duration(seconds: 3)),
      ('wss://${device.host}:3001', const Duration(seconds: 4)),
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (final endpoint in endpoints) {
      try {
        final socket = await _connectAbsoluteSocket(
          endpoint.$1,
          timeout: endpoint.$2,
        );
        _socket = socket;
        _socketSubscription = socket.listen(
          _handleMessage,
          onDone: () => _handleClosed(socket),
          onError: (Object error) => _handleClosed(socket),
        );

        await _sendAndWait({
          'id': 'hello',
          'type': 'hello',
          'payload': <String, dynamic>{},
        }, id: 'hello', timeout: const Duration(seconds: 4));
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        await _closeControlSocket();
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<WebSocket> _connectAbsoluteSocket(
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..badCertificateCallback = (_, __, ___) => true;

    try {
      return await WebSocket.connect(
        url,
        customClient: client,
      ).timeout(timeout);
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  Future<void> _register() async {
    final existingKey = await credentials.read(device.id, 'lg_client_key');

    _registrationCompleter = Completer<Map<String, dynamic>>();
    final payload = <String, dynamic>{
      'forcePairing': false,
      'pairingType': 'PROMPT',
      'client-key': existingKey,
      'manifest': {
        'manifestVersion': 1,
        'appVersion': '1.0',
        'permissions': [
          'APP_TO_APP',
          'CLOSE',
          'CONTROL_AUDIO',
          'CONTROL_DISPLAY',
          'CONTROL_INPUT_JOYSTICK',
          'CONTROL_INPUT_MEDIA_PLAYBACK',
          'CONTROL_INPUT_MEDIA_RECORDING',
          'CONTROL_INPUT_TEXT',
          'CONTROL_INPUT_TV',
          'CONTROL_MOUSE_AND_KEYBOARD',
          'CONTROL_POWER',
          'CONTROL_TV_SCREEN',
          'LAUNCH',
          'LAUNCH_WEBAPP',
          'READ_APP_STATUS',
          'READ_COUNTRY_INFO',
          'READ_CURRENT_CHANNEL',
          'READ_INPUT_DEVICE_LIST',
          'READ_INSTALLED_APPS',
          'READ_NETWORK_STATE',
          'READ_NOTIFICATIONS',
          'READ_POWER_STATE',
          'READ_RUNNING_APPS',
          'READ_TV_CHANNEL_LIST',
          'READ_TV_CURRENT_TIME',
          'READ_UPDATE_INFO',
          'SEARCH',
          'WRITE_NOTIFICATION_ALERT',
          'WRITE_NOTIFICATION_TOAST',
          'WRITE_SETTINGS',
        ],
      },
    };

    _socket!.add(jsonEncode({
      'type': 'register',
      'id': 'register_0',
      'payload': payload,
    }));

    final response = await _registrationCompleter!.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw const TvRemoteException(
        'LG pairing timed out. Accept the connection request on the TV.',
      ),
    );

    final clientKey = (response['payload']
        as Map<String, dynamic>?)?['client-key'] as String?;

    if (clientKey == null || clientKey.isEmpty) {
      throw const TvRemoteException('LG pairing did not return a client key.');
    }

    await credentials.write(device.id, 'lg_client_key', clientKey);
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    // Some webOS versions omit the request ID from their hello response.
    final id = decoded['id']?.toString() ??
        (decoded['type'] == 'hello' ? 'hello' : null);
    if (id == 'register_0') {
      final type = decoded['type']?.toString();
      if (type == 'registered') {
        final completer = _registrationCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(decoded);
        }
      } else if (type == 'error') {
        final completer = _registrationCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            TvRemoteException(
              decoded['error']?.toString() ?? 'LG pairing failed.',
            ),
          );
        }
      }
      return;
    }

    if (id == null) {
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (decoded['type'] == 'error') {
      completer.completeError(
        TvRemoteException(
          decoded['error']?.toString() ?? 'LG command failed.',
        ),
      );
      return;
    }

    completer.complete(decoded);
  }

  void _handleClosed(WebSocket socket) {
    if (!identical(_socket, socket)) {
      return;
    }

    final error = const TvRemoteException('LG TV connection closed.');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
    _socket = null;
  }

  Future<void> _closeControlSocket() async {
    final subscription = _socketSubscription;
    final socket = _socket;
    _socketSubscription = null;
    _socket = null;

    await subscription?.cancel();
    await socket?.close();
  }

  Future<Map<String, dynamic>> _sendAndWait(
    Map<String, dynamic> message, {
    required String id,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final socket = _socket;
    if (socket == null) {
      throw const TvRemoteException('LG TV is not connected.');
    }

    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    socket.add(jsonEncode(message));

    final response = await completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw TvRemoteException('LG request "$id" timed out.');
      },
    );

    final payload = response['payload'];
    return payload is Map<String, dynamic> ? payload : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _request(
    String uri, {
    Map<String, dynamic>? payload,
    String? id,
    Duration timeout = const Duration(seconds: 8),
  }) {
    final requestId = id ?? 'req_${_requestId++}';
    return _sendAndWait({
      'id': requestId,
      'type': 'request',
      'uri': 'ssap://$uri',
      'payload': payload ?? <String, dynamic>{},
    }, id: requestId, timeout: timeout);
  }

  Future<void> _button(String name) async {
    final socket = _inputSocket;
    if (socket == null) {
      throw const TvRemoteException('LG remote input is not connected.');
    }
    socket.add('type:button\nname:$name\n\n');
  }

  @override
  Future<void> up() => _button('UP');

  @override
  Future<void> down() => _button('DOWN');

  @override
  Future<void> left() => _button('LEFT');

  @override
  Future<void> right() => _button('RIGHT');

  @override
  Future<void> select() => _button('ENTER');

  @override
  Future<void> back() => _button('BACK');

  @override
  Future<void> home() => _button('HOME');

  @override
  Future<void> volumeUp() async {
    await _request('audio/volumeUp');
  }

  @override
  Future<void> volumeDown() async {
    await _request('audio/volumeDown');
  }

  @override
  Future<void> mute() async {
    final current = await _request('audio/getMute');
    final isMuted = current['mute'] == true;
    await _request('audio/setMute', payload: {'mute': !isMuted});
  }

  @override
  Future<void> playPause() async {
    // Most webOS apps accept PLAYPAUSE through the pointer-input socket.
    // If a particular app ignores it, its media implementation does not expose
    // a true toggle through SSAP.
    await _button('PLAYPAUSE');
  }

  @override
  Future<void> powerOff() async {
    await _request('system/turnOff');
  }

  @override
  Future<void> sendText(String text) async {
    if (text.isEmpty) {
      return;
    }
    await _request(
      'com.webos.service.ime/insertText',
      payload: {'text': text, 'replace': 0},
    );
  }

  @override
  Future<void> backspace() async {
    await _request(
      'com.webos.service.ime/deleteCharacters',
      payload: {'count': 1},
    );
  }

  @override
  Future<void> enter() async {
    await _request('com.webos.service.ime/sendEnterKey');
  }

  @override
  Future<List<TvAppInfo>> getApps() async {
    if (_apps != null) {
      return _apps!;
    }

    final response = await _request(
      'com.webos.applicationManager/listLaunchPoints',
    );
    final raw = response['launchPoints'];
    if (raw is! List) {
      return const [];
    }

    _apps = raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? map['appId'])?.toString();
          final title = (map['title'] ?? map['name'])?.toString();
          if (id == null || title == null) {
            return null;
          }
          return TvAppInfo(
            id: id,
            title: title,
            iconUrl: map['icon']?.toString(),
          );
        })
        .whereType<TvAppInfo>()
        .toList(growable: false);

    return _apps!;
  }

  @override
  Future<void> launchFavorite(TvFavorite favorite) async {
    final apps = await getApps();
    final match = _findFavorite(apps, favorite);
    if (match == null) {
      throw TvRemoteException(
        '${favorite.label} was not found on this LG TV.',
      );
    }

    await launchApp(match);
  }

  @override
  Future<void> launchApp(TvAppInfo app) async {
    final legacyFavorite = _legacyFavorite(app);
    if (legacyFavorite != null) {
      await launchFavorite(legacyFavorite);
      return;
    }

    await _request('system.launcher/launch', payload: {'id': app.id});
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
    await _inputSubscription?.cancel();
    await _inputSocket?.close();
    _inputSubscription = null;
    _inputSocket = null;
    await _closeControlSocket();
    _apps = null;
  }
}
