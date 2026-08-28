import 'package:flutter/material.dart';
import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_favorite.dart';
import 'package:universal_tv_remote/screens/add_device_screen.dart';
import 'package:universal_tv_remote/services/controller_factory.dart';
import 'package:universal_tv_remote/services/credential_store.dart';
import 'package:universal_tv_remote/services/device_store.dart';
import 'package:universal_tv_remote/widgets/dpad.dart';
import 'package:universal_tv_remote/widgets/favorite_app_button.dart';
import 'package:universal_tv_remote/widgets/keyboard_sheet.dart';

enum RemoteConnectionState {
  idle,
  connecting,
  connected,
  error,
}

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  List<TvDevice> _devices = const [];
  TvDevice? _selected;
  TvRemoteController? _controller;
  RemoteConnectionState _connectionState = RemoteConnectionState.idle;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.disconnect();
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await DeviceStore.instance.loadDevices();
    final selectedId = await DeviceStore.instance.selectedDeviceId();

    TvDevice? selected;
    if (devices.isNotEmpty) {
      selected = devices.first;
      if (selectedId != null) {
        for (final device in devices) {
          if (device.id == selectedId) {
            selected = device;
            break;
          }
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _selected = selected;
    });

    if (selected != null) {
      await _connect(selected);
    }
  }

  Future<void> _connect(TvDevice device) async {
    setState(() {
      _connectionState = RemoteConnectionState.connecting;
      _connectionError = null;
    });

    await _controller?.disconnect();
    final controller = ControllerFactory.create(device);
    _controller = controller;

    try {
      await controller.connect();
      if (!mounted || _controller != controller) {
        return;
      }
      setState(() => _connectionState = RemoteConnectionState.connected);
    } catch (error) {
      if (!mounted || _controller != controller) {
        return;
      }
      setState(() {
        _connectionState = RemoteConnectionState.error;
        _connectionError = error.toString();
      });
    }
  }

  Future<void> _selectDevice(TvDevice device) async {
    if (_selected?.id == device.id) {
      return;
    }

    setState(() => _selected = device);
    await DeviceStore.instance.setSelectedDeviceId(device.id);
    await _connect(device);
  }

  Future<void> _addDevice() async {
    final device = await Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );

    if (device == null) {
      return;
    }

    final devices = [..._devices, device];
    await DeviceStore.instance.saveDevices(devices);
    await DeviceStore.instance.setSelectedDeviceId(device.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _selected = device;
    });
    await _connect(device);
  }

  Future<void> _renameDevice(TvDevice device) async {
    final controller = TextEditingController(text: device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename TV'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null) {
      return;
    }

    final updated = device.copyWith(name: name);
    final devices = _devices.map((item) => item.id == device.id ? updated : item).toList(growable: false);

    await DeviceStore.instance.saveDevices(devices);

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      if (_selected?.id == device.id) {
        _selected = updated;
      }
    });
  }

  Future<void> _deleteDevice(TvDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${device.name}?'),
        content: const Text(
          'This removes the saved TV and its pairing credentials from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final deletingSelected = _selected?.id == device.id;
    if (deletingSelected) {
      await _controller?.disconnect();
      _controller = null;
    }

    final devices = _devices.where((item) => item.id != device.id).toList(growable: false);
    await CredentialStore.instance.deleteDevice(device.id);
    await DeviceStore.instance.saveDevices(devices);

    final next = devices.isEmpty ? null : devices.first;
    if (next != null) {
      await DeviceStore.instance.setSelectedDeviceId(next.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      if (deletingSelected) {
        _selected = next;
        _connectionState = RemoteConnectionState.idle;
      }
    });

    if (deletingSelected && next != null) {
      await _connect(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('TV Remote')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.connected_tv,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'No TVs yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add an LG webOS, Roku TV, or Vizio SmartCast TV on this Wi-Fi network.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Add TV'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selected = _selected ?? _devices.first;
    final connected = _connectionState == RemoteConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<TvDevice>(
            value: selected,
            borderRadius: BorderRadius.circular(16),
            items: _devices
                .map(
                  (device) => DropdownMenuItem(
                    value: device,
                    child: Text(device.name),
                  ),
                )
                .toList(),
            onChanged: (device) {
              if (device != null) {
                _selectDevice(device);
              }
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Manage TVs',
            onPressed: _showManageDevices,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _StatusBar(
              device: selected,
              state: _connectionState,
              error: _connectionError,
              onReconnect: () => _connect(selected),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final favorite in TvFavorite.values) ...[
                    FavoriteAppButton(
                      favorite: favorite,
                      onPressed: connected
                          ? () => _run(
                                () => _controller!.launchFavorite(favorite),
                              )
                          : null,
                    ),
                    if (favorite != TvFavorite.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Dpad(
                onUp: connected ? () => _run(_controller!.up) : () {},
                onDown: connected ? () => _run(_controller!.down) : () {},
                onLeft: connected ? () => _run(_controller!.left) : () {},
                onRight: connected ? () => _run(_controller!.right) : () {},
                onSelect: connected ? () => _run(_controller!.select) : () {},
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.arrow_back,
                    label: 'Back',
                    onPressed: connected ? () => _run(_controller!.back) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onPressed: connected ? () => _run(_controller!.home) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.keyboard_alt_outlined,
                    label: 'Keyboard',
                    onPressed: connected ? _showKeyboard : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.volume_down,
                    label: 'Vol −',
                    onPressed: connected ? () => _run(_controller!.volumeDown) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.volume_off_outlined,
                    label: 'Mute',
                    onPressed: connected ? () => _run(_controller!.mute) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.volume_up,
                    label: 'Vol +',
                    onPressed: connected ? () => _run(_controller!.volumeUp) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.play_arrow,
                    label: 'Play / Pause',
                    onPressed: connected ? () => _run(_controller!.playPause) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RemoteButton(
                    icon: Icons.power_settings_new,
                    label: 'Power Off',
                    onPressed: connected ? () => _confirmPowerOff(selected) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showKeyboard() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => KeyboardSheet(controller: controller),
    );
  }

  Future<void> _confirmPowerOff(TvDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Turn off ${device.name}?'),
        content: const Text(
          'Power-on is intentionally not included because LG/Vizio wake-up '
          'normally requires broadcast or multicast networking on iPhone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Power Off'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _run(_controller!.powerOff);
    }
  }

  Future<void> _showManageDevices() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final device in _devices)
              ListTile(
                leading: Icon(
                  device.id == _selected?.id ? Icons.check_circle : Icons.tv_outlined,
                ),
                title: Text(device.name),
                subtitle: Text('${device.brand.label} • ${device.host}'),
                onTap: () {
                  Navigator.pop(context);
                  _selectDevice(device);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    Navigator.pop(context);
                    if (value == 'rename') {
                      _renameDevice(device);
                    } else if (value == 'delete') {
                      _deleteDevice(device);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove'),
                    ),
                  ],
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add TV'),
              onTap: () {
                Navigator.pop(context);
                _addDevice();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.device,
    required this.state,
    required this.error,
    required this.onReconnect,
  });

  final TvDevice device;
  final RemoteConnectionState state;
  final String? error;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (state) {
      RemoteConnectionState.idle => (Icons.circle_outlined, 'Not connected'),
      RemoteConnectionState.connecting => (Icons.sync, 'Connecting…'),
      RemoteConnectionState.connected => (Icons.circle, 'Connected'),
      RemoteConnectionState.error => (Icons.error_outline, 'Connection failed'),
    };

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$text • ${device.brand.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    error ?? device.host,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (state == RemoteConnectionState.error)
              IconButton(
                tooltip: 'Reconnect',
                onPressed: onReconnect,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
