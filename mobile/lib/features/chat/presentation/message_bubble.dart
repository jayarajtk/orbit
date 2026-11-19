import 'package:flutter/material.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/message_media.dart';
import 'package:orbit/features/chat/presentation/message_preview.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// One message in the chat thread.
class MessageBubble extends StatelessWidget {
  /// Creates a bubble for [message].
  const MessageBubble({
    required this.profileId,
    required this.message,
    required this.otherName,
    required this.showReadReceipt,
    this.groupedWithNext = false,
    this.groupedWithPrevious = false,
    this.waveCount = 1,
    this.onLongPress,
    this.onTap,
    super.key,
  });

  /// The other member in this chat.
  final String profileId;

  /// The message.
  final Message message;

  /// The other member's name, for incoming cards.
  final String otherName;

  /// Whether read receipts are enabled.
  final bool showReadReceipt;

  /// Whether the next bubble is from the same sender and close in time:
  /// tighter spacing and no tail.
  final bool groupedWithNext;

  /// Whether the previous bubble is from the same sender and close in time:
  /// tighter spacing.
  final bool groupedWithPrevious;

  /// How many waves this bubble stands for, when [message] is the newest
  /// of a run of waves.
  final int waveCount;

  /// Long-press action (unsend), if allowed.
  final VoidCallback? onLongPress;

  /// Tap action (retry a failed message), if any.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final mine = message.fromMe;
    final background = mine ? tokens.ownBubble : tokens.surface;
    final foreground = tokens.text;
    final failed = message.status == DeliveryStatus.failed;

    final Widget content;
    if (message.unsent) {
      content = Text(
        l10n.unsentMessage,
        style: TextStyle(color: foreground, fontStyle: FontStyle.italic),
      );
    } else {
      content = switch (message.kind) {
        MessageKind.text => Text(
          message.text,
          style: TextStyle(color: foreground, fontSize: 15),
        ),
        MessageKind.wave => _IconLine(
          icon: Icons.waving_hand_outlined,
          text: switch ((mine, waveCount > 1)) {
            (true, true) => l10n.waveOutCount(waveCount),
            (true, false) => l10n.waveOut,
            (false, true) => l10n.waveInCount(otherName, waveCount),
            (false, false) => l10n.waveIn(otherName),
          },
          color: foreground,
        ),
        MessageKind.location => _IconLine(
          icon: Icons.place_outlined,
          text: l10n.locationCard(message.locationMinutes ?? 0),
          color: foreground,
        ),
        MessageKind.album => _IconLine(
          icon: Icons.photo_library_outlined,
          text: mine
              ? l10n.albumCardOut(message.albumName ?? '')
              : l10n.albumCardIn(otherName, message.albumName ?? ''),
          color: foreground,
        ),
        MessageKind.photo ||
        MessageKind.video ||
        MessageKind.voice => MessageMedia(
          profileId: profileId,
          message: message,
          color: foreground,
        ),
      };
    }

    const tail = Radius.circular(6);
    const round = Radius.circular(18);
    final tailed = !groupedWithNext;
    return Padding(
      padding: EdgeInsets.only(
        top: groupedWithPrevious ? 1 : 3,
        bottom: groupedWithNext ? 1 : 3,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Material(
              color: background,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: !mine && tailed ? tail : round,
                bottomEnd: mine && tailed ? tail : round,
              ),
              child: InkWell(
                onLongPress: onLongPress,
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      content,
                      const SizedBox(height: 2),
                      _TimeAndTicks(
                        message: message,
                        showReadReceipt: showReadReceipt,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (failed && !message.unsent)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.statusFailed,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// The local time and, on own messages, the delivery ticks.
class _TimeAndTicks extends StatelessWidget {
  const _TimeAndTicks({required this.message, required this.showReadReceipt});

  final Message message;
  final bool showReadReceipt;

  static const _tickSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final muted = tokens.onBubbleMuted(
      message.fromMe ? tokens.ownBubble : tokens.surface,
    );
    final tickColor = tokens.tickMuted(tokens.ownBubble);
    final tick = message.fromMe && !message.unsent
        ? switch (message.status) {
            DeliveryStatus.pending => Icon(
              Icons.schedule,
              size: _tickSize,
              color: tickColor,
              semanticLabel: l10n.statusSending,
            ),
            DeliveryStatus.sent => Icon(
              Icons.done,
              size: _tickSize,
              color: tickColor,
              semanticLabel: l10n.tickSent,
            ),
            DeliveryStatus.read when showReadReceipt => Icon(
              Icons.done_all,
              size: _tickSize,
              color: tokens.readTick,
              semanticLabel: l10n.tickRead,
            ),
            // With receipts off, a read message looks merely delivered.
            DeliveryStatus.read => Icon(
              Icons.done_all,
              size: _tickSize,
              color: tickColor,
              semanticLabel: l10n.tickDelivered,
            ),
            DeliveryStatus.failed => null,
          }
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messageTime(context, message.sentAt),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
        ),
        if (tick != null) ...[const SizedBox(width: 4), tick],
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
