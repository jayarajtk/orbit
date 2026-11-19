import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/auth/auth_repository.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/data/chat_gateway.dart';
import 'package:orbit/features/chat/domain/message.dart';

import '../helpers/fake_api.dart';

/// A server-side socket the test drives.
class FakeSocket implements ChatSocket {
  final _incoming = StreamController<String>();

  /// Frames the app sent.
  final sent = <Map<String, dynamic>>[];

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Stream<String> get frames => _incoming.stream;

  @override
  void send(String frame) =>
      sent.add(jsonDecode(frame) as Map<String, dynamic>);

  @override
  Future<void> close() => _incoming.close();

  void receive(Map<String, Object?> frame) => _incoming.add(jsonEncode(frame));

  Future<void> drop(int code, [String? reason]) {
    closeCode = code;
    closeReason = reason;
    return _incoming.close();
  }
}

class FakeAuth implements AuthRepository {
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}

Map<String, Object?> messageJson({
  required String id,
  required int seq,
  required String sender,
  String? clientMsgId,
  String text = '',
}) => {
  'id': id,
  'conversationId': 'c1',
  'seq': seq,
  'senderId': sender,
  'clientMsgId': clientMsgId ?? 'srv-$id',
  'kind': 'TEXT',
  'text': text,
  'createdAt': '2026-11-17T12:00:00Z',
  'unsent': false,
};

