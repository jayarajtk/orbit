import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W10: inbox. Shows its empty state until the chat API exists.
class InboxScreen extends StatelessWidget {
  /// Creates the Inbox tab.
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabInbox)),
      body: EmptyState(
        icon: Icons.chat_bubble_outline,
        message: l10n.inboxEmpty,
      ),
    );
  }
}
