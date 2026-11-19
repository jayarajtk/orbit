/// The ring around a member's avatar.
enum StatusRing {
  /// No live statuses.
  none('NONE'),

  /// At least one live status the viewer has not seen.
  unseen('UNSEEN'),

  /// Live statuses, all seen.
  seen('SEEN')
  ;

  const StatusRing(this.apiValue);

  /// Value used by the API.
  final String apiValue;

  /// Parses an API value; [none] when missing or unknown.
  static StatusRing fromApi(String? value) {
    for (final ring in values) {
      if (ring.apiValue == value) return ring;
    }
    return none;
  }
}

DateTime _utc(Object? value) => DateTime.parse(value! as String).toUtc();

/// A live status as another member sees it.
class StatusItem {
  /// Creates an item.
  const StatusItem({
    required this.id,
    required this.url,
    required this.createdAt,
    required this.seen,
    this.thumbUrl,
    this.caption,
  });

  /// Parses the API's `StatusItem`.
  factory StatusItem.fromJson(Map<String, dynamic> json) => StatusItem(
    id: json['id'] as String,
    url: json['url'] as String,
    thumbUrl: json['thumbUrl'] as String?,
    caption: json['caption'] as String?,
    createdAt: _utc(json['createdAt']),
    seen: json['seen'] as bool? ?? false,
  );

  /// Status id.
  final String id;

  /// Full-size photo.
  final String url;

  /// Small photo.
  final String? thumbUrl;

  /// Optional caption.
  final String? caption;

  /// When it was posted (UTC).
  final DateTime createdAt;

  /// Whether the viewer has seen it.
  final bool seen;
}

/// A member who viewed one of the user's statuses.
class StatusSeenBy {
  /// Creates a viewer.
  const StatusSeenBy({
    required this.id,
    required this.name,
    required this.viewedAt,
    this.thumbUrl,
  });

  /// Parses the API's viewer object.
  factory StatusSeenBy.fromJson(Map<String, dynamic> json) => StatusSeenBy(
    id: json['id'] as String,
    name: json['name'] as String,
    thumbUrl: json['thumbUrl'] as String?,
    viewedAt: _utc(json['viewedAt']),
  );

  /// Member id.
  final String id;

  /// Display name.
  final String name;

  /// Small avatar.
  final String? thumbUrl;

  /// When they viewed it (UTC).
  final DateTime viewedAt;
}

/// One of the user's own live statuses.
class MyStatus {
  /// Creates a status.
  const MyStatus({
    required this.id,
    required this.url,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    required this.viewers,
    this.thumbUrl,
    this.caption,
  });

  /// Parses the API's `MyStatus`.
  factory MyStatus.fromJson(Map<String, dynamic> json) => MyStatus(
    id: json['id'] as String,
    url: json['url'] as String,
    thumbUrl: json['thumbUrl'] as String?,
    caption: json['caption'] as String?,
    createdAt: _utc(json['createdAt']),
    expiresAt: _utc(json['expiresAt']),
    viewCount: (json['viewCount'] as num).toInt(),
    viewers: [
      for (final v in (json['viewers'] as List<dynamic>? ?? const []))
        StatusSeenBy.fromJson(v as Map<String, dynamic>),
    ],
  );

  /// Status id.
  final String id;

  /// Full-size photo.
  final String url;

  /// Small photo.
  final String? thumbUrl;

  /// Optional caption.
  final String? caption;

  /// When it was posted (UTC).
  final DateTime createdAt;

  /// When it disappears (UTC).
  final DateTime expiresAt;

  /// Whether it is still live at [now]. The server deletes expired statuses
  /// on a schedule, so a list fetched earlier can hold some that are gone.
  bool isLiveAt(DateTime now) => expiresAt.isAfter(now);

  /// How many members viewed it.
  final int viewCount;

  /// Who viewed it.
  final List<StatusSeenBy> viewers;
}
