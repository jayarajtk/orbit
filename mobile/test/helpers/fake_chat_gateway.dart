import 'dart:async';
import 'dart:typed_data';

import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/data/chat_gateway.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';

/// The fixed "now" the fake server stamps messages with.
final chatGatewayNow = DateTime.utc(2026, 11, 17, 12);

Message stored(
  String id,
  int seq, {
  required bool fromMe,
  String text = '',
  String? clientMsgId,
}) => Message(
  id: id,
  seq: seq,
  clientMsgId: clientMsgId ?? 'srv-$id',
  fromMe: fromMe,
  kind: MessageKind.text,
  text: text,
  sentAt: chatGatewayNow,
);

/// Records what the controller asks of the server; the test plays the
/// server's side by emitting events.
class FakeChatGateway implements ChatGateway {
  final _events = StreamController<ChatEvent>.broadcast();

  List<Conversation> inboxResult = [
    Conversation(
      profileId: 'bob',
      messages: [stored('m1', 1, fromMe: false, text: 'Hi')],
      unread: 1,
    ),
  ];
  HistoryPage historyResult = HistoryPage(
    messages: [stored('m1', 1, fromMe: false, text: 'Hi')],
    otherReadSeq: 0,
    muted: false,
  );
  bool failMute = false;

  final sent = <(String, Message)>[];
  final reads = <(String, int, bool)>[];
  final historyCalls = <(String, int?)>[];
  final deleted = <String>[];
  final unsent = <String>[];
  int connects = 0;

  void emit(ChatEvent event) => _events.add(event);

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  void connect() => connects++;

  @override
  void disconnect() {}

  @override
  Future<List<Conversation>> inbox() async => inboxResult;

  @override
  Future<HistoryPage> history(String otherId, {int? afterSeq}) async {
    historyCalls.add((otherId, afterSeq));
    return historyResult;
  }

  @override
  void send(String otherId, Message message) => sent.add((otherId, message));

  @override
  void markRead(String otherId, int seq, {required bool share}) =>
      reads.add((otherId, seq, share));

  @override
  void typing(String otherId) {}

  @override
  Future<void> setMuted(String otherId, {required bool muted}) async {
    if (failMute) throw const ApiException(status: 0, type: 'network');
  }

  @override
  Future<void> delete(String otherId) async => deleted.add(otherId);

  @override
  Future<void> unsend(String messageId) async => unsent.add(messageId);

  final linkRequests = <String>[];

  @override
  Future<MediaLinks> mediaLinks(String messageId) async {
    linkRequests.add(messageId);
    return MediaLinks(
      url: 'https://storage.test/$messageId',
      expiresAt: chatGatewayNow.add(const Duration(minutes: 10)),
    );
  }

  @override
  void dispose() => unawaited(_events.close());
}

/// Uploads complete at once unless [fail] is set; records what was sent.
class FakeMediaRepository implements MediaRepository {
  bool fail = false;

  /// Runs at the start of the upload with the 0-based call index; lets a
  /// test make one upload slower than the next.
  Future<void> Function(int index)? before;

  /// Uploads begun so far, finished or not.
  int started = 0;

  /// The bytes of each finished upload, in finishing order.
  final uploadedBytes = <Uint8List>[];

  /// When set, uploads wait for it (an upload in progress).
  Completer<void>? gate;
  final uploads = <(MediaPurpose, String, int?)>[];

  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) async {
    await before?.call(started++);
    await gate?.future;
    if (fail) throw const ApiException(status: 422, type: 'media-rejected');
    uploads.add((purpose, contentType, durationMs));
    uploadedBytes.add(bytes);
    return UploadedMedia(
      id: 'media-${uploads.length}',
      links: MediaLinks(
        url: 'https://storage.test/x',
        expiresAt: chatGatewayNow,
      ),
    );
  }
}
