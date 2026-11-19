import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/auth/auth_repository.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/media/domain/media.dart';

/// Something the server told us about a conversation (ADR-0004).
sealed class ChatEvent {
  const ChatEvent();
}

/// The server closed the connection because the member was suspended or
/// banned (ADR-0007). The gateway stops reconnecting.
class AccountRestricted extends ChatEvent {
  /// Creates the event.
  const AccountRestricted();
}

/// The live connection is up (first time or after a reconnect): time to
/// catch up on anything missed and resend pending messages.
class ChatConnected extends ChatEvent {
  /// Creates the event.
  const ChatConnected();
}

/// A new message from [otherId].
class MessageReceived extends ChatEvent {
  /// Creates the event.
  const MessageReceived(this.otherId, this.message);

  /// The other member.
  final String otherId;

  /// The stored message.
  final Message message;
}

/// The server stored a message the user sent to [otherId].
class MessageAcked extends ChatEvent {
  /// Creates the event.
  const MessageAcked(this.otherId, this.message);

  /// The other member.
  final String otherId;

  /// The stored message; its [Message.clientMsgId] matches the pending one.
  final Message message;
}

/// A message in the conversation with [otherId] was unsent.
class MessageUnsent extends ChatEvent {
  /// Creates the event.
  const MessageUnsent(this.otherId, this.messageId);

  /// The other member.
  final String otherId;

  /// The unsent message.
  final String messageId;
}

/// [otherId] has read the user's messages up to [seq].
class ReadUpTo extends ChatEvent {
  /// Creates the event.
  const ReadUpTo(this.otherId, this.seq);

  /// The other member.
  final String otherId;

  /// Highest message position they have read.
  final int seq;
}

/// [otherId] is typing.
class OtherTyping extends ChatEvent {
  /// Creates the event.
  const OtherTyping(this.otherId);

  /// The other member.
  final String otherId;
}

/// [otherId] opened the user's view-once photo [messageId].
class MessageViewed extends ChatEvent {
  /// Creates the event.
  const MessageViewed(this.otherId, this.messageId);

  /// The other member.
  final String otherId;

  /// The opened message.
  final String messageId;
}

/// The server refused the message with [clientMsgId].
class SendFailed extends ChatEvent {
  /// Creates the event.
  const SendFailed(this.clientMsgId);

  /// The refused message's idempotency key.
  final String clientMsgId;
}

/// One page of history.
class HistoryPage {
  /// Creates a page.
  const HistoryPage({
    required this.messages,
    required this.otherReadSeq,
    required this.muted,
  });

  /// Messages, oldest first.
  final List<Message> messages;

  /// The other member has read the user's messages up to here.
  final int otherReadSeq;

  /// Whether the user muted the conversation.
  final bool muted;
}

/// Chat on the Orbit server: REST for history and the inbox, a WebSocket for
/// live delivery while the app is in the foreground.
abstract interface class ChatGateway {
  /// Live events. Broadcast; never closes while the gateway is alive.
  Stream<ChatEvent> get events;

  /// Opens the live connection (and keeps it open, reconnecting with
  /// backoff) until [disconnect].
  void connect();

  /// Closes the live connection (app in the background or signed out).
  void disconnect();

  /// The user's conversations, newest first. Each holds only its last message.
  Future<List<Conversation>> inbox();

  /// History with [otherId]: the newest page, or what came after [afterSeq].
  Future<HistoryPage> history(String otherId, {int? afterSeq});

  /// Sends [message] (whose [Message.clientMsgId] is set) to [otherId]. The
  /// outcome arrives as [MessageAcked] or [SendFailed].
  void send(String otherId, Message message);

  /// Marks messages up to [seq] as read; with [share] the other member is told.
  void markRead(String otherId, int seq, {required bool share});

  /// Tells [otherId] the user is typing (throttled).
  void typing(String otherId);

  /// Mutes or unmutes the conversation with [otherId].
  Future<void> setMuted(String otherId, {required bool muted});

  /// Deletes the conversation with [otherId] for the user only.
  Future<void> delete(String otherId);

