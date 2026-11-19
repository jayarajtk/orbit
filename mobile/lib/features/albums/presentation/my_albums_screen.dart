import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/presentation/album_screen.dart';
import 'package:orbit/features/albums/presentation/albums_controller.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The user's albums and who can see them, with revoke. With a server it
/// also creates albums, opens them, and lists albums shared with the user.
class MyAlbumsScreen extends ConsumerWidget {
  /// Creates the albums screen.
  const MyAlbumsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(albumsProvider.notifier).create(name);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String albumId,
    String profileId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(albumsProvider.notifier)
          .revoke(albumId: albumId, profileId: profileId);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final albums = ref.watch(albumsProvider);
    final now = ref.watch(clockProvider)();
    final profiles = ref.watch(profilesByIdProvider);
    final live = ref.watch(albumRepositoryProvider) != null;
    final shared = live
        ? ref.watch(sharedAlbumsProvider).value ?? const <SharedAlbum>[]
        : const <SharedAlbum>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAlbumsTitle)),
      floatingActionButton: live
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_create(context, ref)),
              icon: const Icon(Icons.add),
              label: Text(l10n.newAlbum),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final album in albums) ...[
            ListTile(
              leading: Icon(
                album.isPrivate
                    ? Icons.lock_outline
                    : Icons.photo_library_outlined,
              ),
              title: Text(album.name),
              subtitle: Text(
                album.activeGrants(now).isEmpty
                    ? '${l10n.albumPhotos(album.photoCount)} · '
                          '${l10n.albumNotShared}'
                    : '${l10n.albumPhotos(album.photoCount)} · '
                          '${l10n.albumSharedCount(
                            album.activeGrants(now).length,
                          )}',
              ),
              onTap: live
                  ? () => context.push(AppRoutes.album(album.id))
                  : null,
            ),
            for (final grant in album.activeGrants(now))
              ListTile(
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 72,
                  end: 16,
                ),
                title: Text(
                  l10n.sharedWith(
                    profiles[grant.profileId]?.name ?? l10n.unknownMember,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: TextButton(
                  onPressed: () => unawaited(
                    _revoke(context, ref, album.id, grant.profileId),
                  ),
                  child: Text(l10n.revoke),
                ),
              ),
            const Divider(),
          ],
          if (shared.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.sharedWithYou,
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final album in shared)
              ListTile(
                leading: const Icon(Icons.folder_shared_outlined),
                title: Text(album.name),
                subtitle: Text(
                  '${profiles[album.ownerId]?.name ?? l10n.unknownMember} · '
                  '${l10n.albumPhotos(album.photoCount)}',
                ),
                trailing: Text(l10n.openAlbum),
                onTap: () => context.push(AppRoutes.album(album.id)),
              ),
          ],
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newAlbum),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(labelText: l10n.albumNameLabel),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
