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

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({
    super.key,
    this.discovery = const DiscoveryService(),
  });

  final DiscoveryService discovery;

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();

  bool _scanning = false;
  bool _scanCompleted = false;
  int _checked = 0;
  int _total = 254;
  List<DiscoveredTv> _found = const [];

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

    return PopScope(
      canPop: !_scanning,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _scanning,
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
                    Text(
                      'Found TVs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._found.map(
                      (tv) => Card(
                        child: ListTile(
                          leading: Icon(_brandIcon(tv.brand)),
                          title: Text(tv.suggestedName),
                          subtitle: Text(
                            '${tv.brand.label} • ${tv.host}'
                            '${tv.model == null ? '' : ' • ${tv.model}'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _configure(
                            brand: tv.brand,
                            host: tv.host,
                            port: tv.port,
                            suggestedName: tv.suggestedName,
                            model: tv.model,
                          ),
                        ),
                      ),
                    ),
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
          if (_scanning) ...[
            ModalBarrier(
              color: colors.scrim.withValues(alpha: 0.46),
              dismissible: false,
              semanticsLabel: 'TV scan in progress',
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ScanProgressCard(
                    checked: _checked,
                    total: _total,
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
      id: Uuid().v4(),
      name: name,
      brand: brand,
      host: host,
      port: port,
      model: model,
    );

    try {
      switch (brand) {
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

      if (mounted) {
        Navigator.pop(context, device);
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _pairRoku(TvDevice device) async {
    final controller = RokuController(device);
    await controller.connect();
    await controller.disconnect();
  }

  Future<void> _pairLg(TvDevice device) async {
    final controller = LgWebOsController(
      device,
      CredentialStore.instance,
    );

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
    await controller.disconnect();
  }

  Future<void> _pairVizio(TvDevice device) async {
    final controller = VizioController(
      device,
      CredentialStore.instance,
    );
    final session = await controller.startPairing();

    if (!mounted) {
      return;
    }

    final pin = await showVizioPinDialog(context);

    if (pin == null) {
      throw const TvRemoteException('Vizio pairing was canceled.');
    }

    await controller.completePairing(session, pin);
    await controller.disconnect();
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
