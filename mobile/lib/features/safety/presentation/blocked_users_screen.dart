import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Blocked members, with unblock.
class BlockedUsersScreen extends ConsumerWidget {
  /// Creates the blocked users screen.
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedProvider).toList();
    final profiles = ref.watch(profilesByIdProvider);
    final names = ref.watch(blockedNamesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingBlocked)),
      body: blocked.isEmpty
          ? EmptyState(icon: Icons.block, message: l10n.blockedEmpty)
          : ListView.builder(
              itemCount: blocked.length,
              itemBuilder: (context, index) {
                final id = blocked[index];
                final name =
                    names[id] ?? profiles[id]?.name ?? l10n.unknownMember;
                return ListTile(
                  leading: ProfileAvatar(name: name, seed: id),
                  title: Text(name),
                  trailing: TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(blockedProvider.notifier).unblock(id);
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.unblocked(name))),
                        );
                      } on ApiException {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.actionFailed)),
                        );
                      }
                    },
                    child: Text(l10n.unblock),
                  ),
                );
              },
            ),
    );
  }
}
