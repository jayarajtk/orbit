import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
import 'package:orbit/features/profile/presentation/my_photos_actions.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W13: the member's own hub.
class MeScreen extends ConsumerWidget {
  /// Creates the Me tab.
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myProfileProvider);
    final hasPlus = ref.watch(plusProvider);
    if (me == null) return const SizedBox.shrink();

    final items = [
      (Icons.edit_outlined, l10n.menuEditProfile, AppRoutes.editProfile),
      (Icons.photo_library_outlined, l10n.menuAlbums, AppRoutes.myAlbums),
      (Icons.star_border, l10n.menuFavorites, AppRoutes.favorites),
      (Icons.auto_awesome_outlined, l10n.menuPlus, AppRoutes.plus),
      (Icons.shield_outlined, l10n.menuSafety, AppRoutes.safety),
      (Icons.settings_outlined, l10n.menuSettings, AppRoutes.settings),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.meTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              // Posting a status arrives with the status feature.
              MeAvatar(onAddStatus: () {}),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.nameAge(me.displayName, me.age),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        if (hasPlus) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(l10n.orbitPlus),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: me.completionPercent / 100,
                      borderRadius: BorderRadius.circular(3),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.profileComplete(me.completionPercent),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (icon, label, route) in items)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(route),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero tag shared by the avatar and the first page of the photo viewer.
const myMainPhotoHeroTag = 'my-main-photo';

/// The member's own picture. Tapping it opens their photos full screen, or
/// the picker when they have none. A "+" badge starts a status when
/// [onAddStatus] is set.
class MeAvatar extends ConsumerWidget {
  /// Creates the avatar.
  const MeAvatar({this.onAddStatus, super.key});

  /// Called when the "+" badge is tapped; the badge is hidden when null.
  final VoidCallback? onAddStatus;

  static const _size = 84.0;
  static const _badge = 32.0;

  Future<void> _addFirstPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (picked == null || !context.mounted) return;
    await runPhotoAction(
      context,
      () => ref.read(myPhotosActionsProvider).add(picked),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(myProfileProvider);
    if (me == null) return const SizedBox.shrink();
    final main = me.photos.isEmpty ? null : me.photos.first;
    final onAddStatus = this.onAddStatus;
    return SizedBox.square(
      dimension: _size + _badge / 2,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Semantics(
              button: true,
              label: main == null ? l10n.photoAdd : l10n.openMyPhotos,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => main == null
                    ? _addFirstPhoto(context, ref)
                    : context.push('${AppRoutes.myPhotos}?index=0'),
                child: Hero(
                  tag: myMainPhotoHeroTag,
                  child: ProfileAvatar(
                    name: me.displayName,
                    seed: 'me',
                    size: _size,
                    photoUrl: main?.thumbUrl,
                    mediaId: main?.id,
                  ),
                ),
              ),
            ),
          ),
          if (onAddStatus != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: l10n.addStatusTooltip,
                iconSize: 18,
                constraints: const BoxConstraints.tightFor(
                  width: _badge,
                  height: _badge,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add),
                onPressed: onAddStatus,
              ),
            ),
        ],
      ),
    );
  }
}
