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
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/chat_items.dart';
import 'package:orbit/features/chat/presentation/message_bubble.dart';
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

enum _ChatMenu { profile, mute, safety }

/// The message a bubble for [item] acts on (the newest wave of a run), or
/// null for items that are not drawn as a bubble.
Message? _bubbleMessage(ChatItem item) => switch (item) {
  MessageItem(:final message) => message,
  WaveRunItem(:final waves) => waves.last,
  DaySeparatorItem() || PhotoMosaicItem() => null,
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
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_Attachment>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (option, icon, label) in [
              (_Attachment.library, Icons.photo_outlined, l10n.photoOption),
              (
                _Attachment.camera,
                Icons.photo_camera_outlined,
                l10n.cameraOption,
              ),
              (
                _Attachment.viewOnce,
                Icons.filter_1_outlined,
                l10n.viewOnceOption,
              ),
              (_Attachment.video, Icons.videocam_outlined, l10n.videoOption),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final picker = ref.read(mediaPickerProvider);
    final picked = choice == _Attachment.video
        ? await picker.pickVideo(maxDuration: const Duration(seconds: 60))
        : await picker.pickPhoto(camera: choice == _Attachment.camera);
    if (picked == null || !mounted) return;
    ref
        .read(chatProvider.notifier)
        .sendMedia(
          _id,
          choice == _Attachment.video ? MessageKind.video : MessageKind.photo,
          picked,
          viewOnce: choice == _Attachment.viewOnce,
        );
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

  Future<void> _unsend(Message message) async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    if (!message.canUnsend(now)) {
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
    if (confirmed ?? false) {
      ref.read(chatProvider.notifier).unsend(_id, message.id);
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
        title: Row(
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
                  if (profile.online)
                    Text(
                      l10n.onlineNow,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.online,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
                  final message = _bubbleMessage(item);
                  if (message == null) return const SizedBox.shrink();
                  final isNewestMine =
                      message.fromMe &&
                      !items
                          .skip(items.length - position)
                          .any((i) => _bubbleMessage(i)?.fromMe ?? false);
                  return MessageBubble(
                    key: ValueKey(
                      item is WaveRunItem ? item.waves.first.id : message.id,
                    ),
                    waveCount: item is WaveRunItem ? item.waves.length : 1,
                    profileId: _id,
                    message: message,
                    otherName: profile.name,
                    showStatus: isNewestMine,
                    showReadReceipt: showReceipts,
                    onLongPress: message.fromMe && !message.unsent
                        ? () => _unsend(message)
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
            _Composer(
              controller: _composer,
              onSend: _send,
              onTyping: () => ref.read(chatProvider.notifier).typing(_id),
              onAlbum: () => context.push(AppRoutes.shareAlbum(_id)),
              onLocation: _shareLocation,
              onQuickPhrases: _quickPhrases,
              onAttach: _recorder == null ? null : _attach,
              onVoice: _recorder == null ? null : _startVoice,
              recording: _recording,
              onStopVoice: _stopVoice,
              onCancelVoice: _cancelVoice,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onTyping,
    required this.onAlbum,
    required this.onLocation,
    required this.onQuickPhrases,
    required this.onAttach,
    required this.onVoice,
    required this.recording,
    required this.onStopVoice,
    required this.onCancelVoice,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  final VoidCallback onAlbum;
  final VoidCallback onLocation;
  final VoidCallback onQuickPhrases;

  /// Photo or video; null when there's no server (demo mode).
  final VoidCallback? onAttach;

  /// Starts a voice note; null when there's no server (demo mode).
  final VoidCallback? onVoice;

  /// Whether a voice note is being recorded.
  final bool recording;
  final VoidCallback onStopVoice;
  final VoidCallback onCancelVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: onAttach == null
                    ? l10n.photoTooltip
                    : l10n.attachTooltip,
                onPressed: recording ? null : onAttach,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: l10n.albumTooltip,
                onPressed: onAlbum,
                icon: const Icon(Icons.photo_library_outlined),
              ),
              IconButton(
                tooltip: l10n.locationTooltip,
                onPressed: onLocation,
                icon: const Icon(Icons.place_outlined),
              ),
              IconButton(
                tooltip: l10n.quickPhrasesTooltip,
                onPressed: onQuickPhrases,
                icon: const Icon(Icons.bolt_outlined),
              ),
              if (onVoice != null && !recording)
                IconButton(
                  tooltip: l10n.voiceTooltip,
                  onPressed: onVoice,
                  icon: const Icon(Icons.mic_none),
                ),
            ],
          ),
          if (recording)
            Row(
              children: [
                IconButton(
                  tooltip: l10n.voiceCancelTooltip,
                  onPressed: onCancelVoice,
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
                IconButton.filled(
                  tooltip: l10n.voiceStopTooltip,
                  onPressed: onStopVoice,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
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
                IconButton.filled(
                  tooltip: l10n.sendTooltip,
                  onPressed: onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _Attachment { library, camera, viewOnce, video }