  /// Unsends the user's message [messageId].
  Future<void> unsend(String messageId);

  /// Links to a message's photo, video or voice note. For the recipient of a
  /// view-once photo this uses up the one opening. Throws [ApiException]
  /// (410 once opened).
  Future<MediaLinks> mediaLinks(String messageId);

  /// Releases resources.
  void dispose();
}

/// A text WebSocket. Abstracted so tests can fake the server.
abstract interface class ChatSocket {
  /// Incoming text frames; done when the socket closes.
  Stream<String> get frames;

  /// Close code once closed (1008 means the server refused the member).
  int? get closeCode;

  /// Close reason once closed; `account-restricted` after a suspension or
  /// ban (ADR-0007).
  String? get closeReason;

  /// Sends a text frame.
  void send(String frame);

  /// Closes the socket.
  Future<void> close();
}

/// Opens a [ChatSocket] to [uri] with a bearer [token].
typedef ChatSocketConnector =
    Future<ChatSocket> Function(Uri uri, String token);

/// Opens real sockets (iOS and Android; web sign-in is not supported yet).
final chatSocketConnectorProvider = Provider<ChatSocketConnector>(
  (ref) => _IoChatSocket.connect,
);

/// The chat gateway, or null in demo mode.
final chatGatewayProvider = Provider<ChatGateway?>((ref) {
  if (!AppEnv.usesApi) return null;
  final gateway = ApiChatGateway(
    dio: ref.watch(dioProvider),
    auth: ref.watch(authRepositoryProvider),
    connector: ref.watch(chatSocketConnectorProvider),
    socketUri: Uri.parse(
      '${AppEnv.apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws/v1',
    ),
  );
  ref.onDispose(gateway.dispose);
  return gateway;
});

/// [ChatGateway] over the Orbit REST API and `/ws/v1`.
class ApiChatGateway implements ChatGateway {
  /// Creates a gateway.
  ApiChatGateway({
    required Dio dio,
    required AuthRepository auth,
    required ChatSocketConnector connector,
    required Uri socketUri,
    Duration Function(int failures)? backoff,
  }) : _dio = dio,
       _auth = auth,
       _connector = connector,
       _socketUri = socketUri,
       _backoff = backoff ?? _jittered;

  static final _random = Random();

  static Duration _jittered(int failures) =>
      reconnectDelay(failures, _random.nextInt);

  /// Wait before reconnect attempt number [failures] (1-based): exponential
  /// with full jitter (so clients don't reconnect in lockstep after an
  /// outage), between 0.5 s and [maxBackoff] + 0.5 s.
  static Duration reconnectDelay(int failures, int Function(int max) jitter) {
    final ceiling = min(
      maxBackoff.inMilliseconds,
      1000 * pow(2, min(failures - 1, 5)).toInt(),
    );
    return Duration(milliseconds: 500 + jitter(ceiling));
  }

  /// Application-level keep-alive, well inside the server's 70 s idle timeout.
  static const pingInterval = Duration(seconds: 25);

  /// Longest wait between reconnect attempts.
  static const maxBackoff = Duration(seconds: 30);

  static const _typingThrottle = Duration(seconds: 2);
  static const _policyViolation = 1008;

  final Dio _dio;
  final AuthRepository _auth;
  final ChatSocketConnector _connector;
  final Uri _socketUri;
  final Duration Function(int failures) _backoff;
  final _events = StreamController<ChatEvent>.broadcast();
  final _lastTyping = <String, DateTime>{};

  ChatSocket? _socket;
  StreamSubscription<String>? _subscription;
  Timer? _ping;
  Timer? _retry;
  var _wanted = false;
  var _connecting = false;
  var _failures = 0;

  @override
  Stream<ChatEvent> get events => _events.stream;

  /// Whether the live connection is open (for tests and diagnostics).
  @visibleForTesting
  bool get isConnected => _socket != null;

  @override
  void connect() {
    _wanted = true;
    unawaited(_open());
  }

  @override
  void disconnect() {
    _wanted = false;
    _retry?.cancel();
    unawaited(_closeSocket());
  }

