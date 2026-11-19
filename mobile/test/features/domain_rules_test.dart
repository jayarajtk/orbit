import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/domain/reply_bot.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/message_preview.dart';
import 'package:orbit/features/discovery/data/dummy_profiles.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/onboarding/domain/age_policy.dart';

void main() {
  group('AgePolicy', () {
    final today = DateTime(2026, 11, 9);

    test('turning 18 today counts as an adult', () {
      expect(AgePolicy.isAdult(DateTime(2008, 11, 9), today), isTrue);
    });

    test('turning 18 tomorrow does not', () {
      expect(AgePolicy.isAdult(DateTime(2008, 11, 10), today), isFalse);
    });

    test('leap-day birthdays turn over on March 1', () {
      final born = DateTime(2008, 2, 29);
      expect(AgePolicy.isAdult(born, DateTime(2026, 2, 28)), isFalse);
      expect(AgePolicy.isAdult(born, DateTime(2026, 3)), isTrue);
    });
  });

  group('DiscoveryFilters', () {
    Profile byName(String name) =>
        dummyProfiles.firstWhere((p) => p.name == name);

    test('defaults match everyone', () {
      const filters = DiscoveryFilters();
      expect(dummyProfiles.every(filters.matches), isTrue);
      expect(filters.isActive, isFalse);
    });

    test('age range is inclusive', () {
      const filters = DiscoveryFilters(minAge: 27, maxAge: 27);
      expect(filters.matches(byName('Alex')), isTrue);
      expect(filters.matches(byName('Sam')), isFalse);
    });

    test('looking-for matches any overlap', () {
      const filters = DiscoveryFilters(lookingFor: {LookingFor.networking});
      expect(filters.matches(byName('Theo')), isTrue);
      expect(filters.matches(byName('Alex')), isFalse);
    });

    test('a distance limit excludes members who hide their distance', () {
      const filters = DiscoveryFilters(maxDistanceKm: 5);
      expect(filters.matches(byName('Mika')), isFalse);
      expect(filters.matches(byName('Alex')), isTrue);
      expect(filters.matches(byName('Rafa')), isFalse);
    });

    test('photo filter skips members without photos', () {
      const filters = DiscoveryFilters(photoOnly: true);
      expect(filters.matches(byName('Rui')), isFalse);
    });
  });

  group('Message.canUnsend', () {
    final sent = DateTime(2026, 11, 9, 12);
    final mine = Message(
      id: 'm1',
      fromMe: true,
      kind: MessageKind.text,
      sentAt: sent,
    );

    test('allowed within 10 minutes', () {
      expect(mine.canUnsend(sent.add(const Duration(minutes: 10))), isTrue);
    });

    test('refused after 10 minutes, or for incoming messages', () {
      expect(mine.canUnsend(sent.add(const Duration(minutes: 11))), isFalse);
      final theirs = Message(
        id: 'm2',
        fromMe: false,
        kind: MessageKind.text,
        sentAt: sent,
      );
      expect(theirs.canUnsend(sent), isFalse);
    });
  });

  group('ReplyBot', () {
    test('answers questions differently from statements', () {
      expect(
        ReplyBot.replyTo('How are you?', 0),
        isNot(ReplyBot.replyTo('Hi there', 0)),
      );
    });

    test('is deterministic', () {
      expect(ReplyBot.replyTo('hi', 3), ReplyBot.replyTo('hi', 3));
    });
  });

  group('ChatController', () {
    late DateTime now;
    late ProviderContainer container;

    setUp(() {
      now = DateTime(2026, 11, 9, 12);
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          chatTimingProvider.overrideWithValue(
            const ChatTiming(
              replyAfter: Duration.zero,
              typingFor: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('ignores blank messages', () {
      final before = container
          .read(chatProvider)['00000000-0000-4000-8000-000000000001']!
          .messages
          .length;
      container
          .read(chatProvider.notifier)
          .send('00000000-0000-4000-8000-000000000001', '   ');
      expect(
        container
            .read(chatProvider)['00000000-0000-4000-8000-000000000001']!
            .messages,
        hasLength(before),
      );
    });

    test('unsend refuses once the window has passed', () {
      final chat = container.read(chatProvider.notifier)
        ..send('00000000-0000-4000-8000-000000000002', 'hi');
      final id = container
          .read(chatProvider)['00000000-0000-4000-8000-000000000002']!
          .messages
          .last
          .id;

      now = now.add(const Duration(minutes: 11));

      expect(chat.unsend('00000000-0000-4000-8000-000000000002', id), isFalse);
    });

    test('a reply arrives and counts as unread', () async {
      container
          .read(chatProvider.notifier)
          .send('00000000-0000-4000-8000-000000000002', 'hi');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final conversation = container.read(
        chatProvider,
      )['00000000-0000-4000-8000-000000000002']!;
      expect(conversation.messages.last.fromMe, isFalse);
      expect(conversation.unread, 1);
      expect(conversation.messages.first.status, DeliveryStatus.read);
    });

    test('inbox is newest first and the unread total sums it', () {
      final inbox = container.read(inboxProvider);
      expect(inbox.first.profileId, '00000000-0000-4000-8000-000000000001');
      expect(container.read(unreadTotalProvider), 3);
    });
  });

  group('message times', () {
    setUpAll(() => initializeDateFormatting('en'));

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('shortTimestamp shows the local time for a UTC message today', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final time = DateTime.utc(2026, 11, 18, 5);
      final now = DateTime.utc(2026, 11, 18, 5, 30);

      final text = shortTimestamp(context, time, now);

      expect(text, DateFormat.jm('en').format(time.toLocal()));
    });

    testWidgets('shortTimestamp uses the local day', (tester) async {
      final context = await pumpContext(tester);
      final now = DateTime(2026, 11, 19, 0, 1);
      final time = DateTime(2026, 11, 18, 23, 59).toUtc();

      final text = shortTimestamp(context, time, now);

      expect(text, DateFormat.E('en').format(time.toLocal()));
    });

    testWidgets('messageTime formats a UTC message in local time', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final time = DateTime.utc(2026, 11, 18, 23);

      expect(
        messageTime(context, time),
        DateFormat.jm('en').format(time.toLocal()),
      );
    });
  });
}
