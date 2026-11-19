import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/albums/presentation/albums_controller.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W12: share a private album with the member in the current chat.
class ShareAlbumScreen extends ConsumerStatefulWidget {
  /// Creates the share screen for [profileId].
  const ShareAlbumScreen({required this.profileId, super.key});

  /// Who the album is shared with.
  final String profileId;

  @override
  ConsumerState<ShareAlbumScreen> createState() => _ShareAlbumScreenState();
}

class _ShareAlbumScreenState extends ConsumerState<ShareAlbumScreen> {
  String? _albumId;
  AlbumAccess _access = AlbumAccess.day;
  bool _viewOnce = false;

  Future<void> _share(Album album, String name) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      // The grant must exist before the card arrives, or the recipient
      // couldn't open it.
      await ref
          .read(albumsProvider.notifier)
          .share(
            albumId: album.id,
            profileId: widget.profileId,
            access: _access,
            viewOnce: _viewOnce,
          );
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      return;
    }
    ref
        .read(chatProvider.notifier)
        .shareAlbum(
          widget.profileId,
          album.name,
          albumId: ref.read(albumRepositoryProvider) == null ? null : album.id,
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.albumShared(name))));
    router.pop();
  }

  Future<void> _revoke(String albumId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(albumsProvider.notifier)
          .revoke(albumId: albumId, profileId: widget.profileId);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final albums = ref.watch(albumsProvider);
    final now = ref.watch(clockProvider)();
    final name =
        ref.watch(profilesByIdProvider)[widget.profileId]?.name ??
        l10n.unknownMember;
    final selected = albums.where((a) => a.id == _albumId).firstOrNull;
    final sharedIn = [
      for (final album in albums)
        if (album.activeGrants(now).any((g) => g.profileId == widget.profileId))
          album,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareAlbumTitle(name))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              for (final album in albums)
                _AlbumCard(
                  album: album,
                  selected: album.id == _albumId,
                  onTap: () => setState(() => _albumId = album.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.accessLasts, style: theme.textTheme.titleSmall),
          RadioGroup<AlbumAccess>(
            groupValue: _access,
            onChanged: (value) => setState(() => _access = value ?? _access),
            child: Column(
              children: [
                for (final (access, label) in [
                  (AlbumAccess.day, l10n.access24h),
                  (AlbumAccess.week, l10n.access7d),
                  (AlbumAccess.untilRevoked, l10n.accessUntilRevoked),
                ])
                  RadioListTile<AlbumAccess>(
                    contentPadding: EdgeInsets.zero,
                    value: access,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _viewOnce,
            onChanged: (v) => setState(() => _viewOnce = v ?? false),
            title: Text(l10n.viewOnce),
          ),
          Text(
            l10n.screenshotNote,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (sharedIn.isNotEmpty) ...[
            const Divider(height: 32),
            for (final album in sharedIn)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(album.name),
                subtitle: Text(l10n.sharedWith(name)),
                trailing: TextButton(
                  onPressed: () => _revoke(album.id),
                  child: Text(l10n.revoke),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null
                ? null
                : () => unawaited(_share(selected, name)),
            child: Text(l10n.shareAlbumButton),
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final Album album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Icon(
                      album.isPrivate
                          ? Icons.lock_outline
                          : Icons.photo_library_outlined,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  album.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  album.isPrivate
                      ? '${l10n.albumPhotos(album.photoCount)} · '
                            '${l10n.albumPrivate}'
                      : l10n.albumPhotos(album.photoCount),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
