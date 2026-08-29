import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/models/tv_app_info.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/models/tv_input_info.dart';
import 'package:universal_tv_remote/screens/add_device_screen.dart';
import 'package:universal_tv_remote/services/controller_factory.dart';
import 'package:universal_tv_remote/services/credential_store.dart';
import 'package:universal_tv_remote/services/device_store.dart';
import 'package:universal_tv_remote/services/favorite_store.dart';
import 'package:universal_tv_remote/widgets/dpad.dart';
import 'package:universal_tv_remote/widgets/favorite_app_button.dart';
import 'package:universal_tv_remote/widgets/favorite_picker_sheet.dart';
import 'package:universal_tv_remote/widgets/input_picker_sheet.dart';
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
  Map<String, List<TvAppInfo>> _favoritesByDevice = const {};
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
    final favoriteEntries = await Future.wait(
      devices.map((device) async {
        final favorites = await FavoriteStore.instance.load(device.id);
        return MapEntry(device.id, favorites);
      }),
    );

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
      _favoritesByDevice = Map.fromEntries(favoriteEntries);
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
    final result = await Navigator.of(context).push<AddDevicesResult>(
      MaterialPageRoute(
        builder: (_) => AddDeviceScreen(existingDevices: _devices),
      ),
    );

    if (result == null) {
      return;
    }

    final added = <TvDevice>[];
    for (final device in result.devices) {
      final duplicate = _devices.any(
            (saved) => saved.brand == device.brand && saved.host == device.host,
          ) ||
          added.any(
            (saved) => saved.brand == device.brand && saved.host == device.host,
          );
      if (!duplicate) {
        added.add(device);
      }
    }

    if (added.isEmpty) {
      if (result.errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errors.join('\n'))),
        );
      }
      return;
    }

    final favoriteEntries = await Future.wait(
      added.map((device) async {
        final favorites = await FavoriteStore.instance.load(device.id);
        return MapEntry(device.id, favorites);
      }),
    );
    final devices = [..._devices, ...added];
    final selected = added.first;
    await DeviceStore.instance.saveDevices(devices);
    await DeviceStore.instance.setSelectedDeviceId(selected.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _selected = selected;
      _favoritesByDevice = {
        ..._favoritesByDevice,
        ...Map.fromEntries(favoriteEntries),
      };
    });
    await _connect(selected);

    if (result.errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${added.length} TV${added.length == 1 ? '' : 's'} added. '
            '${result.errors.join('\n')}',
          ),
        ),
      );
    }
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
    final devices = _devices
        .map((item) => item.id == device.id ? updated : item)
        .toList(growable: false);

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

    final devices =
        _devices.where((item) => item.id != device.id).toList(growable: false);
    await CredentialStore.instance.deleteDevice(device.id);
    await FavoriteStore.instance.delete(device.id);
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
      _favoritesByDevice = Map<String, List<TvAppInfo>>.from(
        _favoritesByDevice,
      )..remove(device.id);
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
        appBar: AppBar(title: const Text('Tv Remote')),
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

    final favorites =
        _favoritesByDevice[selected.id] ?? FavoriteStore.defaultFavorites;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primaryContainer.withValues(alpha: 0.2),
              colors.surface,
              colors.surface,
            ],
            stops: const [0, 0.34, 1],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final top = _buildTopControls(
              context,
              selected: selected,
              connected: connected,
              favorites: favorites,
            );
            final dpad = _buildDpad(connected);
            final bottom = _buildBottomControls(
              selected: selected,
              connected: connected,
            );

            if (constraints.maxHeight < 800) {
              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  children: [
                    top,
                    const SizedBox(height: 22),
                    Center(child: dpad),
                    const SizedBox(height: 24),
                    bottom,
                  ],
                ),
              );
            }

            return Stack(
              children: [
                Center(child: dpad),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: double.infinity, child: top),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(width: double.infinity, child: bottom),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopControls(
    BuildContext context, {
    required TvDevice selected,
    required bool connected,
    required List<TvAppInfo> favorites,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RemoteHeader(
          devices: _devices,
          selected: selected,
          connectionState: _connectionState,
          onSelected: _selectDevice,
          onManage: _showManageDevices,
          onPower: connected ? () => _confirmPowerOff(selected) : null,
        ),
        if (_connectionState == RemoteConnectionState.error) ...[
          const SizedBox(height: 10),
          _ConnectionNotice(
            message: _connectionError ?? 'Could not connect to this TV.',
            onReconnect: () => _connect(selected),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Favorites',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: connected ? () => _editFavorites(selected) : null,
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var index = 0; index < favorites.length; index++) ...[
              Expanded(
                child: FavoriteAppButton(
                  app: favorites[index],
                  onPressed: connected
                      ? () => _run(
                            () => _controller!.launchApp(favorites[index]),
                          )
                      : null,
                  onLongPress:
                      connected ? () => _editFavorites(selected) : null,
                ),
              ),
              if (index != favorites.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDpad(bool connected) {
    return Dpad(
      key: const Key('remote-dpad'),
      onUp: connected ? () => _run(_controller!.up) : null,
      onDown: connected ? () => _run(_controller!.down) : null,
      onLeft: connected ? () => _run(_controller!.left) : null,
      onRight: connected ? () => _run(_controller!.right) : null,
      onSelect: connected ? () => _run(_controller!.select) : null,
    );
  }

  Widget _buildBottomControls({
    required TvDevice selected,
    required bool connected,
  }) {
    return Column(
      key: const Key('remote-bottom-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _RemoteButton(
                icon: Icons.keyboard_return_rounded,
                label: 'Back',
                vertical: true,
                height: 64,
                onPressed: connected ? () => _run(_controller!.back) : null,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _RemoteButton(
                icon: Icons.home_rounded,
                label: 'Home',
                vertical: true,
                height: 64,
                onPressed: connected ? () => _run(_controller!.home) : null,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _RemoteButton(
                icon: Icons.input_rounded,
                label: 'Input',
                vertical: true,
                height: 64,
                onPressed: connected ? () => _showInputPicker(selected) : null,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _RemoteButton(
                icon: Icons.menu_rounded,
                label: 'Menu',
                vertical: true,
                height: 64,
                onPressed: connected ? () => _run(_controller!.menu) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 76,
                child: _RemoteButton(
                  icon: Icons.volume_off_rounded,
                  label: 'Mute',
                  vertical: true,
                  iconSize: 30,
                  onPressed: connected ? () => _run(_controller!.mute) : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _RemoteButton(
                  icon: Icons.play_arrow,
                  label: 'Play / Pause',
                  vertical: true,
                  iconSize: 36,
                  onPressed:
                      connected ? () => _run(_controller!.playPause) : null,
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 76,
                child: _RemoteButton(
                  icon: Icons.keyboard_alt_outlined,
                  label: 'Keyboard',
                  vertical: true,
                  iconSize: 28,
                  onPressed: connected ? _showKeyboard : null,
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 84,
                child: _VolumeRocker(
                  onUp: connected ? () => _run(_controller!.volumeUp) : null,
                  onDown:
                      connected ? () => _run(_controller!.volumeDown) : null,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Future<void> _editFavorites(TvDevice device) async {
    final controller = _controller;
    if (controller == null ||
        _selected?.id != device.id ||
        _connectionState != RemoteConnectionState.connected) {
      return;
    }

    final current =
        _favoritesByDevice[device.id] ?? FavoriteStore.defaultFavorites;
    final updated = await showModalBottomSheet<List<TvAppInfo>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FavoritePickerSheet(
        deviceName: device.name,
        initialFavorites: current,
        loadApps: controller.getApps,
      ),
    );

    if (updated == null) {
      return;
    }

    await FavoriteStore.instance.save(device.id, updated);
    if (!mounted) {
      return;
    }

    setState(() {
      _favoritesByDevice = {
        ..._favoritesByDevice,
        device.id: List.unmodifiable(updated),
      };
    });
  }

  Future<void> _showInputPicker(TvDevice device) async {
    final controller = _controller;
    if (controller == null ||
        _selected?.id != device.id ||
        _connectionState != RemoteConnectionState.connected) {
      return;
    }

    final input = await showModalBottomSheet<TvInputInfo>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => InputPickerSheet(
        deviceName: device.name,
        loadInputs: controller.getInputs,
      ),
    );
    if (input != null) {
      await _run(() => controller.switchInput(input));
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
                  device.id == _selected?.id
                      ? Icons.check_circle
                      : Icons.tv_outlined,
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

class _RemoteHeader extends StatelessWidget {
  const _RemoteHeader({
    required this.devices,
    required this.selected,
    required this.connectionState,
    required this.onSelected,
    required this.onManage,
    required this.onPower,
  });

  final List<TvDevice> devices;
  final TvDevice selected;
  final RemoteConnectionState connectionState;
  final ValueChanged<TvDevice> onSelected;
  final VoidCallback onManage;
  final VoidCallback? onPower;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<TvDevice>(
            tooltip: 'Switch TV',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onSelected: onSelected,
            itemBuilder: (context) => [
              for (final device in devices)
                PopupMenuItem(
                  value: device,
                  child: Row(
                    children: [
                      Icon(
                        device.id == selected.id
                            ? Icons.check_circle_rounded
                            : Icons.tv_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              device.brand.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: _DeviceSelector(
              device: selected,
              connectionState: connectionState,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          tooltip: 'Manage TVs',
          icon: Icons.tune_rounded,
          onPressed: onManage,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          tooltip: 'Power off',
          icon: Icons.power_settings_new_rounded,
          onPressed: onPower,
          destructive: true,
        ),
      ],
    );
  }
}

class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector({
    required this.device,
    required this.connectionState,
  });

  final TvDevice device;
  final RemoteConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (status, statusColor) = switch (connectionState) {
      RemoteConnectionState.idle => ('Not connected', colors.outline),
      RemoteConnectionState.connecting => ('Connecting…', colors.tertiary),
      RemoteConnectionState.connected => ('Connected', const Color(0xFF35C779)),
      RemoteConnectionState.error => ('Connection failed', colors.error),
    };

    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.72),
                      colors.primary,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.tv_rounded,
                  size: 19,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (connectionState == RemoteConnectionState.connecting)
                          SizedBox.square(
                            dimension: 7,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: statusColor,
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: connectionState ==
                                      RemoteConnectionState.connected
                                  ? [
                                      BoxShadow(
                                        color: statusColor.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 7,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${device.brand.label} • $status',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = destructive
        ? colors.errorContainer.withValues(alpha: 0.72)
        : colors.surfaceContainerHigh;
    final foreground = destructive ? colors.error : colors.onSurface;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  },
            child: SizedBox.square(
              dimension: 46,
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({
    required this.message,
    required this.onReconnect,
  });

  final String message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.errorContainer.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 19, color: colors.error),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: onReconnect,
              child: const Text('Retry'),
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
    this.vertical = false,
    this.iconSize = 22,
    this.height,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool vertical;
  final double iconSize;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = vertical
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize),
              const SizedBox(height: 11),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.48 : 1,
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            height: height ?? (vertical ? 118 : 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeRocker extends StatelessWidget {
  const _VolumeRocker({required this.onUp, required this.onDown});

  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onUp != null || onDown != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'VOL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            Expanded(
              child: _RockerButton(
                icon: Icons.add_rounded,
                label: 'Volume up',
                onPressed: onUp,
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 15,
              endIndent: 15,
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
            Expanded(
              child: _RockerButton(
                icon: Icons.remove_rounded,
                label: 'Volume down',
                onPressed: onDown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RockerButton extends StatelessWidget {
  const _RockerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: Center(child: Icon(icon, size: 25)),
      ),
    );
  }
}
