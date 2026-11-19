import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/account_restriction.dart';
import 'package:orbit/features/chat/data/chat_gateway.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/live_chat_controller.dart';
import 'package:orbit/features/chat/presentation/wave_limit.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';

import '../helpers/fake_chat_gateway.dart';

final DateTime testNow = chatGatewayNow;

final photo = PickedMedia(
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/jpeg',
);

class Harness {
  Harness() {
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => testNow),
        chatGatewayProvider.overrideWithValue(gateway),
        chatProvider.overrideWith(LiveChatController.new),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
    );
  }

  final gateway = FakeChatGateway();
  final media = FakeMediaRepository();
  late final ProviderContainer container;

  ChatController get chat => container.read(chatProvider.notifier);

  Map<String, Conversation> get all => container.read(chatProvider);

  Conversation get bob => all['bob']!;

  Set<String> get typing => container.read(typingProvider);

  /// Starts chat and lets the inbox load.
  Future<void> start(WidgetTester tester) async {
    container.read(chatProvider);
    await tester.pump();
  }

  /// Sends [text] and returns its client id.
  String send(String text) {
    chat.send('bob', text);
    return gateway.sent.last.$2.clientMsgId!;
  }

  void dispose() {
    container.dispose();
    gateway.dispose();
  }
}

