import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_tv_remote/models/tv_device.dart';

class DeviceStore {
  DeviceStore._();

  static final DeviceStore instance = DeviceStore._();

  static const _devicesKey = 'tv_remote.devices';
  static const _selectedDeviceKey = 'tv_remote.selected_device';

  Future<List<TvDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_devicesKey);
    if (encoded == null || encoded.isEmpty) {
      return [];
    }

    final list = jsonDecode(encoded) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(TvDevice.fromJson)
        .toList(growable: false);
  }

  Future<void> saveDevices(List<TvDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _devicesKey,
      jsonEncode(devices.map((device) => device.toJson()).toList()),
    );
  }

  Future<String?> selectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedDeviceKey);
  }

  Future<void> setSelectedDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDeviceKey, id);
  }
}
