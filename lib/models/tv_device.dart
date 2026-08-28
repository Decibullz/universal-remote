import 'package:universal_tv_remote/models/tv_brand.dart';

class TvDevice {
  const TvDevice({
    required this.id,
    required this.name,
    required this.brand,
    required this.host,
    this.port,
    this.model,
  });

  final String id;
  final String name;
  final TvBrand brand;
  final String host;
  final int? port;
  final String? model;

  TvDevice copyWith({
    String? id,
    String? name,
    TvBrand? brand,
    String? host,
    int? port,
    String? model,
  }) {
    return TvDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      host: host ?? this.host,
      port: port ?? this.port,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand.name,
        'host': host,
        'port': port,
        'model': model,
      };

  factory TvDevice.fromJson(Map<String, dynamic> json) {
    return TvDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: TvBrand.fromJson(json['brand'] as String),
      host: json['host'] as String,
      port: json['port'] as int?,
      model: json['model'] as String?,
    );
  }
}
