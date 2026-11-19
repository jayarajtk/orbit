import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/data/seed_conversations.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/domain/reply_bot.dart';
import 'package:orbit/features/chat/presentation/live_chat_controller.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';

/// How quickly dummy members react. Tests override this.
class ChatTiming {
  /// Creates timing settings.
  const ChatTiming({required this.replyAfter, required this.typingFor});

  /// Delay before the other member starts typing.
  final Duration replyAfter;

  /// How long they "type" before the reply arrives.
  final Duration typingFor;
}

/// Reply timing for dummy members.
final chatTimingProvider = Provider<ChatTiming>(
  (ref) => const ChatTiming(
    replyAfter: Duration(milliseconds: 1500),
    typingFor: Duration(seconds: 2),
  ),
);

/// Profile ids of members currently typing.
final typingProvider = NotifierProvider<TypingNotifier, Set<String>>(
  TypingNotifier.new,
);

/// Holds who is typing.
class TypingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Marks [profileId] as typing or not.
  void set(String profileId, {required bool typing}) {
    state = typing ? {...state, profileId} : ({...state}..remove(profileId));
  }
}

/// All conversations by profile id: live from the server in API mode,
/// in memory with dummy replies in demo mode.
final chatProvider =
    NotifierProvider<ChatController, Map<String, Conversation>>(
      () => AppEnv.usesApi ? LiveChatController() : DemoChatController(),
    );

/// Inbox order: newest first, without blocked members or empty chats.
final inboxProvider = Provider<List<Conversation>>((ref) {
  final blocked = ref.watch(blockedProvider);
  final conversations = [
    for (final c in ref.watch(chatProvider).values)
      if (c.last != null && !blocked.contains(c.profileId)) c,
  ]..sort((a, b) => b.last!.sentAt.compareTo(a.last!.sentAt));
  return conversations;
});

/// Total unread messages, for the Inbox tab badge.
///
/// Reads the chat and block state directly rather than [inboxProvider]: the
/// tab bar is paused while a full-screen route covers it, and a
/// provider-to-provider chain re-evaluated on resume would schedule a
/// rebuild in the middle of a frame.
final unreadTotalProvider = Provider<int>((ref) {
  final blocked = ref.watch(blockedProvider);
  var total = 0;
  for (final c in ref.watch(chatProvider).values) {
    if (!blocked.contains(c.profileId)) total += c.unread;
  }
  return total;
});

/// What the chat screens can do, independent of where messages live.
abstract class ChatController extends Notifier<Map<String, Conversation>> {
  /// Sends [text] to [profileId]. Blank text is ignored.
  void send(String profileId, String text);

  /// Waves at [profileId].
  void wave(String profileId);

  /// Shares live location with [profileId] for [minutes].
  void shareLocation(String profileId, int minutes);

  /// Posts an album-share card in the chat with [profileId]. [albumId] is
  /// the server's album (null in demo mode).
  void shareAlbum(String profileId, String albumName, {String? albumId});

  /// Uploads and sends a photo, video or voice note. Not available in demo
  /// mode, where the buttons are hidden.
  void sendMedia(
    String profileId,
    MessageKind kind,
    PickedMedia media, {
    bool viewOnce = false,
  }) {}

  /// Sends each of [photos] as its own photo message, in order. Where
  /// uploads are slow they must not overtake each other; see the live
  /// controller.
  void sendPhotos(String profileId, List<PickedMedia> photos) {
    for (final photo in photos) {
      sendMedia(profileId, MessageKind.photo, photo);
    }
  }

  /// Links to a message's media. For a view-once photo the recipient gets
  /// them once. Throws [ApiException].
  Future<MediaLinks> mediaLinks(String profileId, String messageId) =>
      throw UnsupportedError('Media needs the server.');

  /// Loads the conversation with [profileId] when its screen opens.
  Future<void> open(String profileId) async {}

  /// Tells [profileId] the user is typing.
  void typing(String profileId) {}

  /// Resends a message that failed.
  void retry(String profileId, String messageId) {}

  /// Clears the unread count for [profileId].
  void markRead(String profileId);

  /// Unsends [messageId] if it is the user's and inside the unsend window.
  /// Returns whether it was unsent.
  bool unsend(String profileId, String messageId);

  /// Deletes the conversation with [profileId] and returns it for undo.
  Conversation? delete(String profileId);

  /// Puts back a conversation removed by [delete].
  void restore(Conversation conversation);

  /// Mutes or unmutes notifications for [profileId].
  void toggleMute(String profileId);

  /// Current time.
  @protected
  DateTime get now => ref.read(clockProvider)();

  /// Stores [conversation].
  @protected
  void put(Conversation conversation) {
    state = {...state, conversation.profileId: conversation};
  }

