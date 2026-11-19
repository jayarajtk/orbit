/// What a chat message carries.
enum MessageKind {
  /// Plain text.
  text,

  /// A wave (a lightweight "hi").
  wave,

  /// A timed live-location share.
  location,

  /// A private album shared with the other person.
  album,

  /// A photo, optionally view-once.
  photo,

  /// A short video.
  video,

  /// A voice note.
  voice
  ;

  /// Whether the message carries an uploaded media object.
  bool get hasMedia => this == photo || this == video || this == voice;
}

/// Delivery state of a message the user sent.
enum DeliveryStatus {
  /// Waiting for the server to confirm it.
  pending,

  /// The server refused it or could not be reached; can be retried.
  failed,

  /// Stored by the server.
  sent,

  /// Seen by the recipient (only shown when read receipts are on).
  read,
}

/// One chat message.
class Message {
  /// Creates a message.
  const Message({
    required this.id,
    required this.fromMe,
    required this.kind,
    required this.sentAt,
    this.text = '',
    this.status = DeliveryStatus.sent,
    this.unsent = false,
    this.locationMinutes,
    this.albumName,
    this.seq,
    this.clientMsgId,
    this.mediaId,
    this.albumId,
    this.viewOnce = false,
    this.viewed = false,
  });

  /// How long after sending a message can still be unsent.
  static const unsendWindow = Duration(minutes: 10);

  /// Unique id within the conversation.
  final String id;

  /// Whether the user sent it.
  final bool fromMe;

  /// What it carries.
  final MessageKind kind;

  /// When it was sent.
  final DateTime sentAt;

  /// Text for [MessageKind.text].
  final String text;

  /// Delivery state; meaningful only when [fromMe].
  final DeliveryStatus status;

  /// Whether the sender unsent it.
  final bool unsent;

  /// Share length for [MessageKind.location].
  final int? locationMinutes;

  /// Album name for [MessageKind.album].
  final String? albumName;

  /// Position in the conversation, assigned by the server; null while
  /// pending and in demo mode.
  final int? seq;

  /// Idempotency key of a message the user sent, so retries never duplicate.
  final String? clientMsgId;

  /// Uploaded photo, video or voice note; null while still uploading.
  final String? mediaId;

  /// Shared album, for [MessageKind.album].
  final String? albumId;

  /// A photo the recipient can open once.
  final bool viewOnce;

  /// The recipient has opened this view-once photo.
  final bool viewed;

  /// Whether the user may still unsend this message at [now].
  bool canUnsend(DateTime now) =>
      fromMe &&
      !unsent &&
      status != DeliveryStatus.pending &&
      status != DeliveryStatus.failed &&
      now.difference(sentAt) <= unsendWindow;

  /// Returns a copy with the given fields replaced.
  Message copyWith({
    DeliveryStatus? status,
    bool? unsent,
    String? text,
    String? mediaId,
    bool? viewed,
  }) {
    return Message(
      id: id,
      fromMe: fromMe,
      kind: kind,
      sentAt: sentAt,
      text: text ?? this.text,
      status: status ?? this.status,
      unsent: unsent ?? this.unsent,
      locationMinutes: locationMinutes,
      albumName: albumName,
      seq: seq,
      clientMsgId: clientMsgId,
      mediaId: mediaId ?? this.mediaId,
      albumId: albumId,
      viewOnce: viewOnce,
      viewed: viewed ?? this.viewed,
    );
  }
}
