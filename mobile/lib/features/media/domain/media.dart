/// Why something is uploaded; decides what the server accepts.
enum MediaPurpose {
  /// A public profile photo.
  profilePhoto('PROFILE_PHOTO'),

  /// A photo in a private album.
  albumPhoto('ALBUM_PHOTO'),

  /// A photo sent in chat.
  chatPhoto('CHAT_PHOTO'),

  /// A short video sent in chat.
  chatVideo('CHAT_VIDEO'),

  /// A voice note.
  voiceNote('VOICE_NOTE')
  ;

  const MediaPurpose(this.apiValue);

  /// Value used by the API.
  final String apiValue;

  /// Whether this purpose takes a photo (rather than video or audio).
  bool get isPhoto =>
      this == profilePhoto || this == albumPhoto || this == chatPhoto;
}

/// Short-lived links to a media object. Fetch fresh ones after [expiresAt].
class MediaLinks {
  /// Creates links.
  const MediaLinks({
    required this.url,
    required this.expiresAt,
    this.thumbUrl,
    this.width,
    this.height,
    this.durationMs,
  });

  /// Parses the API's links object.
  factory MediaLinks.fromJson(Map<String, dynamic> json) => MediaLinks(
    url: json['url'] as String,
    thumbUrl: json['thumbUrl'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    durationMs: (json['durationMs'] as num?)?.toInt(),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  /// Full-size photo, video or audio.
  final String url;

  /// Small photo; null for audio and video.
  final String? thumbUrl;

  /// Photo width in pixels.
  final int? width;

  /// Photo height in pixels.
  final int? height;

  /// Video or voice length.
  final int? durationMs;

  /// When the links stop working.
  final DateTime expiresAt;

  /// Width / height, or 1 when unknown.
  double get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : 1;
}

/// A finished upload.
class UploadedMedia {
  /// Creates an upload result.
  const UploadedMedia({required this.id, required this.links});

  /// Media id to attach to a profile, album or message.
  final String id;

  /// Links to the processed media.
  final MediaLinks links;
}