/// A gateway wired to a fake server, reconnecting without delay.
class Harness {
  Harness({this.connectable = true}) {
    http = FakeAdapter(
      {
        'GET /conversations': (
          200,
          [
            {
              'otherId': 'bob',
              'displayName': 'Bob',
              'online': true,
              'muted': true,
              'unread': 3,
              'last': messageJson(id: 'm1', seq: 1, sender: 'bob', text: 'Hi'),
            },
          ],
        ),
        'GET /messages/m9/media': (
          200,
          {
            'kind': 'AUDIO',
            'url': 'https://storage.test/voice',
            'durationMs': 4000,
            'expiresAt': '2026-11-18T12:10:00Z',
          },
        ),
        'GET /messages/gone/media': (
          410,
          {'type': 'urn:orbit:problem:view-once-opened', 'status': 410},
        ),
        'GET /conversations/bob/messages': (
          200,
          {
            'items': [
              messageJson(id: 'm1', seq: 1, sender: 'bob', text: 'Hi'),
              messageJson(id: 'm2', seq: 2, sender: 'me', text: 'Hey'),
            ],
            'otherReadSeq': 2,
            'muted': false,
          },
        ),
      },
      handlers: {
        // Echo the client id so the reply acknowledges the pending message.
        'POST /conversations/bob/messages': (options) {
          final body = options.data as Map<String, Object?>;
          return (
            201,
            messageJson(
              id: 'rest-1',
              seq: 3,
              sender: 'me',
              clientMsgId: body['clientMsgId']! as String,
              text: body['text']! as String,
            ),
          );
        },
      },
    );
    gateway = ApiChatGateway(
      dio: dioWith(http),
      auth: FakeAuth(),
      connector: (uri, token) async {
        if (!connectable) throw const SocketUnavailable();
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
      socketUri: Uri.parse('ws://api.test/ws/v1'),
      backoff: (_) => Duration.zero,
    );
    events = [];
    gateway.events.listen(events.add);
  }

  late final FakeAdapter http;
  late final ApiChatGateway gateway;
  late final List<ChatEvent> events;
  final sockets = <FakeSocket>[];
  bool connectable;

  Future<FakeSocket> connected() async {
    gateway.connect();
    await pumpEventQueue();
    return sockets.last;
  }
}

class SocketUnavailable implements Exception {
  const SocketUnavailable();
}

Message pending(String clientMsgId, String text) => Message(
  id: clientMsgId,
  clientMsgId: clientMsgId,
  fromMe: true,
  kind: MessageKind.text,
  text: text,
  sentAt: DateTime.utc(2026, 11, 17, 12),
  status: DeliveryStatus.pending,
);

void main() {
  late Harness app;

  tearDown(() => app.gateway.dispose());

  test('reads the inbox and history as seen by the user', () async {
    app = Harness();

    final inbox = await app.gateway.inbox();
    final page = await app.gateway.history('bob');

    expect(inbox.single.profileId, 'bob');
    expect(inbox.single.unread, 3);
    expect(inbox.single.muted, isTrue);
    expect(inbox.single.last!.fromMe, isFalse);
    expect(page.messages.map((m) => (m.seq, m.fromMe)), [
      (1, false),
      (2, true),
    ]);
    expect(page.otherReadSeq, 2);
  });

  test('asks only for newer messages when catching up', () async {
    app = Harness();

    await app.gateway.history('bob', afterSeq: 7);

    expect(app.http.requests.last.queryParameters, {'after': 7});
  });

  test('turns server frames into events', () async {
    app = Harness();
    final socket = await app.connected();

    socket
      ..receive({
        'type': 'msg.new',
        'with': 'bob',
        'message': messageJson(id: 'm9', seq: 9, sender: 'bob', text: 'Yo'),
      })
      ..receive({'type': 'msg.read', 'with': 'bob', 'seq': 9})
      ..receive({'type': 'typing', 'with': 'bob'})
      ..receive({
        'type': 'msg.unsent',
        'with': 'bob',
        'message': messageJson(id: 'm9', seq: 9, sender: 'bob'),
      })
      ..receive({
        'type': 'error',
        'code': 'invalid-message',
        'clientMsgId': 'x',
      })
      ..receive({'type': 'error', 'code': 'bad-frame'})
      ..receive({'type': 'pong'});
    await pumpEventQueue();

    expect(app.events, [
      isA<ChatConnected>(),
      isA<MessageReceived>()
          .having((e) => e.otherId, 'otherId', 'bob')
          .having((e) => e.message.text, 'text', 'Yo')
          .having((e) => e.message.fromMe, 'fromMe', isFalse),
      isA<ReadUpTo>().having((e) => e.seq, 'seq', 9),
      isA<OtherTyping>().having((e) => e.otherId, 'otherId', 'bob'),
      isA<MessageUnsent>().having((e) => e.messageId, 'messageId', 'm9'),
      isA<SendFailed>().having((e) => e.clientMsgId, 'clientMsgId', 'x'),
    ]);
  });

  test('sends over the socket while connected', () async {
    app = Harness();
    final socket = await app.connected();

    app.gateway
      ..send('bob', pending('c1', 'Hello'))
      ..markRead('bob', 4, share: false)
      ..typing('bob')
      ..typing('bob');

    expect(socket.sent, [
      {
        'type': 'msg.send',
        'to': 'bob',
        'clientMsgId': 'c1',
        'kind': 'TEXT',
        'text': 'Hello',
      },
      {'type': 'read', 'with': 'bob', 'seq': 4, 'share': false},
      {'type': 'typing', 'to': 'bob'},
    ]);
    expect(app.http.requests, isEmpty);
  });

  test('sends over REST while disconnected and reports the ack', () async {
    app = Harness(connectable: false);

    app.gateway.send('bob', pending('c1', 'Over HTTP'));
    await pumpEventQueue();

    expect(app.http.requests.single.data, {
      'clientMsgId': 'c1',
      'kind': 'TEXT',
      'text': 'Over HTTP',
    });
    expect(
      app.events.single,
      isA<MessageAcked>()
          .having((e) => e.message.id, 'id', 'rest-1')
          .having((e) => e.message.clientMsgId, 'clientMsgId', 'c1'),
    );
  });

  test('reconnects after a drop and announces it', () async {
    app = Harness();
    final first = await app.connected();

    await first.drop(1006);
    await pumpEventQueue();

    expect(app.sockets, hasLength(2));
    expect(app.events.whereType<ChatConnected>(), hasLength(2));
    expect(app.gateway.isConnected, isTrue);
  });

  test('stops when the server refuses the member', () async {
    app = Harness();
    final first = await app.connected();

    await first.drop(1008);
    await pumpEventQueue();

    expect(app.sockets, hasLength(1));
    expect(app.gateway.isConnected, isFalse);
  });

  test('reports a suspension or ban when the server says so', () async {
    app = Harness();
    final first = await app.connected();

    await first.drop(1008, 'account-restricted');
    await pumpEventQueue();

    expect(app.events.whereType<AccountRestricted>(), hasLength(1));
    expect(app.sockets, hasLength(1));
  });

  test('a refusal for another reason is not a restriction', () async {
    app = Harness();
    final first = await app.connected();

    await first.drop(1008, 'account-required');
    await pumpEventQueue();

    expect(app.events.whereType<AccountRestricted>(), isEmpty);
  });

  test('stays closed after disconnect', () async {
    app = Harness();
    await app.connected();

    app.gateway.disconnect();
    await pumpEventQueue();

    expect(app.sockets, hasLength(1));
    expect(app.gateway.isConnected, isFalse);
  });

  test('backs off exponentially up to the cap', () {
    int noJitter(int max) => 0;
    int fullJitter(int max) => max - 1;

    expect(ApiChatGateway.reconnectDelay(1, noJitter).inMilliseconds, 500);
    expect(ApiChatGateway.reconnectDelay(1, fullJitter).inMilliseconds, 1499);
    expect(ApiChatGateway.reconnectDelay(3, fullJitter).inMilliseconds, 4499);
    expect(
      ApiChatGateway.reconnectDelay(20, fullJitter),
      ApiChatGateway.maxBackoff + const Duration(milliseconds: 499),
    );
  });

  test('media and album fields travel in both directions', () async {
    app = Harness();
    final socket = await app.connected();

    app.gateway
      ..send(
        'bob',
        Message(
          id: 'c2',
          clientMsgId: 'c2',
          fromMe: true,
          kind: MessageKind.photo,
          sentAt: DateTime.utc(2026),
          mediaId: 'media-1',
          viewOnce: true,
        ),
      )
      ..send(
        'bob',
        Message(
          id: 'c3',
          clientMsgId: 'c3',
          fromMe: true,
          kind: MessageKind.album,
          sentAt: DateTime.utc(2026),
          albumId: 'album-1',
        ),
      );
    socket
      ..receive({
        'type': 'msg.new',
        'with': 'bob',
        'message': {
          ...messageJson(id: 'm9', seq: 9, sender: 'bob'),
          'kind': 'VOICE',
          'mediaId': 'media-9',
          'viewOnce': false,
        },
      })
      ..receive({'type': 'msg.viewed', 'with': 'bob', 'messageId': 'm2'});
    await pumpEventQueue();

    expect(socket.sent[0], {
      'type': 'msg.send',
      'to': 'bob',
      'clientMsgId': 'c2',
      'kind': 'PHOTO',
      'mediaId': 'media-1',
      'viewOnce': true,
    });
    expect(socket.sent[1], containsPair('albumId', 'album-1'));
    final received = app.events.whereType<MessageReceived>().single.message;
    expect(received.kind, MessageKind.voice);
    expect(received.mediaId, 'media-9');
    expect(
      app.events.whereType<MessageViewed>().single.messageId,
      'm2',
    );
  });

  test('fetches media links, and reports a used view-once photo', () async {
    app = Harness();

    final links = await app.gateway.mediaLinks('m9');

    expect(links.url, 'https://storage.test/voice');
    expect(links.durationMs, 4000);
    await expectLater(
      app.gateway.mediaLinks('gone'),
      throwsA(
        isA<ApiException>().having((e) => e.status, 'status', 410),
      ),
    );
  });
}