  Future<void> _open() async {
    if (!_wanted || _connecting || _socket != null) return;
    _connecting = true;
    try {
      final token = await _auth.accessToken(forceRefresh: _failures == 1);
      if (token == null) {
        // Signed out: nothing to connect as, and nothing to retry.
        _wanted = false;
        return;
      }
      final socket = await _connector(_socketUri, token);
      if (!_wanted) {
        await socket.close();
        return;
      }
      _socket = socket;
      _failures = 0;
      _subscription = socket.frames.listen(
        _onFrame,
        onDone: () => _onClosed(socket),
        onError: (Object _) => _onClosed(socket),
      );
      _ping = Timer.periodic(pingInterval, (_) => _sendFrame({'type': 'ping'}));
      _events.add(const ChatConnected());
    } on Exception {
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _onClosed(ChatSocket socket) {
    if (!identical(socket, _socket)) return;
    _ping?.cancel();
    _socket = null;
    unawaited(_subscription?.cancel());
    if (socket.closeCode == _policyViolation) {
      // The server refused this member (no active account): don't retry.
      _wanted = false;
      if (socket.closeReason == 'account-restricted') {
        _events.add(const AccountRestricted());
      }
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _failures++;
    _retry?.cancel();
    _retry = Timer(_backoff(_failures), () => unawaited(_open()));
  }

  Future<void> _closeSocket() async {
    _ping?.cancel();
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
  }

  bool _sendFrame(Map<String, Object?> frame) {
    final socket = _socket;
    if (socket == null) return false;
    socket.send(jsonEncode(frame));
    return true;
  }

  void _onFrame(String raw) {
    final Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return;
    }
    final otherId = frame['with'] as String?;
    final event = switch (frame['type']) {
      'msg.new' => MessageReceived(
        otherId!,
        messageFromJson(frame['message'] as Map<String, dynamic>, otherId),
      ),
      'msg.ack' => MessageAcked(
        otherId!,
        messageFromJson(frame['message'] as Map<String, dynamic>, otherId),
      ),
      'msg.unsent' => MessageUnsent(
        otherId!,
        (frame['message'] as Map<String, dynamic>)['id'] as String,
      ),
      'msg.read' => ReadUpTo(otherId!, (frame['seq'] as num).toInt()),
      'typing' => OtherTyping(otherId!),
      'msg.viewed' => MessageViewed(otherId!, frame['messageId'] as String),
      'error' when frame['clientMsgId'] != null => SendFailed(
        frame['clientMsgId'] as String,
      ),
      _ => null,
    };
    if (event != null) _events.add(event);
  }

  @override
  Future<List<Conversation>> inbox() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/conversations');
    return [
      for (final row in response.data!.cast<Map<String, dynamic>>())
        _conversationFromJson(row),
    ];
  });

  Conversation _conversationFromJson(Map<String, dynamic> row) {
    final otherId = row['otherId'] as String;
    final last = row['last'] as Map<String, dynamic>?;
    return Conversation(
      profileId: otherId,
      messages: [if (last != null) messageFromJson(last, otherId)],
      unread: (row['unread'] as num).toInt(),
      muted: row['muted'] as bool,
    );
  }

