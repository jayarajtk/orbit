import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Most lines the message field grows to before it scrolls.
const _maxLines = 5;

const _swapMotion = Duration(milliseconds: 250);

/// The chat message bar: a "+" for attachments, a field that grows to five
/// lines, and a button that is the mic while the field is blank and send
/// once there is text.
class Composer extends StatelessWidget {
  /// Creates the composer around [controller].
  const Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onVoiceStart,
    required this.onVoiceStop,
    required this.onVoiceCancel,
    required this.onTyping,
    this.recording = false,
    super.key,
  });

  /// Holds the message being written.
  final TextEditingController controller;

  /// Sends the current text.
  final VoidCallback onSend;

  /// Opens the attach sheet.
  final VoidCallback onAttach;

  /// Starts a voice note; null when there is no server (demo mode).
  final VoidCallback? onVoiceStart;

  /// Stops the voice note and sends it.
  final VoidCallback onVoiceStop;

  /// Throws the voice note away.
  final VoidCallback onVoiceCancel;

  /// Called as the member types.
  final VoidCallback onTyping;

  /// Whether a voice note is being recorded.
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
      child: recording
          ? Row(
              children: [
                IconButton(
                  tooltip: l10n.voiceCancelTooltip,
                  onPressed: onVoiceCancel,
                  icon: const Icon(Icons.delete_outline),
                ),
                Icon(Icons.fiber_manual_record, color: scheme.error, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.recording,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                _RoundButton(
                  tooltip: l10n.voiceStopTooltip,
                  onPressed: onVoiceStop,
                  icon: Icons.send,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.attachTooltip,
                  onPressed: onAttach,
                  icon: const Icon(Icons.add),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: _maxLines,
                    textCapitalization: TextCapitalization.sentences,
                    // Return starts a new line; only the button sends.
                    textInputAction: TextInputAction.newline,
                    onChanged: (text) {
                      if (text.isNotEmpty) onTyping();
                    },
                    decoration: InputDecoration(
                      hintText: l10n.messageHint,
                      labelText: l10n.messageLabel,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final hasText = controller.text.trim().isNotEmpty;
                    final still = MediaQuery.disableAnimationsOf(context);
                    return AnimatedSwitcher(
                      duration: still ? Duration.zero : _swapMotion,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: hasText
                          ? _RoundButton(
                              key: const ValueKey('send'),
                              tooltip: l10n.sendTooltip,
                              onPressed: onSend,
                              icon: Icons.send,
                            )
                          : _RoundButton(
                              key: const ValueKey('mic'),
                              tooltip: l10n.voiceTooltip,
                              onPressed: onVoiceStart,
                              icon: Icons.mic_none,
                            ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

/// The filled round button at the end of the bar.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}
