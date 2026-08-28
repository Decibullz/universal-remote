class TvAppInfo {
  const TvAppInfo({
    required this.id,
    required this.title,
    this.iconUrl,
  });

  final String id;
  final String title;
  final String? iconUrl;
}
