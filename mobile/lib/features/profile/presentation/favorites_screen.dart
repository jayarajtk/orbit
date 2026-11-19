import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Profiles the member starred.
class FavoritesScreen extends ConsumerWidget {
  /// Creates the favorites screen.
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ids = ref.watch(favoritesProvider);
    final blocked = ref.watch(blockedProvider);
    final profiles = ref.watch(profilesByIdProvider);
    final favorites = [
      for (final id in ids)
        if (!blocked.contains(id)) ?profiles[id],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuFavorites)),
      body: favorites.isEmpty
          ? EmptyState(icon: Icons.star_border, message: l10n.favoritesEmpty)
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final p = favorites[index];
                return ListTile(
                  leading: ProfileAvatar(
                    name: p.name,
                    seed: p.id,
                    photoUrl: p.thumbUrl,
                    mediaId: p.thumbMediaId,
                    ownerId: p.id,
                  ),
                  title: Text(l10n.nameWithAge(p.name, p.age)),
                  subtitle: Text(l10n.distance(p.distanceKm)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.profile(p.id)),
                );
              },
            ),
    );
  }
}