void main() {
  testWidgets('connects and loads the inbox, then history on open', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    expect(app.gateway.connects, 1);
    expect(app.bob.unread, 1);
    expect(app.bob.last!.text, 'Hi');

    app.gateway.historyResult = HistoryPage(
      messages: [
        stored('m1', 1, fromMe: false, text: 'Hi'),
        stored('m2', 2, fromMe: true, text: 'Hey'),
      ],
      otherReadSeq: 2,
      muted: true,
    );
    await app.chat.open('bob');

    expect(app.bob.messages.map((m) => m.id), ['m1', 'm2']);
    expect(app.bob.last!.status, DeliveryStatus.read);
    expect(app.bob.muted, isTrue);
    app.dispose();
  });

  testWidgets('reconnects once a suspended or banned member is reinstated', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);
    final restriction = app.container.read(accountRestrictedProvider.notifier);

    app.gateway.emit(const AccountRestricted());
    await tester.pump();
    expect(app.container.read(accountRestrictedProvider), isTrue);
    restriction.clear();

    expect(app.gateway.connects, 2);
    restriction.clear();
    expect(app.gateway.connects, 2, reason: 'only when the flag is lifted');
    app.dispose();
  });

  testWidgets('a sent message is pending until acked, then read', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    final clientMsgId = app.send('  Hello  ');
    expect(app.bob.last!.status, DeliveryStatus.pending);
    expect(app.bob.last!.text, 'Hello');
    expect(app.bob.last!.canUnsend(testNow), isFalse);

    app.gateway.emit(
      MessageAcked(
        'bob',
        stored('m2', 2, fromMe: true, text: 'Hello', clientMsgId: clientMsgId),
      ),
    );
    await tester.pump();
    expect(app.bob.messages.map((m) => m.id), ['m1', 'm2']);
    expect(app.bob.last!.status, DeliveryStatus.sent);

    app.gateway.emit(const ReadUpTo('bob', 2));
    await tester.pump();
    expect(app.bob.last!.status, DeliveryStatus.read);
    app.dispose();
  });

  testWidgets('blank messages are not sent', (tester) async {
    final app = Harness();
    await app.start(tester);

    app.chat.send('bob', '   ');

    expect(app.gateway.sent, isEmpty);
    app.dispose();
  });

  testWidgets('typing shows until a message arrives or it times out', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    app.gateway.emit(const OtherTyping('bob'));
    await tester.pump();
    expect(app.typing, contains('bob'));

    app.gateway.emit(
      MessageReceived('bob', stored('m2', 2, fromMe: false, text: 'Yo')),
    );
    await tester.pump();
    expect(app.typing, isEmpty);
    expect(app.bob.unread, 2);
    expect(app.bob.last!.text, 'Yo');

    app.gateway.emit(const OtherTyping('bob'));
    await tester.pump();
    await tester.pump(LiveChatController.typingTimeout);
    expect(app.typing, isEmpty);
    app.dispose();
  });

  testWidgets('a repeated delivery is not counted twice', (tester) async {
    final app = Harness();
    await app.start(tester);
    final message = stored('m2', 2, fromMe: false, text: 'Yo');

    app.gateway
      ..emit(MessageReceived('bob', message))
      ..emit(MessageReceived('bob', message));
    await tester.pump();

    expect(app.bob.unread, 2);
    expect(app.bob.messages, hasLength(2));
    app.dispose();
  });

  testWidgets('reading clears unread and shares the position', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    app.chat.markRead('bob');

    expect(app.bob.unread, 0);
    expect(app.gateway.reads, [('bob', 1, true)]);
    app.dispose();
  });

  testWidgets('a refused message fails and is retried with the same id', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    final clientMsgId = app.send('Hello');
    app.gateway.emit(SendFailed(clientMsgId));
    await tester.pump();
    expect(app.bob.last!.status, DeliveryStatus.failed);

    app.chat.retry('bob', app.bob.last!.id);

    expect(app.bob.last!.status, DeliveryStatus.pending);
    expect(app.gateway.sent.last.$2.clientMsgId, clientMsgId);
    expect(app.gateway.sent, hasLength(2));
    app.dispose();
  });

  testWidgets('a refused wave disappears and blocks the button', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);
    app.chat.wave('bob');
    final wave = app.gateway.sent.last.$2;
    final retryAt = testNow.add(const Duration(hours: 5));
    expect(app.bob.last!.kind, MessageKind.wave);

    app.gateway.emit(
      SendFailed(
        wave.clientMsgId!,
        reason: SendFailure.waveLimit,
        retryAt: retryAt,
      ),
    );
    await tester.pump();

    expect(app.bob.messages.map((m) => m.kind), [MessageKind.text]);
    expect(app.container.read(waveLimitProvider('bob')), retryAt);
    expect(app.container.read(waveRefusalProvider)?.retryAt, retryAt);
    app.dispose();
  });

  testWidgets('after a reconnect it catches up and resends pending', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);
    app.gateway.emit(const ChatConnected());
    await tester.pump();
    await app.chat.open('bob');
    final clientMsgId = app.send('Hello');
    app.gateway.historyResult = HistoryPage(
      messages: [stored('m2', 2, fromMe: false, text: 'Missed')],
      otherReadSeq: 0,
      muted: false,
    );

    app.gateway.emit(const ChatConnected());
    await tester.pump();

    expect(app.gateway.historyCalls.last, ('bob', 1));
    expect(app.bob.messages.map((m) => m.text), ['Hi', 'Missed', 'Hello']);
    expect(app.gateway.sent.last.$2.clientMsgId, clientMsgId);
    expect(app.gateway.sent, hasLength(2));
    app.dispose();
  });

  testWidgets('unsend is optimistic and goes to the server', (tester) async {
    final app = Harness();
    await app.start(tester);
    app.gateway.emit(
      MessageReceived('bob', stored('m2', 2, fromMe: true, text: 'Oops')),
    );
    await tester.pump();

    expect(app.chat.unsend('bob', 'm2'), isTrue);
    expect(app.bob.last!.unsent, isTrue);
    expect(app.chat.unsend('bob', 'm1'), isFalse);
    await tester.pump();
    expect(app.gateway.unsent, ['m2']);
    app.dispose();
  });

  testWidgets('mute reverts when the server cannot be reached', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);
    app.gateway.failMute = true;

    app.chat.toggleMute('bob');
    expect(app.bob.muted, isTrue);
    await tester.pump();

    expect(app.bob.muted, isFalse);
    app.dispose();
  });

  testWidgets('delete reaches the server only after the undo window', (
    tester,
  ) async {
    final app = Harness();
    await app.start(tester);

    final removed = app.chat.delete('bob')!;
    expect(app.all, isNot(contains('bob')));
    app.chat.restore(removed);
    await tester.pump(LiveChatController.deleteGrace * 2);
    expect(app.all, contains('bob'));
    expect(app.gateway.deleted, isEmpty);

    app.chat.delete('bob');
    await tester.pump(LiveChatController.deleteGrace);
    expect(app.gateway.deleted, ['bob']);
    app.dispose();
  });

  group('media', () {
    testWidgets('a photo is uploaded, then sent with its media id', (
      tester,
    ) async {
      final app = Harness();
      await app.start(tester);

      app.chat.sendMedia('bob', MessageKind.photo, photo, viewOnce: true);
      expect(app.bob.last!.kind, MessageKind.photo);
      expect(app.bob.last!.status, DeliveryStatus.pending);
      await tester.pump();

      expect(app.media.uploads.single.$1, MediaPurpose.chatPhoto);
      final sent = app.gateway.sent.single.$2;
      expect(sent.mediaId, 'media-1');
      expect(sent.viewOnce, isTrue);
      expect(app.bob.last!.mediaId, 'media-1');
      app.dispose();
    });

    testWidgets('voice notes go up as voice notes with their length', (
      tester,
    ) async {
      final app = Harness();
      await app.start(tester);

      app.chat.sendMedia(
        'bob',
        MessageKind.voice,
        PickedMedia(
          bytes: Uint8List(4),
          contentType: 'audio/mp4',
          durationMs: 3200,
        ),
        viewOnce: true,
      );
      await tester.pump();

      expect(app.media.uploads.single, (
        MediaPurpose.voiceNote,
        'audio/mp4',
        3200,
      ));
      expect(app.gateway.sent.single.$2.viewOnce, isFalse);
      app.dispose();
    });

    testWidgets('a failed upload can be retried', (tester) async {
      final app = Harness();
      await app.start(tester);
      app.media.fail = true;

      app.chat.sendMedia('bob', MessageKind.photo, photo);
      await tester.pump();
      expect(app.bob.last!.status, DeliveryStatus.failed);
      expect(app.gateway.sent, isEmpty);

      app.media.fail = false;
      app.chat.retry('bob', app.bob.last!.id);
      await tester.pump();
      expect(app.gateway.sent.single.$2.mediaId, 'media-1');
      app.dispose();
    });

    testWidgets('media still uploading is not resent on reconnect', (
      tester,
    ) async {
      final app = Harness();
      await app.start(tester);
      app.media.gate = Completer<void>();

      app.chat.sendMedia('bob', MessageKind.photo, photo);
      app.gateway.emit(const ChatConnected());
      await tester.pump();
      expect(app.gateway.sent, isEmpty);

      app.media.gate!.complete();
      await tester.pump();
      expect(app.gateway.sent.single.$2.mediaId, 'media-1');
      app.dispose();
    });

    testWidgets('view-once photos are marked opened on both sides', (
      tester,
    ) async {
      final app = Harness();
      await app.start(tester);
      app.gateway
        ..emit(
          MessageReceived(
            'bob',
            Message(
              id: 'in-1',
              seq: 2,
              fromMe: false,
              kind: MessageKind.photo,
              sentAt: testNow,
              mediaId: 'm',
              viewOnce: true,
            ),
          ),
        )
        ..emit(
          MessageAcked(
            'bob',
            Message(
              id: 'out-1',
              seq: 3,
              clientMsgId: 'c',
              fromMe: true,
              kind: MessageKind.photo,
              sentAt: testNow,
              mediaId: 'n',
              viewOnce: true,
            ),
          ),
        );
      await tester.pump();

      await app.chat.mediaLinks('bob', 'in-1');
      app.gateway.emit(const MessageViewed('bob', 'out-1'));
      await tester.pump();

      final byId = {for (final m in app.bob.messages) m.id: m};
      expect(byId['in-1']!.viewed, isTrue);
      expect(byId['out-1']!.viewed, isTrue);
      app.dispose();
    });

    testWidgets('album shares carry the album id', (tester) async {
      final app = Harness();
      await app.start(tester);

      app.chat.shareAlbum('bob', 'Summer', albumId: 'album-1');

      final sent = app.gateway.sent.single.$2;
      expect(sent.kind, MessageKind.album);
      expect(sent.albumId, 'album-1');
      app.dispose();
    });
  });
}
