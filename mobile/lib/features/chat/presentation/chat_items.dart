import 'package:orbit/features/chat/domain/message.dart';

/// One entry in the chat list, built from the raw messages by [chatItems].
sealed class ChatItem {
  const ChatItem();
}

/// A single message drawn as its own bubble.
final class MessageItem extends ChatItem {
  /// Creates an item for [message].
  const MessageItem(
    this.message, {
    this.groupedWithNext = false,
    this.groupedWithPrevious = false,
  });

  /// The message.
  final Message message;

  /// Whether the next item is a message from the same sender.
  final bool groupedWithNext;

  /// Whether the previous item is a message from the same sender.
  final bool groupedWithPrevious;
}

/// Consecutive waves from one sender, drawn as one bubble.
final class WaveRunItem extends ChatItem {
  /// Creates a run of [waves], oldest first. Must not be empty.
  const WaveRunItem(this.waves);

  /// The waves in the run, oldest first.
  final List<Message> waves;
}

/// A divider between two days of messages.
final class DaySeparatorItem extends ChatItem {
  /// Creates a separator for [localDay].
  const DaySeparatorItem(this.localDay);

  /// The day, in the member's local time zone.
  final DateTime localDay;
}

/// Several photos sent together, drawn as one mosaic.
final class PhotoMosaicItem extends ChatItem {
  /// Creates a mosaic of [photos], oldest first.
  const PhotoMosaicItem(this.photos);

  /// The photos.
  final List<Message> photos;
}

/// Longest gap between two messages that still share a group.
const _groupGap = Duration(minutes: 2);

/// Turns [messages] (oldest first) into the items the chat list draws.
///
/// Consecutive waves from the same sender collapse into one run; a
/// [DaySeparatorItem] opens each local calendar day; and consecutive
/// [MessageItem]s from one sender within two minutes are grouped. A wave run
/// or a separator between two messages always breaks their group.
List<ChatItem> chatItems(List<Message> messages) {
  final items = <ChatItem>[];
  final run = <Message>[];
  DateTime? day;

  void flushRun() {
    if (run.isEmpty) return;
    items.add(WaveRunItem(List.unmodifiable(run)));
    run.clear();
  }

  for (final message in messages) {
    final local = message.sentAt.toLocal();
    final messageDay = DateTime(local.year, local.month, local.day);
    if (messageDay != day) {
      flushRun();
      items.add(DaySeparatorItem(messageDay));
      day = messageDay;
    }
    final isWave = message.kind == MessageKind.wave && !message.unsent;
    if (isWave && run.isNotEmpty && run.first.fromMe != message.fromMe) {
      flushRun();
    }
    if (isWave) {
      run.add(message);
      continue;
    }
    flushRun();
    items.add(MessageItem(message));
  }
  flushRun();
  return _grouped(items);
}

/// Sets the grouping flags on each pair of adjacent [MessageItem]s.
List<ChatItem> _grouped(List<ChatItem> items) {
  bool groups(ChatItem a, ChatItem b) =>
      a is MessageItem &&
      b is MessageItem &&
      a.message.fromMe == b.message.fromMe &&
      b.message.sentAt.difference(a.message.sentAt) <= _groupGap;

  return [
    for (var i = 0; i < items.length; i++)
      switch (items[i]) {
        final MessageItem item => MessageItem(
          item.message,
          groupedWithPrevious: i > 0 && groups(items[i - 1], item),
          groupedWithNext: i < items.length - 1 && groups(item, items[i + 1]),
        ),
        final other => other,
      },
  ];
}
