class TvInputInfo {
  const TvInputInfo({
    required this.id,
    required this.title,
    this.stateToken,
  });

  final String id;
  final String title;
  final int? stateToken;
}
