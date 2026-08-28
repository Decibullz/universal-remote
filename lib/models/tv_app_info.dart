class TvAppInfo {
  const TvAppInfo({
    required this.id,
    required this.title,
    this.iconUrl,
  });

  final String id;
  final String title;
  final String? iconUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconUrl': iconUrl,
      };

  factory TvAppInfo.fromJson(Map<String, dynamic> json) {
    return TvAppInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }
}
