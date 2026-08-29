import 'package:flutter/material.dart';
import 'package:universal_tv_remote/controllers/lg_webos_controller.dart';
import 'package:universal_tv_remote/controllers/roku_controller.dart';
import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/controllers/vizio_controller.dart';
import 'package:universal_tv_remote/models/discovered_tv.dart';
import 'package:universal_tv_remote/models/tv_brand.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/services/credential_store.dart';
import 'package:universal_tv_remote/services/discovery_service.dart';
import 'package:universal_tv_remote/widgets/vizio_pin_dialog.dart';
import 'package:uuid/uuid.dart';

typedef DevicePairer = Future<void> Function(TvDevice device);

class AddDevicesResult {
  const AddDevicesResult({
    required this.devices,
    this.errors = const [],
  });

  final List<TvDevice> devices;
  final List<String> errors;
}

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({
    super.key,
    this.discovery = const DiscoveryService(),
    this.existingDevices = const [],
    this.pairDevice,
  });

  final DiscoveryService discovery;
  final List<TvDevice> existingDevices;
  final DevicePairer? pairDevice;

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();

  bool _scanning = false;
  bool _adding = false;
  bool _scanCompleted = false;
  int _checked = 0;
  int _total = 254;
  int _addingIndex = 0;
  int _addingTotal = 0;
  String _addingName = '';
  List<DiscoveredTv> _found = const [];
  Set<String> _selected = const {};

  @override
  void dispose() {
    _manualIpController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanCompleted = false;
      _checked = 0;
      _found = const [];
      _selected = const {};
    });

    try {
      final results = await widget.discovery.scan(
        onProgress: (checked, total) {
          if (mounted) {
            setState(() {
              _checked = checked;
              _total = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _found = results;
          _selected =
              results.where((tv) => !_alreadySaved(tv)).map(_tvKey).toSet();
          _scanCompleted = true;
        });
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = _scanning || _adding;
    final available = _found.where((tv) => !_alreadySaved(tv)).toList();
    final selectedCount =
        available.where((tv) => _selected.contains(_tvKey(tv))).length;
    final allSelected =
        available.isNotEmpty && selectedCount == available.length;

    return PopScope(
      canPop: !busy,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: busy,
            child: Scaffold(
              appBar: AppBar(title: const Text('Add TV')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: const Icon(Icons.radar),
                    label: Text(
                      _scanning ? 'Scanning $_checked / $_total' : 'Scan Wi-Fi',
                    ),
                  ),
                  if (_found.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Found TVs',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (available.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selected = allSelected
                                    ? <String>{}
                                    : available.map(_tvKey).toSet();
                              });
                            },
                            child: Text(allSelected ? 'Clear' : 'Select all'),
                          ),
                      ],
                    ),
                    Text(
                      available.isEmpty
                          ? 'Every discovered TV is already saved.'
                          : 'Select every TV you want to add. You can rename them later.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    ..._found.map(
                      (tv) {
                        final saved = _alreadySaved(tv);
                        final selected = _selected.contains(_tvKey(tv));
                        return Card(
                          child: CheckboxListTile(
                            key: Key('discovered-tv-${_tvKey(tv)}'),
                            value: saved || selected,
                            onChanged: saved
                                ? null
                                : (value) {
                                    setState(() {
                                      final updated = Set<String>.from(
                                        _selected,
                                      );
                                      if (value == true) {
                                        updated.add(_tvKey(tv));
                                      } else {
                                        updated.remove(_tvKey(tv));
                                      }
                                      _selected = updated;
                                    });
                                  },
                            secondary: Icon(_brandIcon(tv.brand)),
                            title: Text(tv.suggestedName),
                            subtitle: Text(
                              '${tv.brand.label} • ${tv.host}'
                              '${tv.model == null ? '' : ' • ${tv.model}'}'
                              '${saved ? ' • Already added' : ''}',
                            ),
                          ),
                        );
                      },
                    ),
                    if (available.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('add-selected-tvs'),
                          onPressed: selectedCount == 0 ? null : _addSelected,
                          icon: const Icon(Icons.add_to_queue_rounded),
                          label: Text(
                            selectedCount == 1
                                ? 'Add selected TV'
                                : 'Add $selectedCount selected TVs',
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (_scanCompleted && _found.isEmpty) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No TVs found',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'On iPhone, open Settings > Apps > Tv Remote and '
                                    'make sure Local Network is enabled. Also confirm '
                                    'the phone and TVs are on the same Wi-Fi network.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Add by IP',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use this if your network is not a typical /24 or scanning misses a TV.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualIpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'TV IP address',
                      hintText: '192.168.1.50',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TvBrand.values
                        .map(
                          (brand) => ActionChip(
                            avatar: Icon(_brandIcon(brand), size: 18),
                            label: Text(brand.label),
                            onPressed: () => _manualAdd(brand),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          if (busy) ...[
            ModalBarrier(
              color: colors.scrim.withValues(alpha: 0.46),
              dismissible: false,
              semanticsLabel: _scanning ? 'TV scan in progress' : 'Adding TVs',
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _scanning
                      ? _ScanProgressCard(
                          checked: _checked,
                          total: _total,
                        )
                      : _AddDevicesProgressCard(
                          current: _addingIndex,
                          total: _addingTotal,
                          name: _addingName,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _manualAdd(TvBrand brand) async {
    final host = _manualIpController.text.trim();
    if (!_validIpv4(host)) {
      _showError('Enter a valid IPv4 address.');
      return;
    }

    if (_alreadySavedHost(brand, host)) {
      _showError('${brand.label} at $host is already added.');
      return;
    }

    int? port;
    if (brand == TvBrand.vizio) {
      port = await widget.discovery.resolveVizioPort(host);
      if (port == null && mounted) {
        _showError(
          'No SmartCast API was found on $host (checked ports 7345 and 9000).',
        );
        return;
      }
    }

    await _configure(
      brand: brand,
      host: host,
      port: port,
      suggestedName: brand.label,
    );
  }

  bool _validIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) {
      return false;
    }
    return parts.every((part) {
      final number = int.tryParse(part);
      return number != null && number >= 0 && number <= 255;
    });
  }

  Future<void> _configure({
    required TvBrand brand,
    required String host,
    required String suggestedName,
    int? port,
    String? model,
  }) async {
    _manualNameController.text = suggestedName;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this TV'),
        content: TextField(
          controller: _manualNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Living Room',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = _manualNameController.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (name == null || !mounted) {
      return;
    }

    final device = TvDevice(
      id: const Uuid().v4(),
      name: name,
      brand: brand,
      host: host,
      port: port,
      model: model,
    );

    setState(() {
      _adding = true;
      _addingIndex = 1;
      _addingTotal = 1;
      _addingName = device.name;
    });

    try {
      await _pairDevice(device);

      if (mounted) {
        Navigator.pop(
          context,
          AddDevicesResult(devices: [device]),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _adding = false);
        _showError(error);
      }
    }
  }

  Future<void> _addSelected() async {
    final selectedTvs = _found
        .where(
          (tv) => !_alreadySaved(tv) && _selected.contains(_tvKey(tv)),
        )
        .toList(growable: false);
    if (selectedTvs.isEmpty) {
      return;
    }

    final usedNames = widget.existingDevices
        .map((device) => device.name.toLowerCase())
        .toSet();
    final devices = <TvDevice>[];
    for (final tv in selectedTvs) {
      final name = _uniqueName(tv.suggestedName, usedNames);
      usedNames.add(name.toLowerCase());
      devices.add(
        TvDevice(
          id: const Uuid().v4(),
          name: name,
          brand: tv.brand,
          host: tv.host,
          port: tv.port,
          model: tv.model,
        ),
      );
    }

    setState(() {
      _adding = true;
      _addingIndex = 0;
      _addingTotal = devices.length;
      _addingName = '';
    });

    final added = <TvDevice>[];
    final errors = <String>[];
    for (var index = 0; index < devices.length; index++) {
      final device = devices[index];
      if (!mounted) {
        return;
      }
      setState(() {
        _addingIndex = index + 1;
        _addingName = device.name;
      });

      try {
        await _pairDevice(device);
        added.add(device);
      } catch (error) {
        errors.add('${device.name}: $error');
      }
    }

    if (!mounted) {
      return;
    }
    if (added.isNotEmpty) {
      Navigator.pop(
        context,
        AddDevicesResult(
          devices: List.unmodifiable(added),
          errors: List.unmodifiable(errors),
        ),
      );
      return;
    }

    setState(() => _adding = false);
    _showError(errors.join('\n'));
  }

  Future<void> _pairDevice(TvDevice device) async {
    final pairDevice = widget.pairDevice;
    if (pairDevice != null) {
      await pairDevice(device);
      return;
    }

    switch (device.brand) {
      case TvBrand.roku:
        await _pairRoku(device);
        break;
      case TvBrand.lgWebOs:
        await _pairLg(device);
        break;
      case TvBrand.vizio:
        await _pairVizio(device);
        break;
    }
  }

  bool _alreadySaved(DiscoveredTv tv) => _alreadySavedHost(tv.brand, tv.host);

  bool _alreadySavedHost(TvBrand brand, String host) {
    return widget.existingDevices.any(
      (device) => device.brand == brand && device.host == host,
    );
  }

  String _tvKey(DiscoveredTv tv) => '${tv.brand.name}:${tv.host}';

  String _uniqueName(String suggestedName, Set<String> usedNames) {
    final base = suggestedName.trim().isEmpty ? 'TV' : suggestedName.trim();
    if (!usedNames.contains(base.toLowerCase())) {
      return base;
    }

    var suffix = 2;
    while (usedNames.contains('$base $suffix'.toLowerCase())) {
      suffix++;
    }
    return '$base $suffix';
  }

  Future<void> _pairRoku(TvDevice device) async {
    final controller = RokuController(device);
    try {
      await controller.connect();
    } finally {
      await _disconnectQuietly(controller);
    }
  }

  Future<void> _pairLg(TvDevice device) async {
    final controller = LgWebOsController(
      device,
      CredentialStore.instance,
    );

    try {
      final future = controller.connect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(
              'LG: accept the connection request on the TV if one appears.',
            ),
          ),
        );
      }

      await future;
    } finally {
      await _disconnectQuietly(controller);
    }
  }

  Future<void> _pairVizio(TvDevice device) async {
    final controller = VizioController(
      device,
      CredentialStore.instance,
    );
    try {
      final session = await controller.startPairing();

      if (!mounted) {
        return;
      }

      final pin = await showVizioPinDialog(context);

      if (pin == null) {
        throw const TvRemoteException('Vizio pairing was canceled.');
      }

      await controller.completePairing(session, pin);
    } finally {
      await _disconnectQuietly(controller);
    }
  }

  Future<void> _disconnectQuietly(TvRemoteController controller) async {
    try {
      await controller.disconnect();
    } catch (_) {
      // Preserve the pairing result if cleanup encounters a closed socket.
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  IconData _brandIcon(TvBrand brand) {
    return switch (brand) {
      TvBrand.lgWebOs => Icons.tv,
      TvBrand.roku => Icons.connected_tv,
      TvBrand.vizio => Icons.live_tv,
    };
  }
}

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({required this.checked, required this.total});

  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? null : checked / total;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Scanning Wi-Fi. Checked $checked of $total addresses.',
      child: Card(
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radar_rounded, size: 40),
                const SizedBox(height: 14),
                Text(
                  'Scanning Wi-Fi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking $checked of $total addresses',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  key: const Key('tv-scan-progress'),
                  value: progress,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  'Controls will unlock when the scan is complete.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDevicesProgressCard extends StatelessWidget {
  const _AddDevicesProgressCard({
    required this.current,
    required this.total,
    required this.name,
  });

  final int current;
  final int total;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Adding TV $current of $total. $name.',
      child: Card(
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_to_queue_rounded, size: 40),
                const SizedBox(height: 14),
                Text(
                  'Adding TVs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pairing $current of $total${name.isEmpty ? '' : ': $name'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  key: const Key('add-tvs-progress'),
                  value: total == 0 ? null : current / total,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  'Follow any pairing instructions shown on each TV.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
