import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/session.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/features/settings/domain/app_settings.dart';
import 'package:orbit/features/settings/presentation/settings_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W15: privacy, security and data settings.
///
/// Demo build: switches change in-app state only. Discreet icon, shake to
/// hide and app lock need platform work and take effect once implemented.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(deletionRequested: true));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deleteRequested)),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(sessionProvider).signOut();
    router.go(AppRoutes.welcome);
  }

  Future<void> _setShowDistance(
    BuildContext context,
    WidgetRef ref,
    MyProfile me, {
    required bool show,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).actionFailed;
    try {
      final saved = await ref
          .read(accountRepositoryProvider)
          .saveProfile(me.copyWith(showDistance: show));
      ref.read(myProfileProvider.notifier).save(saved);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final me = ref.watch(myProfileProvider);
    final hasPlus = ref.watch(plusProvider);
    final notifier = ref.read(settingsProvider.notifier);
    void update(AppSettings Function(AppSettings) change) =>
        notifier.update(change);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          header(l10n.sectionPrivacy),
          SwitchListTile(
            title: Text(l10n.showDistance),
            value: me?.showDistance ?? true,
            onChanged: me == null
                ? null
                : (v) => _setShowDistance(context, ref, me, show: v),
          ),
          SwitchListTile(
            title: Text(l10n.settingReadReceipts),
            subtitle: Text(l10n.settingReadReceiptsSubtitle),
            value: settings.readReceipts,
            onChanged: (v) => update((s) => s.copyWith(readReceipts: v)),
          ),
          SwitchListTile(
            title: Text(l10n.settingPreviews),
            value: settings.messagePreviews,
            onChanged: (v) => update((s) => s.copyWith(messagePreviews: v)),
          ),
          if (hasPlus)
            SwitchListTile(
              title: Text(l10n.settingIncognito),
              subtitle: Text(l10n.settingIncognitoSubtitle),
              value: settings.incognito,
              onChanged: (v) => update((s) => s.copyWith(incognito: v)),
            )
          else
            ListTile(
              title: Text(l10n.settingIncognito),
              subtitle: Text(l10n.settingIncognitoSubtitle),
              trailing: Chip(
                avatar: const Icon(Icons.lock_outline, size: 16),
                label: Text(l10n.orbitPlus),
              ),
              onTap: () => context.push(AppRoutes.plus),
            ),
          header(l10n.sectionSecurity),
          SwitchListTile(
            title: Text(l10n.settingDiscreetIcon),
            subtitle: Text(l10n.settingDiscreetIconSubtitle),
            value: settings.discreetIcon,
            onChanged: (v) => update((s) => s.copyWith(discreetIcon: v)),
          ),
          SwitchListTile(
            title: Text(l10n.settingShake),
            value: settings.shakeToHide,
            onChanged: (v) => update((s) => s.copyWith(shakeToHide: v)),
          ),
          SwitchListTile(
            title: Text(l10n.settingAppLock),
            value: settings.appLock,
            onChanged: (v) => update((s) => s.copyWith(appLock: v)),
          ),
          header(l10n.sectionData),
          ListTile(
            title: Text(l10n.settingBlocked),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.blockedUsers),
          ),
          ListTile(
            title: Text(l10n.settingExport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.exportStarted)),
            ),
          ),
          ListTile(
            title: Text(
              l10n.settingDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: settings.deletionRequested
                ? Text(l10n.deleteRequested)
                : null,
            enabled: !settings.deletionRequested,
            onTap: () => _confirmDelete(context, ref),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.signOut),
            onTap: () => _signOut(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
