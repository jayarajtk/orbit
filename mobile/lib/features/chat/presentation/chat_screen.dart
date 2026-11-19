import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/attach_sheet.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/chat_items.dart';
import 'package:orbit/features/chat/presentation/composer.dart';
import 'package:orbit/features/chat/presentation/message_bubble.dart';
import 'package:orbit/features/chat/presentation/message_preview.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/features/safety/presentation/safety_sheet.dart';
import 'package:orbit/features/settings/presentation/settings_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W11: a 1:1 conversation.
class ChatScreen extends ConsumerWidget {
  /// Creates the chat with [profileId].
  const ChatScreen({required this.profileId, super.key});

  /// The other member.
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedProvider).contains(profileId);
    final unavailable = Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.person_off_outlined,
        message: l10n.profileUnavailable,
      ),
    );
    final cached = ref.watch(profilesByIdProvider)[profileId];
    return ref
        .watch(profileByIdProvider(profileId))
        .when(
          loading: () => cached != null && !blocked
              ? _ChatView(profile: cached)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
          error: (_, _) => unavailable,
          data: (profile) => profile == null || blocked
              ? unavailable
              : _ChatView(profile: profile),
        );
  }
}

/// The day heading between messages.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tokens.text),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChatMenu { profile, mute, safety }

/// The message a bubble for [item] acts on (the newest wave of a run), or
/// null for items that are not drawn as a bubble.
Message? _bubbleMessage(ChatItem item) => switch (item) {
  MessageItem(:final message) => message,
  WaveRunItem(:final waves) => waves.last,
  PhotoMosaicItem(:final photos) => photos.last,
  DaySeparatorItem() => null,
};

