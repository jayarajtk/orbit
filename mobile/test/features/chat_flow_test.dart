import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/chat_items.dart';
import 'package:orbit/features/discovery/data/dummy_profiles.dart';

import '../helpers/pump_app.dart';

class _InMemoryAlbums implements AlbumRepository {
  final List<Album> _albums = [];

  @override
  Future<List<Album>> mine() async => List.of(_albums);

  @override
  Future<String> create(String name) async {
    final id = 'new-${_albums.length}';
    _albums.add(Album(id: id, name: name, photoCount: 0, isPrivate: true));
    return id;
  }

  @override
  Future<void> addPhoto(String albumId, String mediaId) async {}

  @override
  Future<void> share(
    String albumId,
    String profileId,
    AlbumAccess access, {
    required bool viewOnce,
  }) async {}

  @override
  Future<void> revoke(String albumId, String profileId) async {}

  @override
  Future<List<SharedAlbum>> sharedWithMe() async => const [];

  @override
  Future<OpenedAlbum> open(String albumId) => throw UnimplementedError();
}

Message _wave(String id, {bool fromMe = false, int minute = 0}) => Message(
  id: id,
  fromMe: fromMe,
  kind: MessageKind.wave,
  sentAt: testNow.subtract(Duration(minutes: 60 - minute)),
);

Message _text(String id, {bool fromMe = false, int minute = 0}) => Message(
  id: id,
  fromMe: fromMe,
  kind: MessageKind.text,
  text: 'hello $id',
  sentAt: testNow.subtract(Duration(minutes: 60 - minute)),
);

/// Demo chat where Sam has waved at the user three times in a row.
class _SamWavedThrice extends DemoChatController {
  @override
  Map<String, Conversation> build() {
    return {
      ...super.build(),
      dummyProfiles[1].id: Conversation(
        profileId: dummyProfiles[1].id,
        messages: [
          for (var i = 0; i < 3; i++) _wave('w$i', minute: i),
        ],
      ),
    };
  }
}

Future<void> openChatWith(WidgetTester tester, String name) async {
  await pumpOrbit(tester);
  await onboard(tester);
  await tapText(tester, 'Inbox');
  await tapText(tester, name);
}

Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

void main() {
  group('chatItems', () {
    test('three consecutive waves from one sender become one run', () {
      final waves = [_wave('a'), _wave('b'), _wave('c')];

      final items = chatItems(waves);

      expect(items, hasLength(1));
      final run = items.single as WaveRunItem;
      expect(run.waves.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('a text between waves splits the run', () {
      final items = chatItems([
        _wave('a'),
        _wave('b'),
        _text('t'),
        _wave('c'),
      ]);

      expect(items.map((i) => i.runtimeType), [
        WaveRunItem,
        MessageItem,
        WaveRunItem,
      ]);
      expect((items[0] as WaveRunItem).waves, hasLength(2));
      expect((items[2] as WaveRunItem).waves, hasLength(1));
    });

    test('waves from different senders are separate runs', () {
      final items = chatItems([
        _wave('a'),
        _wave('b', fromMe: true),
        _wave('c', fromMe: true),
      ]);

      expect(items, hasLength(2));
      expect((items[0] as WaveRunItem).waves, hasLength(1));
      expect((items[1] as WaveRunItem).waves, hasLength(2));
    });

    test('an unsent wave is not counted in a run', () {
      final unsent = Message(
        id: 'u',
        fromMe: true,
        kind: MessageKind.wave,
        sentAt: testNow,
        unsent: true,
      );

      final items = chatItems([_wave('a', fromMe: true), unsent]);

      expect(items.map((i) => i.runtimeType), [WaveRunItem, MessageItem]);
    });

    test('other messages stay single items in order', () {
      final items = chatItems([_text('a'), _text('b', fromMe: true)]);

      expect(items.whereType<MessageItem>().map((i) => i.message.id), [
        'a',
        'b',
      ]);
    });

    test('no messages gives no items', () {
      expect(chatItems(const []), isEmpty);
    });
  });

  testWidgets('opening a chat clears its unread count', (tester) async {
    await openChatWith(tester, 'Alex');
    expect(find.text("There's a new gym near the river"), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNothing);
  });

  testWidgets('a dummy member types, then replies, and reads yours', (
    tester,
  ) async {
    await openChatWith(tester, 'Alex');

    await sendMessage(tester, 'Want to climb on Saturday');
    expect(find.text('Want to climb on Saturday'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);

    await tester.pump(testReplyAfter);
    expect(find.text('Alex is typing…'), findsOneWidget);

    await tester.pump(testTypingFor);
    await tester.pumpAndSettle();
    expect(find.text('Hey! Nice to hear from you 🙂'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('turning off read receipts hides "Read"', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');
    await tapText(tester, 'Read receipts');
    await tapText(tester, 'Inbox');
    await tapText(tester, 'Alex');

    await sendMessage(tester, 'hello');
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsNothing);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('own messages can be unsent', (tester) async {
    await openChatWith(tester, 'Alex');
    await sendMessage(tester, 'oops wrong chat');

    await tester.longPress(find.text('oops wrong chat'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Unsend');

    expect(find.text('oops wrong chat'), findsNothing);
    expect(find.text('This message was unsent'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();
  });

  testWidgets('sharing an album posts a card in the chat', (tester) async {
    await openChatWith(tester, 'Alex');

    await tester.tap(find.byTooltip('Share an album'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Travel');
    await tapText(tester, 'Share album');

    expect(find.text('You shared “Travel”'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();
    expect(find.text('Thanks for sharing — great pics!'), findsOneWidget);
  });

  testWidgets('sharing with no albums offers to create one', (tester) async {
    await pumpOrbit(
      tester,
      overrides: [
        albumRepositoryProvider.overrideWithValue(_InMemoryAlbums()),
      ],
    );
    await onboard(tester);
    await tapText(tester, 'Inbox');
    await tapText(tester, 'Alex');

    await tester.tap(find.byTooltip('Share an album'));
    await tester.pumpAndSettle();
    expect(
      find.text("You don't have any albums yet. Create one to share it."),
      findsOneWidget,
    );

    await tapText(tester, 'Create album');
    await tester.enterText(find.byType(TextField), 'Weekend');
    await tapText(tester, 'Create');

    expect(find.text('Weekend'), findsOneWidget);
    final share = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Share album'),
    );
    expect(share.onPressed, isNotNull);
  });

  testWidgets('waving from a profile starts a conversation', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Omar 32');

    await tapText(tester, 'Wave');
    expect(find.text('You waved at Omar'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Inbox');
    expect(find.text('Hey, thanks for the wave! 👋'), findsOneWidget);
  });

  testWidgets('chat shows "Sam waved ×3"', (tester) async {
    await pumpOrbit(
      tester,
      overrides: [chatProvider.overrideWith(_SamWavedThrice.new)],
    );
    await onboard(tester);
    await tapText(tester, 'Inbox');
    await tapText(tester, 'Sam');

    expect(find.text('Sam waved ×3'), findsOneWidget);
    expect(find.text('Sam waved at you'), findsNothing);
  });
}
