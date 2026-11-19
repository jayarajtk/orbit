import 'package:flutter/material.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/message_media.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// One message in the chat thread.
class MessageBubble extends StatelessWidget {
  /// Creates a bubble for [message].
  const MessageBubble({
    required this.profileId,
    required this.message,
    required this.otherName,
    required this.showStatus,
    required this.showReadReceipt,
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

  /// Whether to show Sent/Read under this (the newest own) message.
  final bool showStatus;

  /// Whether read receipts are enabled.
  final bool showReadReceipt;

  /// Long-press action (unsend), if allowed.
  final VoidCallback? onLongPress;

  /// Tap action (retry a failed message), if any.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromMe;
    final background = mine ? scheme.primary : scheme.surfaceContainer;
    final foreground = mine ? scheme.onPrimary : scheme.onSurface;
    final failed = message.status == DeliveryStatus.failed;
    final status = switch (message.status) {
      DeliveryStatus.pending => l10n.statusSending,
      DeliveryStatus.failed => l10n.statusFailed,
      DeliveryStatus.read when showReadReceipt => l10n.statusRead,
      DeliveryStatus.read || DeliveryStatus.sent => l10n.statusSent,
    };

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
          text: mine ? l10n.waveOut : l10n.waveIn(otherName),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
                bottomStart: Radius.circular(mine ? 18 : 6),
                bottomEnd: Radius.circular(mine ? 6 : 18),
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
                  child: content,
                ),
              ),
            ),
          ),
          if ((showStatus || failed) && !message.unsent)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                status,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
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
