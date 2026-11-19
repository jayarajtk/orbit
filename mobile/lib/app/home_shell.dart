import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/standing/presentation/warning_notice.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Bottom-tab scaffold for Nearby, Inbox and Me. Each tab keeps its own
/// navigation stack. On arrival it shows any warning from the safety team
/// the member hasn't seen yet.
class HomeShell extends ConsumerStatefulWidget {
  /// Creates the shell around the router's [shell].
  const HomeShell({required this.shell, super.key});

  /// Provided by `StatefulShellRoute`.
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(showPendingWarnings(context, ref)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(unreadTotalProvider);
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
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
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