  @override
  Future<HistoryPage> history(String otherId, {int? afterSeq}) => guardApi(
    () async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/conversations/$otherId/messages',
        queryParameters: {'after': ?afterSeq},
      );
      final body = response.data!;
      return HistoryPage(
        messages: [
          for (final m
              in (body['items'] as List<dynamic>).cast<Map<String, dynamic>>())
            messageFromJson(m, otherId),
        ],
        otherReadSeq: (body['otherReadSeq'] as num).toInt(),
        muted: body['muted'] as bool,
      );
    },
  );

  @override
  void send(String otherId, Message message) {
    final body = <String, Object?>{
      'clientMsgId': message.clientMsgId,
      'kind': message.kind.name.toUpperCase(),
      if (message.kind == MessageKind.text) 'text': message.text,
      'locationMinutes': ?message.locationMinutes,
      'mediaId': ?message.mediaId,
      'albumId': ?message.albumId,
      if (message.viewOnce) 'viewOnce': true,
    };
    if (_sendFrame({'type': 'msg.send', 'to': otherId, ...body})) return;
    unawaited(_sendOverRest(otherId, body, message.clientMsgId!));
  }

  Future<void> _sendOverRest(
    String otherId,
    Map<String, Object?> body,
    String clientMsgId,
  ) async {
    try {
      final response = await guardApi(
        () => _dio.post<Map<String, dynamic>>(
          '/conversations/$otherId/messages',
          data: body,
        ),
      );
      _events.add(
        MessageAcked(otherId, messageFromJson(response.data!, otherId)),
      );
    } on ApiException catch (e) {
      // Offline: stays pending and is resent on reconnect. Refused: failed.
      if (e.status != 0) _events.add(SendFailed(clientMsgId));
    }
  }

  @override
  void markRead(String otherId, int seq, {required bool share}) {
    final frame = {'type': 'read', 'with': otherId, 'seq': seq, 'share': share};
    if (_sendFrame(frame)) return;
    unawaited(_markReadOverRest(otherId, seq, share: share));
  }

  Future<void> _markReadOverRest(
    String otherId,
    int seq, {
    required bool share,
  }) async {
    try {
      await guardApi(
        () => _dio.post<void>(
          '/conversations/$otherId/read',
          data: {'seq': seq, 'share': share},
        ),
      );
    } on ApiException {
      // Unread counts are recomputed from the server on the next inbox load.
    }
  }

  @override
  void typing(String otherId) {
    final now = DateTime.now();
    final last = _lastTyping[otherId];
    if (last != null && now.difference(last) < _typingThrottle) return;
    if (_sendFrame({'type': 'typing', 'to': otherId})) {
      _lastTyping[otherId] = now;
    }
  }

  @override
  Future<void> setMuted(String otherId, {required bool muted}) => guardApi(
    () => _dio.put<void>(
      '/conversations/$otherId/mute',
      data: {'muted': muted},
    ),
  );

  @override
  Future<void> delete(String otherId) =>
      guardApi(() => _dio.delete<void>('/conversations/$otherId'));

  @override
  Future<void> unsend(String messageId) =>
      guardApi(() => _dio.post<void>('/messages/$messageId/unsend'));

  @override
  Future<MediaLinks> mediaLinks(String messageId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/messages/$messageId/media',
    );
    return MediaLinks.fromJson(response.data!);
  });

  @override
  void dispose() {
    disconnect();
    unawaited(_events.close());
  }
}

/// Parses a server message in the conversation with [otherId].
Message messageFromJson(Map<String, dynamic> json, String otherId) {
  return Message(
    id: json['id'] as String,
    seq: (json['seq'] as num).toInt(),
    clientMsgId: json['clientMsgId'] as String?,
    fromMe: json['senderId'] != otherId,
    kind: MessageKind.values.byName((json['kind'] as String).toLowerCase()),
    text: json['text'] as String? ?? '',
    sentAt: DateTime.parse(json['createdAt'] as String),
    unsent: json['unsent'] as bool? ?? false,
    locationMinutes: (json['locationMinutes'] as num?)?.toInt(),
    albumName: json['albumName'] as String?,
    mediaId: json['mediaId'] as String?,
    albumId: json['albumId'] as String?,
    viewOnce: json['viewOnce'] as bool? ?? false,
    viewed: json['viewed'] as bool? ?? false,
  );
}

class _IoChatSocket implements ChatSocket {
  _IoChatSocket(this._socket);

  static Future<ChatSocket> connect(Uri uri, String token) async {
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    return _IoChatSocket(socket);
  }

  final WebSocket _socket;

  @override
  Stream<String> get frames => _socket.where((f) => f is String).cast<String>();

  @override
  int? get closeCode => _socket.closeCode;

  @override
  String? get closeReason => _socket.closeReason;

  @override
  void send(String frame) => _socket.add(frame);

  @override
  Future<void> close() => _socket.close();
}
