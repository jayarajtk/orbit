import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The longest status caption.
const statusCaptionLimit = 100;

/// Lets the member pick a photo, then opens the composer for it. Does
/// nothing when they cancel the picker.
Future<void> addStatus(BuildContext context, WidgetRef ref) async {
  if (ref.read(statusPostingProvider).isPosting) return;
  final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
  if (picked == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StatusComposerScreen(photo: picked),
    ),
  );
}

/// Previews the picked [photo] with a caption field and a Post button.
/// Post closes the screen; the upload carries on in the background.
class StatusComposerScreen extends ConsumerStatefulWidget {
  /// Creates the composer for [photo].
  const StatusComposerScreen({required this.photo, super.key});

  /// The photo to post.
  final PickedMedia photo;

  @override
  ConsumerState<StatusComposerScreen> createState() =>
      _StatusComposerScreenState();
}

class _StatusComposerScreenState extends ConsumerState<StatusComposerScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _post() {
    final caption = _caption.text.trim();
    unawaited(
      ref
          .read(statusPostingProvider.notifier)
          .post(widget.photo, caption: caption.isEmpty ? null : caption),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statusAdd)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    widget.photo.bytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: Colors.black12, // photo-overlay
                        ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _caption,
                maxLength: statusCaptionLimit,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.statusCaptionHint),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _post,
                  child: Text(l10n.statusPost),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
