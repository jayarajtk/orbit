import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';

/// Starting inbox for development builds, relative to [now].
Map<String, Conversation> seedConversations(DateTime now) {
  DateTime ago(Duration d) => now.subtract(d);

  final conversations = [
    Conversation(
      profileId: '00000000-0000-4000-8000-000000000001',
      unread: 2,
      messages: [
        Message(
          id: 's1',
          fromMe: true,
          kind: MessageKind.text,
          text: "Hey! Saw you're into climbing too",
          sentAt: ago(const Duration(minutes: 12)),
          status: DeliveryStatus.read,
        ),
        Message(
          id: 's2',
          fromMe: false,
          kind: MessageKind.text,
          text: 'Ha, yes! Mostly bouldering. You?',
          sentAt: ago(const Duration(minutes: 3)),
        ),
        Message(
          id: 's3',
          fromMe: false,
          kind: MessageKind.text,
          text: "There's a new gym near the river",
          sentAt: ago(const Duration(minutes: 2)),
        ),
      ],
    ),
    Conversation(
      profileId: '00000000-0000-4000-8000-000000000003',
      unread: 1,
      messages: [
        Message(
          id: 's4',
          fromMe: false,
          kind: MessageKind.wave,
          sentAt: ago(const Duration(hours: 1)),
        ),
      ],
    ),
    Conversation(
      profileId: '00000000-0000-4000-8000-000000000004',
      messages: [
        Message(
          id: 's5',
          fromMe: false,
          kind: MessageKind.album,
          albumName: 'Trail runs',
          sentAt: ago(const Duration(days: 1)),
        ),
        Message(
          id: 's6',
          fromMe: true,
          kind: MessageKind.text,
          text: 'Those views! Where was the second one?',
          sentAt: ago(const Duration(hours: 20)),
          status: DeliveryStatus.read,
        ),
      ],
    ),
    Conversation(
      profileId: '00000000-0000-4000-8000-000000000005',
      messages: [
        Message(
          id: 's7',
          fromMe: false,
          kind: MessageKind.text,
          text: 'See you Saturday!',
          sentAt: ago(const Duration(days: 2)),
        ),
        Message(
          id: 's8',
          fromMe: true,
          kind: MessageKind.text,
          text: 'Haha same',
          sentAt: ago(const Duration(days: 2, minutes: -5)),
          status: DeliveryStatus.read,
        ),
      ],
    ),
  ];
  return {for (final c in conversations) c.profileId: c};
}