  /// Whether [profileId] is blocked.
  @protected
  bool isBlocked(String profileId) =>
      ref.read(blockedProvider).contains(profileId);
}

/// In-memory chat for demo mode (no server). Dummy members reply via
/// [ReplyBot] after [ChatTiming] delays.
class DemoChatController extends ChatController {
  final _timers = <Timer>[];
  final _turns = <String, int>{};
  var _nextId = 0;

  @override
  Map<String, Conversation> build() {
    ref.onDispose(() {
      for (final timer in _timers) {
        timer.cancel();
      }
    });
    return seedConversations(now);
  }

  /// Sends [text] to [profileId]. Blank text is ignored.
  @override
  void send(String profileId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _appendMine(profileId, MessageKind.text, text: trimmed);
    final turn = _turns[profileId] ?? 0;
    _turns[profileId] = turn + 1;
    _scheduleReply(profileId, ReplyBot.replyTo(trimmed, turn));
  }

  /// Waves at [profileId].
  @override
  void wave(String profileId) {
    _appendMine(profileId, MessageKind.wave);
    _scheduleReply(profileId, ReplyBot.waveBack);
  }

  /// Shares live location with [profileId] for [minutes].
  @override
  void shareLocation(String profileId, int minutes) {
    _appendMine(profileId, MessageKind.location, locationMinutes: minutes);
    _scheduleReply(profileId, ReplyBot.locationThanks);
  }

  /// Posts an album-share card in the chat with [profileId].
  @override
  void shareAlbum(String profileId, String albumName, {String? albumId}) {
    _appendMine(profileId, MessageKind.album, albumName: albumName);
    _scheduleReply(profileId, ReplyBot.albumThanks);
  }

  /// Clears the unread count for [profileId].
  @override
  void markRead(String profileId) {
    final conversation = state[profileId];
    if (conversation == null || conversation.unread == 0) return;
    put(conversation.copyWith(unread: 0));
  }

  /// Unsends [messageId] if it is the user's and inside the unsend window.
  /// Returns whether it was unsent.
  @override
  bool unsend(String profileId, String messageId) {
    final conversation = state[profileId];
    if (conversation == null) return false;
    final index = conversation.messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || !conversation.messages[index].canUnsend(now)) {
      return false;
    }
    final messages = [...conversation.messages];
    messages[index] = messages[index].copyWith(unsent: true);
    put(conversation.copyWith(messages: messages));
    return true;
  }

  /// Deletes the conversation with [profileId] and returns it for undo.
  @override
  Conversation? delete(String profileId) {
    final removed = state[profileId];
    state = {...state}..remove(profileId);
    return removed;
  }

  /// Puts back a conversation removed by [delete].
  @override
  void restore(Conversation conversation) => put(conversation);

  /// Mutes or unmutes notifications for [profileId].
  @override
  void toggleMute(String profileId) {
    final conversation = state[profileId];
    if (conversation == null) return;
    put(conversation.copyWith(muted: !conversation.muted));
  }

  void _appendMine(
    String profileId,
    MessageKind kind, {
    String text = '',
    int? locationMinutes,
    String? albumName,
  }) {
    _append(
      profileId,
      Message(
        id: 'm${_nextId++}',
        fromMe: true,
        kind: kind,
        text: text,
        sentAt: now,
        locationMinutes: locationMinutes,
        albumName: albumName,
      ),
    );
  }

  void _append(String profileId, Message message) {
    final conversation =
        state[profileId] ?? Conversation(profileId: profileId, messages: []);
    put(
      conversation.copyWith(
        messages: [...conversation.messages, message],
        unread: message.fromMe ? null : conversation.unread + 1,
      ),
    );
  }

  void _scheduleReply(String profileId, String reply) {
    final timing = ref.read(chatTimingProvider);
    _timers.add(
      Timer(timing.replyAfter, () {
        if (!ref.mounted || isBlocked(profileId)) return;
        ref.read(typingProvider.notifier).set(profileId, typing: true);
        _timers.add(
          Timer(timing.typingFor, () {
            if (!ref.mounted) return;
            ref.read(typingProvider.notifier).set(profileId, typing: false);
            if (isBlocked(profileId) || !state.containsKey(profileId)) {
              return;
            }
            _markMineRead(profileId);
            _append(
              profileId,
              Message(
                id: 'm${_nextId++}',
                fromMe: false,
                kind: MessageKind.text,
                text: reply,
                sentAt: now,
              ),
            );
          }),
        );
      }),
    );
  }

  void _markMineRead(String profileId) {
    final conversation = state[profileId];
    if (conversation == null) return;
    put(
      conversation.copyWith(
        messages: [
          for (final m in conversation.messages)
            m.fromMe ? m.copyWith(status: DeliveryStatus.read) : m,
        ],
      ),
    );
  }
}
