import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

/// Links to a message's media, kept until shortly before they expire. Never
/// used for a view-once photo's recipient, which must fetch on purpose.
final FutureProviderFamily<MediaLinks, (String, String)> messageMediaProvider =
    FutureProvider.autoDispose.family<MediaLinks, (String, String)>((
      ref,
      key,
    ) async {
      final (profileId, messageId) = key;
      final links = await ref
          .read(chatProvider.notifier)
          .mediaLinks(profileId, messageId);
      final keep = ref.keepAlive();
      final ttl =
          links.expiresAt.difference(DateTime.now()) -
          const Duration(seconds: 30);
      final timer = Timer(ttl.isNegative ? Duration.zero : ttl, keep.close);
      ref.onDispose(timer.cancel);
      return links;
    });

/// The media part of a chat bubble: photo, view-once photo, video or voice.
class MessageMedia extends ConsumerWidget {
  /// Creates the media view for [message] in the chat with [profileId].
  const MessageMedia({
    required this.profileId,
    required this.message,
    required this.color,
    super.key,
  });

  /// The other member.
  final String profileId;

  /// A photo, video or voice message.
  final Message message;

  /// Text and icon colour on the bubble.
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (message.mediaId == null) {
      return _Line(
        icon: Icons.cloud_upload_outlined,
        text: l10n.uploading,
        color: color,
      );
    }
    if (message.kind == MessageKind.photo && message.viewOnce) {
      return _ViewOnce(profileId: profileId, message: message, color: color);
    }
    return switch (message.kind) {
      MessageKind.video => _Video(
        profileId: profileId,
        message: message,
        color: color,
      ),
      MessageKind.voice => _Voice(
        profileId: profileId,
        message: message,
        color: color,
      ),
      _ => _Photo(profileId: profileId, message: message),
    };
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.profileId, required this.message});

  final String profileId;
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final links = ref.watch(messageMediaProvider((profileId, message.id)));
    return switch (links) {
      AsyncData(:final value) => Semantics(
        button: true,
        label: l10n.photoMessage,
        child: GestureDetector(
          onTap: () => openPhoto(context, value.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: value.aspectRatio.clamp(0.6, 1.8),
              child: Image.network(
                value.thumbUrl ?? value.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
      AsyncError() => Text(l10n.mediaUnavailable),
      _ => const SizedBox(
        width: 200,
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ViewOnce extends ConsumerWidget {
  const _ViewOnce({
    required this.profileId,
    required this.message,
    required this.color,
  });

  final String profileId;
  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (message.fromMe) {
      return _Line(
        icon: Icons.filter_1_outlined,
        text: message.viewed
            ? '${l10n.viewOnceSent} · ${l10n.viewOnceOpened}'
            : l10n.viewOnceSent,
        color: color,
      );
    }
    if (message.viewed) {
      return _Line(
        icon: Icons.filter_1_outlined,
        text: l10n.viewOnceOpened,
        color: color,
      );
    }
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final links = await ref
              .read(chatProvider.notifier)
              .mediaLinks(profileId, message.id);
          if (context.mounted) await openPhoto(context, links.url);
        } on ApiException {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.mediaUnavailable)),
          );
        }
      },
      child: _Line(
        icon: Icons.filter_1_outlined,
        text: l10n.viewOnceClosed,
        color: color,
      ),
    );
  }
}

class _Video extends ConsumerWidget {
  const _Video({
    required this.profileId,
    required this.message,
    required this.color,
  });

  final String profileId;
  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final links = await ref.read(
            messageMediaProvider((profileId, message.id)).future,
          );
          if (context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => VideoViewer(url: links.url),
              ),
            );
          }
        } on ApiException {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.mediaUnavailable)),
          );
        }
      },
      child: _Line(
        icon: Icons.play_circle_outline,
        text: l10n.videoMessage,
        color: color,
      ),
    );
  }
}

/// A voice note: tap to play or pause. The player exists only while shown.
class _Voice extends ConsumerStatefulWidget {
  const _Voice({
    required this.profileId,
    required this.message,
    required this.color,
  });

  final String profileId;
  final Message message;
  final Color color;

  @override
  ConsumerState<_Voice> createState() => _VoiceState();
}

class _VoiceState extends ConsumerState<_Voice> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _state;
  bool _playing = false;
  int? _durationMs;

  @override
  void dispose() {
    unawaited(_state?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var player = _player;
    if (player == null) {
      try {
        final links = await ref.read(
          messageMediaProvider((widget.profileId, widget.message.id)).future,
        );
        player = AudioPlayer();
        await player.setUrl(links.url);
        _state = player.playerStateStream.listen((state) {
          final done = state.processingState == ProcessingState.completed;
          if (done) unawaited(player!.seek(Duration.zero));
          if (mounted) setState(() => _playing = state.playing && !done);
        });
        setState(() {
          _player = player;
          _durationMs = links.durationMs;
        });
      } on Exception {
        messenger.showSnackBar(SnackBar(content: Text(l10n.mediaUnavailable)));
        return;
      }
    }
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = ((_durationMs ?? 0) / 1000).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _playing ? l10n.pauseTooltip : l10n.playTooltip,
          color: widget.color,
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
        ),
        Text(
          seconds > 0 ? l10n.voiceDuration(seconds) : l10n.voiceMessage,
          style: TextStyle(color: widget.color),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

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

/// Shows [url] full screen with pinch to zoom.
Future<void> openPhoto(BuildContext context, String url) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => PhotoViewer(url: url),
    ),
  );
}

/// A full-screen photo.
class PhotoViewer extends StatelessWidget {
  /// Creates the viewer.
  const PhotoViewer({required this.url, super.key});

  /// Image to show.
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.closeTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (context, error, stackTrace) => Text(
              l10n.mediaUnavailable,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-screen video that plays once opened.
class VideoViewer extends StatefulWidget {
  /// Creates the viewer.
  const VideoViewer({required this.url, super.key});

  /// Video to play.
  final String url;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.closeTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _failed
            ? Text(
                l10n.mediaUnavailable,
                style: const TextStyle(color: Colors.white),
              )
            : !_ready
            ? const CircularProgressIndicator()
            : GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying
                      ? unawaited(_controller.pause())
                      : unawaited(_controller.play());
                }),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
      ),
    );
  }
}
