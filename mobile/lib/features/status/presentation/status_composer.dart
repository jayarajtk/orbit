import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The longest status caption.
const statusCaptionLimit = 100;

/// Lets the member pick a photo, then opens the composer for it. Does
/// nothing when they cancel the picker.
Future<void> addStatus(BuildContext context, WidgetRef ref) async {
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
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final media = ref.read(mediaRepositoryProvider);
    final caption = _caption.text.trim();
    setState(() => _posting = true);
    try {
      if (media == null) {
        throw UnsupportedError('Statuses need the media service (API mode).');
      }
      final uploaded = await media.upload(
        MediaPurpose.statusPhoto,
        widget.photo.bytes,
        widget.photo.contentType,
      );
      await ref
          .read(myStatusesProvider.notifier)
          .post(uploaded.id, caption: caption.isEmpty ? null : caption);
      if (mounted) navigator.pop();
      return;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_message(l10n, e))));
    } on Object catch (e, stack) {
      // Not an API refusal (for example no media service): the member only
      // needs to know it failed; the cause goes to the developer log.
      developer.log('Status post failed', error: e, stackTrace: stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
    if (mounted) setState(() => _posting = false);
  }

  static String _message(AppLocalizations l10n, ApiException e) {
    if (e.isProblem('status-limit')) return l10n.statusLimitReached;
    return e.status == 422 ? l10n.uploadFailed : l10n.actionFailed;
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
                        const ColoredBox(color: Colors.black12),
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
                  onPressed: _posting ? null : _post,
                  child: _posting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.statusPost),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