class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _composer = TextEditingController();

  /// Null in demo mode: media needs the server.
  VoiceRecorder? _recorder;
  bool _recording = false;

  String get _id => widget.profile.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = ref.read(chatProvider.notifier);
      unawaited(chat.open(_id));
      chat.markRead(_id);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _send() {
    ref.read(chatProvider.notifier).send(_id, _composer.text);
    _composer.clear();
  }

  /// Shortest voice note worth sending (a mis-tap otherwise).
  static const _minVoice = Duration(seconds: 1);

  Future<void> _attach() async {
    final choice = await showAttachSheet(
      context,
      mediaEnabled: _recorder != null,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case AttachChoice.photos:
        await _sendPhotos();
      case AttachChoice.video:
        await _sendVideo();
      case AttachChoice.camera || AttachChoice.viewOnce:
        await _sendPhoto(
          camera: choice == AttachChoice.camera,
          viewOnce: choice == AttachChoice.viewOnce,
        );
      case AttachChoice.album:
        await context.push(AppRoutes.shareAlbum(_id));
      case AttachChoice.location:
        await _shareLocation();
      case AttachChoice.quickPhrase:
        await _quickPhrases();
    }
  }

  /// Sends each photo the member picks as its own message, in the order
  /// they were picked.
  Future<void> _sendPhotos() async {
    final picked = await ref.read(mediaPickerProvider).pickPhotos();
    if (!mounted) return;
    ref.read(chatProvider.notifier).sendPhotos(_id, picked);
  }

  Future<void> _sendVideo() async {
    final picked = await ref
        .read(mediaPickerProvider)
        .pickVideo(maxDuration: const Duration(seconds: 60));
    if (picked == null || !mounted) return;
    ref.read(chatProvider.notifier).sendMedia(_id, MessageKind.video, picked);
  }

  Future<void> _sendPhoto({
    required bool camera,
    required bool viewOnce,
  }) async {
    final picked = await ref
        .read(mediaPickerProvider)
        .pickPhoto(camera: camera);
    if (picked == null || !mounted) return;
    ref
        .read(chatProvider.notifier)
        .sendMedia(_id, MessageKind.photo, picked, viewOnce: viewOnce);
  }

  Future<void> _startVoice() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final started = await _recorder!.start();
    if (!mounted) return;
    if (!started) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.microphoneDenied)));
      return;
    }
    setState(() => _recording = true);
  }

  Future<void> _stopVoice() async {
    final voice = await _recorder!.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (voice == null || (voice.durationMs ?? 0) < _minVoice.inMilliseconds) {
      return;
    }
    ref.read(chatProvider.notifier).sendMedia(_id, MessageKind.voice, voice);
  }

  Future<void> _cancelVoice() async {
    await _recorder!.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _shareLocation() async {
    final l10n = AppLocalizations.of(context);
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.shareLocationTitle)),
            for (final m in const [15, 30])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(l10n.minutesOption(m)),
                onTap: () => Navigator.of(context).pop(m),
              ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.hourOption),
              onTap: () => Navigator.of(context).pop(60),
            ),
          ],
        ),
      ),
    );
    if (minutes != null) {
      ref.read(chatProvider.notifier).shareLocation(_id, minutes);
    }
  }

  Future<void> _quickPhrases() async {
    final l10n = AppLocalizations.of(context);
    final phrases = [
      l10n.phraseHi,
      l10n.phraseCoffee,
      l10n.phraseWhat,
      l10n.phraseLater,
    ];
    final phrase = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in phrases)
              ListTile(
                title: Text(p),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (phrase != null) {
      _composer
        ..text = phrase
        ..selection = TextSelection.collapsed(offset: phrase.length);
    }
  }

  /// Unsends [messages] (one bubble, or every photo of a mosaic) after
  /// asking once. Messages past the unsend window are left alone.
  Future<void> _unsend(List<Message> messages) async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    final allowed = [
      for (final message in messages)
        if (message.canUnsend(now)) message,
    ];
    if (allowed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unsendExpired)),
      );
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.undo),
          title: Text(l10n.unsendAction),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (!(confirmed ?? false)) return;
    final chat = ref.read(chatProvider.notifier);
    for (final message in allowed) {
      chat.unsend(_id, message.id);
    }
  }

  Future<void> _onMenu(_ChatMenu choice) async {
    switch (choice) {
      case _ChatMenu.profile:
        await context.push(AppRoutes.profile(_id));
      case _ChatMenu.mute:
        ref.read(chatProvider.notifier).toggleMute(_id);
      case _ChatMenu.safety:
        final blocked = await showSafetySheet(context, widget.profile);
        if (blocked && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = widget.profile;
    _recorder = ref.watch(mediaRepositoryProvider) == null
        ? null
        : ref.watch(voiceRecorderProvider);
    final conversation = ref.watch(chatProvider)[_id];
    final items = chatItems(conversation?.messages ?? const <Message>[]);
    final typing = ref.watch(typingProvider).contains(_id);
    final showReceipts = ref.watch(
      settingsProvider.select((s) => s.readReceipts),
    );
    final muted = conversation?.muted ?? false;

    ref.listen(chatProvider.select((all) => all[_id]?.unread ?? 0), (_, n) {
      if (n > 0) ref.read(chatProvider.notifier).markRead(_id);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => unawaited(context.push(AppRoutes.profile(_id))),
          child: Row(
            children: [
              ProfileAvatar(
                name: profile.name,
                seed: profile.id,
                photoUrl: profile.thumbUrl,
                mediaId: profile.thumbMediaId,
                ownerId: profile.id,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, overflow: TextOverflow.ellipsis),
                    if (typing || profile.online)
                      Text(
                        typing ? l10n.typingStatus : l10n.onlineNow,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.tokens.online,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_ChatMenu>(
            tooltip: l10n.chatMenu,
            onSelected: _onMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ChatMenu.profile,
                child: Text(l10n.chatViewProfile),
              ),
              PopupMenuItem(
                value: _ChatMenu.mute,
                child: Text(muted ? l10n.chatUnmute : l10n.chatMute),
              ),
              PopupMenuItem(
                value: _ChatMenu.safety,
                child: Text(l10n.chatBlockReport),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: items.length + (typing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (typing && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        l10n.typing(profile.name),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    );
                  }
                  final position = index - (typing ? 1 : 0);
                  final item = items[items.length - 1 - position];
                  if (item is DaySeparatorItem) {
                    return _DaySeparator(
                      label: dayLabel(
                        context,
                        item.localDay,
                        ref.read(clockProvider)(),
                      ),
                    );
                  }
                  final message = _bubbleMessage(item);
                  if (message == null) return const SizedBox.shrink();
                  return MessageBubble(
                    key: ValueKey(switch (item) {
                      WaveRunItem(:final waves) => waves.first.id,
                      PhotoMosaicItem(:final photos) => photos.first.id,
                      _ => message.id,
                    }),
                    waveCount: item is WaveRunItem ? item.waves.length : 1,
                    mosaic: item is PhotoMosaicItem ? item.photos : null,
                    profileId: _id,
                    message: message,
                    otherName: profile.name,
                    showReadReceipt: showReceipts,
                    groupedWithNext: switch (item) {
                      MessageItem(:final groupedWithNext) ||
                      PhotoMosaicItem(
                        :final groupedWithNext,
                      ) => groupedWithNext,
                      _ => false,
                    },
                    groupedWithPrevious: switch (item) {
                      MessageItem(:final groupedWithPrevious) ||
                      PhotoMosaicItem(
                        :final groupedWithPrevious,
                      ) => groupedWithPrevious,
                      _ => false,
                    },
                    onLongPress: message.fromMe && !message.unsent
                        ? () => _unsend(
                            item is PhotoMosaicItem ? item.photos : [message],
                          )
                        : null,
                    onTap: message.status == DeliveryStatus.failed
                        ? () => ref
                              .read(chatProvider.notifier)
                              .retry(_id, message.id)
                        : message.kind == MessageKind.album &&
                              message.albumId != null &&
                              !message.unsent
                        ? () => context.push(AppRoutes.album(message.albumId!))
                        : null,
                  );
                },
              ),
            ),
            Composer(
              controller: _composer,
              onSend: _send,
              onTyping: () => ref.read(chatProvider.notifier).typing(_id),
              onAttach: _attach,
              onVoiceStart: _recorder == null ? null : _startVoice,
              onVoiceStop: _stopVoice,
              onVoiceCancel: _cancelVoice,
              recording: _recording,
            ),
          ],
        ),
      ),
    );
  }
}
