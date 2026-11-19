import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/message_preview.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

enum _InboxFilter { all, unread, favorites }

/// W10: conversations, newest first.
class InboxScreen extends ConsumerStatefulWidget {
  /// Creates the Inbox tab.
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  _InboxFilter _filter = _InboxFilter.all;

  void _delete(Conversation conversation, String name) {
    final l10n = AppLocalizations.of(context);
    final removed = ref
        .read(chatProvider.notifier)
        .delete(conversation.profileId);
    if (removed == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.conversationDeleted(name)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => ref.read(chatProvider.notifier).restore(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider);
    final profiles = ref.watch(profilesByIdProvider);
    final conversations = [
      for (final c in ref.watch(inboxProvider))
        if (switch (_filter) {
          _InboxFilter.all => true,
          _InboxFilter.unread => c.unread > 0,
          _InboxFilter.favorites => favorites.contains(c.profileId),
        })
          c,
    ];
    final emptyMessage = switch (_filter) {
      _InboxFilter.all => l10n.inboxEmpty,
      _InboxFilter.unread => l10n.inboxUnreadEmpty,
      _InboxFilter.favorites => l10n.inboxFavoritesEmpty,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabInbox)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_InboxFilter>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _InboxFilter.all,
                    label: Text(l10n.inboxAll),
                  ),
                  ButtonSegment(
                    value: _InboxFilter.unread,
                    label: Text(l10n.inboxUnread),
                  ),
                  ButtonSegment(
                    value: _InboxFilter.favorites,
                    label: Text(l10n.inboxFavorites),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          Expanded(
            child: conversations.isEmpty
                ? EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: emptyMessage,
                  )
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final c = conversations[index];
                      final profile = profiles[c.profileId];
                      final name = profile?.name ?? l10n.unknownMember;
                      return Dismissible(
                        key: ValueKey(c.profileId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) => _delete(c, name),
                        child: _ConversationTile(
                          conversation: c,
                          profile: profile,
                          name: name,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.profile,
    required this.name,
  });

  final Conversation conversation;
  final Profile? profile;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = conversation.last!;
    final now = ref.watch(clockProvider)();
    final typing = ref.watch(typingProvider).contains(conversation.profileId);
    final unread = conversation.unread > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push(AppRoutes.chat(conversation.profileId)),
      leading: Stack(
        children: [
          ProfileAvatar(
            name: name,
            seed: conversation.profileId,
            hasPhoto: profile?.hasPhoto ?? true,
            photoUrl: profile?.thumbUrl,
            size: 52,
          ),
          if (profile?.online ?? false)
            const PositionedDirectional(
              end: 0,
              bottom: 2,
              child: OnlineDot(size: 12),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (conversation.muted) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.notifications_off_outlined,
              size: 16,
              semanticLabel: l10n.mutedLabel,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Text(
        typing ? l10n.typing(name) : messagePreview(l10n, last),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
          fontStyle: typing ? FontStyle.italic : null,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            shortTimestamp(context, last.sentAt, now),
            style: theme.textTheme.labelSmall,
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            Badge.count(count: conversation.unread),
          ],
        ],
      ),
    );
  }
}
