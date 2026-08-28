import 'package:universal_tv_remote/models/tv_brand.dart';

class DiscoveredTv {
  const DiscoveredTv({
    required this.host,
    required this.brand,
    required this.suggestedName,
    this.port,
    this.model,
  });

  final String host;
  final TvBrand brand;
  final String suggestedName;
  final int? port;
  final String? model;
}
