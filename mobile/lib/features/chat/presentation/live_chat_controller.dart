import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:orbit/core/network/account_restriction.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/data/chat_gateway.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/wave_limit.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/settings/presentation/settings_controller.dart';

/// Chat on the server (ADR-0004). Messages show at once as pending and turn
/// into sent when the server acknowledges them; pending ones are resent
/// (idempotently) after a reconnect. The live connection is open only while
/// the app is in the foreground.
class LiveChatController extends ChatController {
  /// How long a typing indicator lasts without a fresh signal.
  static const typingTimeout = Duration(seconds: 4);

  /// How long a deleted conversation can be restored before the server
  /// forgets it (longer than the undo snack bar).
  static const deleteGrace = Duration(seconds: 5);

  late ChatGateway _gateway;
  final _random = Random.secure();
  final _loaded = <String>{};
  final _otherRead = <String, int>{};
  final _typingTimers = <String, Timer>{};
  final _pendingDeletes = <String, Timer>{};
  final _uploads = <String, PickedMedia>{};
  var _connectedBefore = false;

  @override
  Map<String, Conversation> build() {
    _gateway = ref.watch(chatGatewayProvider)!;
    final subscription = _gateway.events.listen(_onEvent);
    final lifecycle = AppLifecycleListener(
      onResume: _gateway.connect,
      onPause: _gateway.disconnect,
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      lifecycle.dispose();
      for (final timer in [
        ..._typingTimers.values,
        ..._pendingDeletes.values,
      ]) {
        timer.cancel();
      }
      _gateway.disconnect();
    });
    _gateway.connect();
    unawaited(_refreshInbox());
    // A restriction makes the gateway stop reconnecting; reconnect when the
    // member is reinstated and comes back without restarting the app.
    ref.listen(accountRestrictedProvider, (wasRestricted, restricted) {
      if ((wasRestricted ?? false) && !restricted) _gateway.connect();
    });
    return const {};
  }

  // --- user actions --------------------------------------------------------

  @override
  void send(String profileId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _sendNew(profileId, MessageKind.text, text: trimmed);
  }

  @override
  void wave(String profileId) => _sendNew(profileId, MessageKind.wave);

  @override
  void shareLocation(String profileId, int minutes) =>
      _sendNew(profileId, MessageKind.location, locationMinutes: minutes);

  @override
  void shareAlbum(String profileId, String albumName, {String? albumId}) =>
      _sendNew(
        profileId,
        MessageKind.album,
        albumName: albumName,
        albumId: albumId,
      );

  @override
  void sendMedia(
    String profileId,
    MessageKind kind,
    PickedMedia media, {
    bool viewOnce = false,
  }) {
    final message = _pendingMessage(
      kind,
      viewOnce: kind == MessageKind.photo && viewOnce,
    );
    _uploads[message.clientMsgId!] = media;
    _upsert(profileId, message);
    unawaited(_upload(profileId, message));
  }

  /// Uploads a pending media message's bytes, then sends it.
  Future<void> _upload(String profileId, Message message) async {
    final media = _uploads[message.clientMsgId];
    final repository = ref.read(mediaRepositoryProvider);
    if (media == null || repository == null) return;
    try {
      final uploaded = await repository.upload(
        switch (message.kind) {
          MessageKind.video => MediaPurpose.chatVideo,
          MessageKind.voice => MediaPurpose.voiceNote,
          _ => MediaPurpose.chatPhoto,
        },
        media.bytes,
        media.contentType,
        durationMs: media.durationMs,
      );
      if (!ref.mounted) return;
      _uploads.remove(message.clientMsgId);
      final ready = message.copyWith(mediaId: uploaded.id);
      _replace(profileId, ready);
      _gateway.send(profileId, ready);
    } on ApiException {
      if (ref.mounted) {
        _replace(profileId, message.copyWith(status: DeliveryStatus.failed));
      }
    }
  }

  @override
  Future<MediaLinks> mediaLinks(String profileId, String messageId) async {
    final links = await _gateway.mediaLinks(messageId);
    final message = _find(profileId, messageId);
    if (ref.mounted && message != null && message.viewOnce && !message.fromMe) {
      _replace(profileId, message.copyWith(viewed: true));
    }
    return links;
  }

  @override
  Future<void> open(String profileId) async {
    if (_loaded.contains(profileId)) return;
    try {
      final page = await _gateway.history(profileId);
      if (!ref.mounted) return;
      _loaded.add(profileId);
      _otherRead[profileId] = page.otherReadSeq;
      final existing = state[profileId];
      if (existing == null && page.messages.isEmpty) return;
      put(
        (existing ?? Conversation(profileId: profileId, messages: const []))
            .copyWith(
              messages: _merge(profileId, existing?.messages, page.messages),
              muted: page.muted,
            ),
      );
    } on ApiException {
      // Shows what the inbox already has; the next open or reconnect retries.
    }
  }

  @override
  void typing(String profileId) => _gateway.typing(profileId);

  @override
  void retry(String profileId, String messageId) {
    final message = _find(profileId, messageId);
    if (message == null || message.status != DeliveryStatus.failed) return;
    final pending = message.copyWith(status: DeliveryStatus.pending);
    _replace(profileId, pending);
    if (pending.kind.hasMedia && pending.mediaId == null) {
      unawaited(_upload(profileId, pending));
    } else {
      _gateway.send(profileId, pending);
    }
  }

  @override
  void markRead(String profileId) {
    final conversation = state[profileId];
    if (conversation == null || conversation.unread == 0) return;
    put(conversation.copyWith(unread: 0));
    final seq = _maxSeq(conversation.messages);
    if (seq == null) return;
    _gateway.markRead(
      profileId,
      seq,
      share: ref.read(settingsProvider).readReceipts,
    );
  }

  @override
  bool unsend(String profileId, String messageId) {
    final message = _find(profileId, messageId);
    if (message == null || !message.canUnsend(now)) return false;
    _replace(profileId, message.copyWith(unsent: true));
    unawaited(
      _gateway.unsend(messageId).catchError((Object _) {
        if (ref.mounted) _replace(profileId, message);
      }),
    );
    return true;
  }

  @override
  Conversation? delete(String profileId) {
    final removed = state[profileId];
    if (removed == null) return null;
    state = {...state}..remove(profileId);
    _loaded.remove(profileId);
    _pendingDeletes[profileId]?.cancel();
    _pendingDeletes[profileId] = Timer(deleteGrace, () {
      _pendingDeletes.remove(profileId);
      unawaited(
        _gateway.delete(profileId).catchError((Object _) {
          // Not deleted on the server: it comes back on the next inbox load.
        }),
      );
    });
    return removed;
  }

  @override
  void restore(Conversation conversation) {
    _pendingDeletes.remove(conversation.profileId)?.cancel();
    put(conversation);
  }

  @override
  void toggleMute(String profileId) {
    final conversation = state[profileId];
    if (conversation == null) return;
    final muted = !conversation.muted;
    put(conversation.copyWith(muted: muted));
    unawaited(
      _gateway.setMuted(profileId, muted: muted).catchError((Object _) {
        final current = ref.mounted ? state[profileId] : null;
        if (current != null) put(current.copyWith(muted: !muted));
      }),
    );
  }

  // --- server events -------------------------------------------------------

  void _onEvent(ChatEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case AccountRestricted():
        ref.read(accountRestrictedProvider.notifier).flag();
      case ChatConnected():
        unawaited(_catchUp());
      case MessageReceived(:final otherId, :final message):
        if (isBlocked(otherId)) return;
        _setTyping(otherId, typing: false);
        final isNew = _find(otherId, message.id) == null;
        _upsert(
          otherId,
          message,
          unreadDelta: isNew && !message.fromMe ? 1 : 0,
        );
      case MessageAcked(:final otherId, :final message):
        _upsert(otherId, message);
      case MessageUnsent(:final otherId, :final messageId):
        final message = _find(otherId, messageId);
        if (message != null) _replace(otherId, message.copyWith(unsent: true));
      case ReadUpTo(:final otherId, :final seq):
        _otherRead[otherId] = max(_otherRead[otherId] ?? 0, seq);
        final conversation = state[otherId];
        if (conversation != null) {
          put(
            conversation.copyWith(
              messages: [
                for (final m in conversation.messages) _receipt(otherId, m),
              ],
            ),
          );
        }
      case MessageViewed(:final otherId, :final messageId):
        final message = _find(otherId, messageId);
        if (message != null) _replace(otherId, message.copyWith(viewed: true));
      case OtherTyping(:final otherId):
        if (!isBlocked(otherId)) _setTyping(otherId, typing: true);
      case SendFailed(:final clientMsgId, :final reason, :final retryAt):
        for (final c in state.values) {
          for (final m in c.messages) {
            if (m.clientMsgId != clientMsgId ||
                m.status != DeliveryStatus.pending) {
              continue;
            }
            if (reason == SendFailure.waveLimit) {
              _refuseWave(c.profileId, m, retryAt);
            } else {
              _replace(c.profileId, m.copyWith(status: DeliveryStatus.failed));
            }
          }
        }
    }
  }

  /// Drops a wave the server refused and locks the Wave button, rather than
  /// leaving a failed message that could only be refused again.
  void _refuseWave(String profileId, Message wave, DateTime? retryAt) {
    final conversation = state[profileId];
    if (conversation == null) return;
    put(
      conversation.copyWith(
        messages: [
          for (final m in conversation.messages)
            if (m.id != wave.id) m,
        ],
      ),
    );
    final unlocksAt = retryAt ?? now.add(waveWindow);
    ref.read(waveLimitProvider(profileId).notifier).block(unlocksAt);
    ref.read(waveRefusalProvider.notifier).refusal = WaveRefusal(
      profileId,
      unlocksAt,
    );
  }

  /// After a (re)connect: load what was missed and resend what is pending.
  Future<void> _catchUp() async {
    if (_connectedBefore) await _refreshInbox();
    _connectedBefore = true;
    for (final profileId in [..._loaded]) {
      final conversation = state[profileId];
      if (conversation == null) continue;
      try {
        final page = await _gateway.history(
          profileId,
          afterSeq: _maxSeq(conversation.messages),
        );
        if (!ref.mounted) return;
        _otherRead[profileId] = page.otherReadSeq;
        final current = state[profileId];
        if (current != null) {
          put(
            current.copyWith(
              messages: _merge(profileId, current.messages, page.messages),
            ),
          );
        }
      } on ApiException {
        // Offline again; the next reconnect catches up.
      }
    }
    if (!ref.mounted) return;
    for (final conversation in state.values) {
      for (final m in conversation.messages) {
        // Media still uploading is sent when its upload finishes.
        final uploading = m.kind.hasMedia && m.mediaId == null;
        if (m.status == DeliveryStatus.pending && !uploading) {
          _gateway.send(conversation.profileId, m);
        }
      }
    }
  }

  Future<void> _refreshInbox() async {
    try {
      final conversations = await _gateway.inbox();
      if (!ref.mounted) return;
      final next = <String, Conversation>{};
      for (final fromServer in conversations) {
        final id = fromServer.profileId;
        if (_pendingDeletes.containsKey(id)) continue;
        final existing = state[id];
        next[id] = existing == null
            ? fromServer
            : existing.copyWith(
                messages: _merge(id, existing.messages, fromServer.messages),
                unread: fromServer.unread,
                muted: fromServer.muted,
              );
      }
      // Conversations the server doesn't have yet (only pending messages).
      for (final entry in state.entries) {
        next.putIfAbsent(entry.key, () => entry.value);
      }
      state = next;
    } on ApiException {
      // Keeps the current inbox; the next reconnect refreshes it.
    }
  }

  // --- helpers -------------------------------------------------------------

  void _sendNew(
    String profileId,
    MessageKind kind, {
    String text = '',
    int? locationMinutes,
    String? albumName,
    String? albumId,
  }) {
    final message = _pendingMessage(
      kind,
      text: text,
      locationMinutes: locationMinutes,
      albumName: albumName,
      albumId: albumId,
    );
    _upsert(profileId, message);
    _gateway.send(profileId, message);
  }

  Message _pendingMessage(
    MessageKind kind, {
    String text = '',
    int? locationMinutes,
    String? albumName,
    String? albumId,
    bool viewOnce = false,
  }) {
    final clientMsgId = _newClientId();
    return Message(
      id: clientMsgId,
      clientMsgId: clientMsgId,
      fromMe: true,
      kind: kind,
      text: text,
      sentAt: now,
      status: DeliveryStatus.pending,
      locationMinutes: locationMinutes,
      albumName: albumName,
      albumId: albumId,
      viewOnce: viewOnce,
    );
  }

  String _newClientId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  void _upsert(String profileId, Message message, {int unreadDelta = 0}) {
    final conversation =
        state[profileId] ??
        Conversation(profileId: profileId, messages: const []);
    put(
      conversation.copyWith(
        messages: _merge(profileId, conversation.messages, [message]),
        unread: conversation.unread + unreadDelta,
      ),
    );
  }

  /// Merges [incoming] into [current]: same id replaces, a stored message
  /// replaces its pending copy (same client id), order is by position with
  /// pending messages last.
  List<Message> _merge(
    String profileId,
    List<Message>? current,
    List<Message> incoming,
  ) {
    final byId = <String, Message>{
      for (final m in current ?? const <Message>[]) m.id: m,
    };
    for (final m in incoming) {
      final clientId = m.clientMsgId;
      if (m.seq != null && clientId != null) byId.remove(clientId);
      byId[m.id] = _receipt(profileId, m);
    }
    return byId.values.toList()..sort((a, b) {
      final sa = a.seq;
      final sb = b.seq;
      if (sa != null && sb != null) return sa.compareTo(sb);
      if (sa != null) return -1;
      if (sb != null) return 1;
      return a.sentAt.compareTo(b.sentAt);
    });
  }

  /// [message] with its status reflecting the other member's read position.
  Message _receipt(String profileId, Message message) {
    final seq = message.seq;
    if (!message.fromMe || seq == null) return message;
    final read = seq <= (_otherRead[profileId] ?? 0);
    return message.copyWith(
      status: read ? DeliveryStatus.read : DeliveryStatus.sent,
    );
  }

  Message? _find(String profileId, String messageId) {
    for (final m in state[profileId]?.messages ?? const <Message>[]) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  void _replace(String profileId, Message message) {
    final conversation = state[profileId];
    if (conversation == null) return;
    put(
      conversation.copyWith(
        messages: [
          for (final m in conversation.messages)
            m.id == message.id ? message : m,
        ],
      ),
    );
  }

  static int? _maxSeq(List<Message> messages) {
    int? highest;
    for (final m in messages) {
      final seq = m.seq;
      if (seq != null && (highest == null || seq > highest)) highest = seq;
    }
    return highest;
  }

  void _setTyping(String profileId, {required bool typing}) {
    _typingTimers.remove(profileId)?.cancel();
    ref.read(typingProvider.notifier).set(profileId, typing: typing);
    if (typing) {
      _typingTimers[profileId] = Timer(typingTimeout, () {
        _typingTimers.remove(profileId);
        if (ref.mounted) {
          ref.read(typingProvider.notifier).set(profileId, typing: false);
        }
      });
    }
  }
}
