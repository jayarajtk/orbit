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

/// Turns [messages] (oldest first) into the items the chat list draws,
/// collapsing consecutive waves from the same sender into one run.
List<ChatItem> chatItems(List<Message> messages) {
  final items = <ChatItem>[];
  final run = <Message>[];

  void flushRun() {
    if (run.isEmpty) return;
    items.add(WaveRunItem(List.unmodifiable(run)));
    run.clear();
  }

  for (final message in messages) {
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
  return items;
}
