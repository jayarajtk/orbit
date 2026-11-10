import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Bottom-tab scaffold for Nearby, Inbox and Me. Each tab keeps its own
/// navigation stack.
class HomeShell extends StatelessWidget {
  /// Creates the shell around the router's [shell].
  const HomeShell({required this.shell, super.key});

  /// Provided by `StatefulShellRoute`.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            label: l10n.tabNearby,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.tabInbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: l10n.tabMe,
          ),
        ],
      ),
    );
  }
}
