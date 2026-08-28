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
import 'package:uuid/uuid.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _discovery = const DiscoveryService();
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();

  bool _scanning = false;
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
      _checked = 0;
      _found = const [];
    });

    try {
      final results = await _discovery.scan(
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
        setState(() => _found = results);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add TV')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.radar),
            label: Text(_scanning ? 'Scanning $_checked / $_total' : 'Scan Wi-Fi'),
          ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _total == 0 ? null : _checked / _total,
            ),
          ],
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
      port = await _discovery.resolveVizioPort(host);
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

    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Vizio PIN'),
        content: TextField(
          controller: pinController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'PIN shown on TV',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = pinController.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );
    pinController.dispose();

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
