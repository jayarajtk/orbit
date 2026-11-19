import 'package:orbit/features/chat/domain/message.dart';

/// A 1:1 conversation with another member.
class Conversation {
  /// Creates a conversation.
  const Conversation({
    required this.profileId,
    required this.messages,
    this.unread = 0,
    this.muted = false,
  });

  /// The other member's profile id.
  final String profileId;

  /// Messages, oldest first.
  final List<Message> messages;

  /// Messages from the other member not yet seen.
  final int unread;

  /// Whether notifications are muted.
  final bool muted;

  /// The newest message, if any.
  Message? get last => messages.isEmpty ? null : messages.last;

  /// Returns a copy with the given fields replaced.
  Conversation copyWith({
    List<Message>? messages,
    int? unread,
    bool? muted,
  }) {
    return Conversation(
      profileId: profileId,
      messages: messages ?? this.messages,
      unread: unread ?? this.unread,
      muted: muted ?? this.muted,
    );
  }
}
