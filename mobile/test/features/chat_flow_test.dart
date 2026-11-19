import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/attach_sheet.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/chat_items.dart';
import 'package:orbit/features/chat/presentation/composer.dart';
import 'package:orbit/features/chat/presentation/message_bubble.dart';
import 'package:orbit/features/chat/presentation/message_preview.dart';
import 'package:orbit/features/discovery/data/dummy_profiles.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/l10n/app_localizations.dart';

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

/// [chatItems] without the day separators, to test the rest on its own.
List<ChatItem> _bodyItems(List<Message> messages) =>
    chatItems(messages).where((i) => i is! DaySeparatorItem).toList();

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

/// Messages from Sam across local midnight (23:59 then 00:01).
class _SamAcrossMidnight extends DemoChatController {
  @override
  Map<String, Conversation> build() {
    return {
      ...super.build(),
      dummyProfiles[1].id: Conversation(
        profileId: dummyProfiles[1].id,
        messages: [
          Message(
            id: 'late',
            fromMe: false,
            kind: MessageKind.text,
            text: 'late one',
            sentAt: DateTime(2026, 11, 8, 23, 59),
          ),
          Message(
            id: 'early',
            fromMe: false,
            kind: MessageKind.text,
            text: 'early one',
            sentAt: DateTime(2026, 11, 9, 0, 1),
          ),
        ],
      ),
    };
  }
}

/// Whether a delivery tick with semantics [label] is on screen.
Finder _tick(String label) => find.byWidgetPredicate(
  (w) => w is Icon && w.semanticLabel == label,
);

OrbitTokens get _tokens => OrbitTokens.light;

Future<void> _showBubble(
  WidgetTester tester,
  Message message, {
  bool showReadReceipt = true,
  bool groupedWithNext = false,
  bool groupedWithPrevious = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildOrbitTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            profileId: 'bob',
            message: message,
            otherName: 'Bob',
            showReadReceipt: showReadReceipt,
            groupedWithNext: groupedWithNext,
            groupedWithPrevious: groupedWithPrevious,
          ),
        ),
      ),
    ),
  );
}

BorderRadiusDirectional _bubbleRadius(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.borderRadius! as BorderRadiusDirectional;
}

Message _mine(DeliveryStatus status, {DateTime? at}) => Message(
  id: 'm',
  fromMe: true,
  kind: MessageKind.text,
  text: 'hi there',
  status: status,
  sentAt: at ?? DateTime(2026, 11, 9, 14, 5),
);

Message _photo(
  String id, {
  bool fromMe = false,
  int minute = 0,
  bool viewOnce = false,
  DateTime? at,
}) => Message(
  id: id,
  fromMe: fromMe,
  kind: MessageKind.photo,
  mediaId: 'media-$id',
  viewOnce: viewOnce,
  sentAt: at ?? testNow.subtract(Duration(minutes: 60 - minute)),
);

/// Sam sent five photos one after the other.
class _SamSentFivePhotos extends DemoChatController {
  @override
  Map<String, Conversation> build() {
    return {
      ...super.build(),
      dummyProfiles[1].id: Conversation(
        profileId: dummyProfiles[1].id,
        messages: [
          for (var i = 0; i < 5; i++) _photo('p$i', minute: i),
        ],
      ),
    };
  }

  @override
  Future<MediaLinks> mediaLinks(String profileId, String messageId) async =>
      MediaLinks(
        url: 'https://x.test/$messageId/full',
        thumbUrl: 'https://x.test/$messageId/thumb',
        expiresAt: DateTime.utc(2030),
      );
}

/// Records what the chat screen asks to send.
class _RecordingChat extends DemoChatController {
  final sentMedia = <(MessageKind, Uint8List, bool)>[];

  @override
  void sendMedia(
    String profileId,
    MessageKind kind,
    PickedMedia media, {
    bool viewOnce = false,
  }) => sentMedia.add((kind, media.bytes, viewOnce));
}

class _ThreePhotosPicker implements MediaPicker {
  int limit = 0;

  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async => null;

  @override
  Future<List<PickedMedia>> pickPhotos({int limit = 10}) async {
    this.limit = limit;
    return [
      for (var i = 1; i <= 3; i++)
        PickedMedia(bytes: Uint8List.fromList([i]), contentType: 'image/jpeg'),
    ];
  }

  @override
  Future<PickedMedia?> pickVideo({required Duration maxDuration}) async => null;
}

class _NoUploads implements MediaRepository {
  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) => throw UnimplementedError();
}

class _NoVoice implements VoiceRecorder {
  @override
  Future<bool> start() async => false;

  @override
  Future<PickedMedia?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

Future<void> _openAttachSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Attach'));
  await tester.pumpAndSettle();
}

