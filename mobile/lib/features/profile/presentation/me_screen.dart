import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
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
              ProfileAvatar(
                name: me.displayName,
                seed: 'me',
                size: 84,
                photoUrl: me.photos.isEmpty ? null : me.photos.first.thumbUrl,
                mediaId: me.photos.isEmpty ? null : me.photos.first.id,
              ),
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
