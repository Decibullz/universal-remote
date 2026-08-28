enum TvBrand {
  lgWebOs('LG webOS'),
  roku('Roku TV'),
  vizio('Vizio SmartCast');

  const TvBrand(this.label);

  final String label;

  static TvBrand fromJson(String value) {
    return TvBrand.values.firstWhere(
      (brand) => brand.name == value,
      orElse: () => TvBrand.lgWebOs,
    );
  }
}
