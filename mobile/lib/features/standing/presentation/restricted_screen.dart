import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/session.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/standing/data/standing_repository.dart';
import 'package:orbit/features/standing/domain/standing.dart';
import 'package:orbit/features/standing/presentation/policy_label.dart';
import 'package:orbit/features/standing/presentation/standing_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Why the account is suspended or banned, and the one appeal the member may
/// make (ADR-0007). The only screen a restricted member can reach.
class RestrictedScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RestrictedScreen({super.key});

  @override
  ConsumerState<RestrictedScreen> createState() => _RestrictedScreenState();
}

class _RestrictedScreenState extends ConsumerState<RestrictedScreen> {
  bool _checking = false;

  /// Asks the server again; if the member is active, resumes the session.
  Future<void> _checkAgain() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      final destination = await ref.read(sessionProvider).restore();
      if (!mounted) return;
      switch (destination) {
        case SessionDestination.restricted:
          ref.invalidate(standingProvider);
          messenger.showSnackBar(SnackBar(content: Text(l10n.stillRestricted)));
        case SessionDestination.home:
          router.go(AppRoutes.nearby);
        case SessionDestination.welcome ||
            SessionDestination.birthday ||
            SessionDestination.profileSetup:
          router.go(AppRoutes.welcome);
      }
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    await ref.read(sessionProvider).signOut();
    router.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final standing = ref.watch(standingProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.restrictedTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            switch (standing) {
              AsyncData(:final value?) => _StandingDetails(standing: value),
              AsyncError() => Text(l10n.actionFailed),
              _ => const Center(child: CircularProgressIndicator()),
            },
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _checking ? null : () => unawaited(_checkAgain()),
              child: Text(l10n.checkAgain),
            ),
            TextButton(
              onPressed: () => unawaited(_signOut()),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingDetails extends StatelessWidget {
  const _StandingDetails({required this.standing});

  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final restriction = standing.restriction;
    final until = standing.suspendedUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          standing.banned ? l10n.bannedHeading : l10n.suspendedHeading,
          style: theme.textTheme.headlineSmall,
        ),
        if (!standing.banned && until != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.suspendedUntil(
              DateFormat.yMMMd().add_jm().format(until.toLocal()),
            ),
          ),
        ],
        if (restriction != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.restrictedBecause(policyLabel(l10n, restriction.policy)),
          ),
          if (restriction.message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.messageFromSafetyTeam,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(restriction.message),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _AppealSection(restriction: restriction),
        ],
      ],
    );
  }
}

class _AppealSection extends ConsumerStatefulWidget {
  const _AppealSection({required this.restriction});

  final Restriction restriction;

  @override
  ConsumerState<_AppealSection> createState() => _AppealSectionState();
}

class _AppealSectionState extends ConsumerState<_AppealSection> {
  static const _maxLength = 1000;

  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _text.text.trim();
    final repository = ref.read(standingRepositoryProvider);
    if (text.isEmpty || repository == null) return;
    setState(() => _sending = true);
    try {
      await repository.appeal(text);
      ref.invalidate(standingProvider);
    } on ApiException catch (e) {
      // Already appealed (e.g. on another device): show the refreshed state.
      if (e.isProblem('appeal-exists')) {
        ref.invalidate(standingProvider);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appeal = widget.restriction.appeal;
    if (appeal != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appealHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(switch (appeal.status) {
            AppealStatus.open => l10n.appealPending,
            AppealStatus.upheld => l10n.appealUpheld,
            AppealStatus.reversed => l10n.appealReversed,
          }),
          if (appeal.decisionMessage case final message?
              when message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message),
          ],
        ],
      );
    }
    if (!widget.restriction.canAppeal) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.appealHeading, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.appealIntro),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLength: _maxLength,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: l10n.appealLabel,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _sending || _text.text.trim().isEmpty
              ? null
              : () => unawaited(_send()),
          child: Text(l10n.sendAppeal),
        ),
      ],
    );
  }
}