Future<void> _pumpComposer(
  WidgetTester tester,
  TextEditingController controller, {
  bool recording = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildOrbitTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Composer(
            controller: controller,
            onSend: () {},
            onAttach: () {},
            onVoiceStart: () {},
            onVoiceStop: () {},
            onVoiceCancel: () {},
            onTyping: () {},
            recording: recording,
          ),
        ),
      ),
    ),
  );
}

Future<void> openSamsChat(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await pumpOrbit(tester, overrides: overrides);
  await onboard(tester);
  await tapText(tester, 'Inbox');
  await tapText(tester, 'Sam');
}

Future<void> openChatWith(WidgetTester tester, String name) async {
  await pumpOrbit(tester);
  await onboard(tester);
  await tapText(tester, 'Inbox');
  await tapText(tester, name);
}

Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

void main() {
  group('chatItems', () {
    test('three consecutive waves from one sender become one run', () {
      final waves = [_wave('a'), _wave('b'), _wave('c')];

      final items = _bodyItems(waves);

      expect(items, hasLength(1));
      final run = items.single as WaveRunItem;
      expect(run.waves.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('a text between waves splits the run', () {
      final items = _bodyItems([
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
      final items = _bodyItems([
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

      final items = _bodyItems([_wave('a', fromMe: true), unsent]);

      expect(items.map((i) => i.runtimeType), [WaveRunItem, MessageItem]);
    });

    test('other messages stay single items in order', () {
      final items = _bodyItems([_text('a'), _text('b', fromMe: true)]);

      expect(items.whereType<MessageItem>().map((i) => i.message.id), [
        'a',
        'b',
      ]);
    });

    test('two photos within two minutes become a mosaic', () {
      final items = _bodyItems([_photo('a'), _photo('b', minute: 1)]);

      final mosaic = items.single as PhotoMosaicItem;
      expect(mosaic.photos.map((m) => m.id), ['a', 'b']);
    });

    test('a single photo stays a plain message', () {
      expect(_bodyItems([_photo('a')]).single, isA<MessageItem>());
    });

    test('a view-once photo, a gap, a sender or a text breaks a mosaic', () {
      final items = _bodyItems([
        _photo('a'),
        _photo('v', minute: 1, viewOnce: true),
        _photo('b', minute: 2),
        _photo('c', minute: 5),
        _photo('d', minute: 6, fromMe: true),
        _photo('e', minute: 7, fromMe: true),
        _text('t', fromMe: true, minute: 8),
        _photo('f', minute: 9, fromMe: true),
      ]);

      expect(items.map((i) => i.runtimeType), [
        MessageItem,
        MessageItem,
        MessageItem,
        MessageItem,
        PhotoMosaicItem,
        MessageItem,
        MessageItem,
      ]);
      expect((items[4] as PhotoMosaicItem).photos.map((m) => m.id), [
        'd',
        'e',
      ]);
    });

    test('photos either side of local midnight are not one mosaic', () {
      final items = chatItems([
        _photo('a', at: DateTime(2026, 11, 8, 23, 59)),
        _photo('b', at: DateTime(2026, 11, 9, 0, 1)),
      ]);

      expect(items.map((i) => i.runtimeType), [
        DaySeparatorItem,
        MessageItem,
        DaySeparatorItem,
        MessageItem,
      ]);
    });

    test('a mosaic groups with the messages around it', () {
      final items = _bodyItems([
        _text('a', fromMe: true),
        _photo('b', fromMe: true, minute: 1),
        _photo('c', fromMe: true, minute: 2),
        _text('d', fromMe: true, minute: 3),
      ]);

      final mosaic = items[1] as PhotoMosaicItem;
      expect(mosaic.groupedWithPrevious, isTrue);
      expect(mosaic.groupedWithNext, isTrue);
      expect((items[0] as MessageItem).groupedWithNext, isTrue);
      expect((items[2] as MessageItem).groupedWithPrevious, isTrue);
    });

    test('no messages gives no items', () {
      expect(_bodyItems(const []), isEmpty);
    });

    test('messages within two minutes group and only the last has a tail', () {
      final items = chatItems([
        _text('a', fromMe: true),
        _text('b', fromMe: true, minute: 2),
        _text('c', fromMe: true, minute: 5),
      ]).whereType<MessageItem>().toList();

      expect(items.map((i) => i.groupedWithPrevious), [false, true, false]);
      expect(items.map((i) => i.groupedWithNext), [true, false, false]);
    });

    test('a different sender or a wave breaks a group', () {
      final items = chatItems([
        _text('a', fromMe: true),
        _text('b'),
        _wave('w'),
        _text('c'),
      ]);

      final messages = items.whereType<MessageItem>().toList();
      expect(messages.any((i) => i.groupedWithNext), isFalse);
      expect(messages.any((i) => i.groupedWithPrevious), isFalse);
    });

    test('a day separator comes before the first message of each day', () {
      final items = chatItems([
        Message(
          id: 'a',
          fromMe: false,
          kind: MessageKind.text,
          sentAt: DateTime(2026, 11, 8, 23, 59),
        ),
        Message(
          id: 'b',
          fromMe: false,
          kind: MessageKind.text,
          sentAt: DateTime(2026, 11, 9, 0, 1),
        ),
      ]);

      expect(items.map((i) => i.runtimeType), [
        DaySeparatorItem,
        MessageItem,
        DaySeparatorItem,
        MessageItem,
      ]);
      expect((items[0] as DaySeparatorItem).localDay, DateTime(2026, 11, 8));
      expect((items[2] as DaySeparatorItem).localDay, DateTime(2026, 11, 9));
      expect((items[1] as MessageItem).groupedWithNext, isFalse);
      expect((items[3] as MessageItem).groupedWithPrevious, isFalse);
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
    expect(_tick('Sent'), findsOneWidget);

    await tester.pump(testReplyAfter);
    expect(find.text('Alex is typing…'), findsOneWidget);

    await tester.pump(testTypingFor);
    await tester.pumpAndSettle();
    expect(find.text('Hey! Nice to hear from you 🙂'), findsOneWidget);
    expect(_tick('Read'), findsWidgets);
    expect(find.text('Read'), findsNothing);
  });

  testWidgets('turning off read receipts shows grey ticks, not "Read"', (
    tester,
  ) async {
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

    expect(_tick('Read'), findsNothing);
    expect(_tick('Delivered'), findsWidgets);
  });

  testWidgets('bubble shows local time and read ticks', (tester) async {
    await _showBubble(
      tester,
      _mine(DeliveryStatus.read, at: DateTime(2026, 11, 9, 14, 5).toUtc()),
    );

    expect(find.textContaining('2:05'), findsOneWidget);
    expect(_tick('Read'), findsOneWidget);
    expect(tester.widget<Icon>(_tick('Read')).color, _tokens.readTick);
  });

  testWidgets('read receipts off shows grey ticks', (tester) async {
    await _showBubble(
      tester,
      _mine(DeliveryStatus.read),
      showReadReceipt: false,
    );

    expect(_tick('Read'), findsNothing);
    expect(
      tester.widget<Icon>(_tick('Delivered')).color,
      _tokens.tickMuted(_tokens.ownBubble),
    );
  });

  testWidgets('pending shows a clock and sent shows one tick', (tester) async {
    await _showBubble(tester, _mine(DeliveryStatus.pending));
    expect(find.byIcon(Icons.schedule), findsOneWidget);

    await _showBubble(tester, _mine(DeliveryStatus.sent));
    expect(_tick('Sent'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsOneWidget);
  });

  testWidgets('incoming bubbles show the time but no ticks', (tester) async {
    await _showBubble(
      tester,
      Message(
        id: 'i',
        fromMe: false,
        kind: MessageKind.text,
        text: 'yo',
        sentAt: DateTime(2026, 11, 9, 14, 5),
      ),
    );

    expect(find.textContaining('2:05'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('only the last bubble of a group has a tail', (tester) async {
    await _showBubble(
      tester,
      _mine(DeliveryStatus.sent),
      groupedWithNext: true,
    );
    expect(_bubbleRadius(tester).bottomEnd, const Radius.circular(18));

    await _showBubble(tester, _mine(DeliveryStatus.sent));
    expect(_bubbleRadius(tester).bottomEnd, const Radius.circular(6));
  });

  testWidgets('day separator uses local midnight', (tester) async {
    await pumpOrbit(
      tester,
      now: DateTime(2026, 11, 9, 0, 5),
      overrides: [
        chatProvider.overrideWith(_SamAcrossMidnight.new),
      ],
    );
    await onboard(tester);
    await tapText(tester, 'Inbox');
    await tapText(tester, 'Sam');

    final yesterday = tester.getTopLeft(find.text('Yesterday')).dy;
    final today = tester.getTopLeft(find.text('Today')).dy;
    expect(yesterday, lessThan(today));
    expect(find.text('late one'), findsOneWidget);
  });

  testWidgets('tapping the chat header opens the profile', (tester) async {
    await openChatWith(tester, 'Alex');

    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('Alex')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wave'), findsOneWidget);
  });

  testWidgets('the header shows typing while the member types', (tester) async {
    await openChatWith(tester, 'Alex');
    await sendMessage(tester, 'hi');

    await tester.pump(testReplyAfter);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('typing…')),
      findsOneWidget,
    );
    await tester.pump(testTypingFor);
    await tester.pumpAndSettle();
  });

  testWidgets('dayLabel names today, yesterday, weekdays and dates', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final now = DateTime(2026, 11, 9, 0, 5);

    expect(dayLabel(context, DateTime(2026, 11, 9), now), 'Today');
    expect(dayLabel(context, DateTime(2026, 11, 8), now), 'Yesterday');
    expect(dayLabel(context, DateTime(2026, 11, 5), now), 'Thursday');
    expect(dayLabel(context, DateTime(2026, 11, 2), now), 'Nov 2, 2026');
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

    await _openAttachSheet(tester);
    await tapText(tester, 'Share an album');
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

    await _openAttachSheet(tester);
    await tapText(tester, 'Share an album');
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

  group('composer', () {
    testWidgets('shows mic when empty and send when typing', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pumpComposer(tester, controller);

      expect(find.byTooltip('Record a voice note'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.byTooltip('Record a voice note'), findsNothing);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Record a voice note'), findsOneWidget);
    });

    testWidgets('the plus button has a tooltip', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pumpComposer(tester, controller);

      expect(find.byTooltip('Attach'), findsOneWidget);
    });

    testWidgets('field grows to five lines then scrolls', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pumpComposer(tester, controller);
      double height() => tester.getSize(find.byType(TextField)).height;
      Future<void> typeLines(int count) async {
        await tester.enterText(
          find.byType(TextField),
          List.filled(count, 'x').join('\n'),
        );
        await tester.pumpAndSettle();
      }

      final oneLine = height();
      await typeLines(3);
      final threeLines = height();
      await typeLines(5);
      final fiveLines = height();
      await typeLines(9);

      expect(threeLines, greaterThan(oneLine));
      expect(fiveLines, greaterThan(threeLines));
      expect(height(), fiveLines);
    });

    testWidgets('the swap is instant when animations are off', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpComposer(tester, controller);

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();

      expect(find.byTooltip('Record a voice note'), findsNothing);
    });

    testWidgets('while recording it offers discard and send', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pumpComposer(tester, controller, recording: true);

      expect(find.byTooltip('Discard recording'), findsOneWidget);
      expect(find.byTooltip('Stop and send'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('attach sheet', () {
    testWidgets('plus opens the attach sheet with six options', (
      tester,
    ) async {
      await openChatWith(tester, 'Alex');

      await _openAttachSheet(tester);

      expect(find.byType(AttachSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AttachSheet),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(6),
      );
      expect(AttachChoice.values, hasLength(6));
      for (final label in [
        'Photos (up to 10)',
        'Take a photo',
        'View-once photo',
        'Share an album',
        'Share live location',
        'Quick phrases',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('quick phrases fill the field', (tester) async {
      await openChatWith(tester, 'Alex');

      await _openAttachSheet(tester);
      await tapText(tester, 'Quick phrases');
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isNotEmpty,
      );
    });

    testWidgets('picking three photos sends three photo messages in order', (
      tester,
    ) async {
      final chat = _RecordingChat();
      final picker = _ThreePhotosPicker();
      await pumpOrbit(
        tester,
        overrides: [
          chatProvider.overrideWith(() => chat),
          mediaPickerProvider.overrideWithValue(picker),
          mediaRepositoryProvider.overrideWithValue(_NoUploads()),
          voiceRecorderProvider.overrideWithValue(_NoVoice()),
        ],
      );
      await onboard(tester);
      await tapText(tester, 'Inbox');
      await tapText(tester, 'Alex');

      await _openAttachSheet(tester);
      await tapText(tester, 'Photos (up to 10)');

      expect(picker.limit, 10);
      expect(chat.sentMedia.map((m) => m.$1), everyElement(MessageKind.photo));
      expect(chat.sentMedia.map((m) => m.$2.single), [1, 2, 3]);
      expect(chat.sentMedia.map((m) => m.$3), everyElement(isFalse));
    });
  });

  group('photo mosaic', () {
    Future<void> openMosaic(WidgetTester tester) => openSamsChat(
      tester,
      overrides: [chatProvider.overrideWith(_SamSentFivePhotos.new)],
    );

    testWidgets('five consecutive photos show a mosaic with +1', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openMosaic(tester);

      expect(find.text('+1'), findsOneWidget);
      for (var i = 1; i <= 4; i++) {
        expect(find.bySemanticsLabel('Photo $i of 5'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Photo 5 of 5'), findsNothing);
      expect(find.byType(MessageBubble), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tapping a tile opens the viewer at that photo', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openMosaic(tester);

      await tester.tap(find.bySemanticsLabel('Photo 2 of 5'));
      await tester.pumpAndSettle();

      final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
      expect(viewer.items, hasLength(5));
      expect(viewer.initialIndex, 1);
      expect(viewer.items[1].mediaId, 'media-p1');
      semantics.dispose();
    });

    testWidgets('tapping the +1 tile opens the viewer at the fourth photo', (
      tester,
    ) async {
      await openMosaic(tester);

      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();

      final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
      expect(viewer.initialIndex, 3);
    });
  });
}
