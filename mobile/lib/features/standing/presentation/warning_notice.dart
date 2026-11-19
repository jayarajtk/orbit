import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/standing/data/standing_repository.dart';
import 'package:orbit/features/standing/domain/standing.dart';
import 'package:orbit/features/standing/presentation/policy_label.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Shows each warning the member hasn't seen yet, one dialog at a time, and
/// marks it seen once dismissed (ADR-0007). Does nothing in demo mode or if
/// the check fails; it runs again on the next launch.
Future<void> showPendingWarnings(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(standingRepositoryProvider);
  if (repository == null) return;
  final List<Warning> warnings;
  try {
    warnings = (await repository.standing()).warnings;
  } on Exception {
    return;
  }
  for (final warning in warnings) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WarningDialog(warning: warning),
    );
    unawaited(repository.acknowledge(warning.id).catchError((Object _) {}));
  }
}

class _WarningDialog extends StatelessWidget {
  const _WarningDialog({required this.warning});

  final Warning warning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.warningTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.warningBecause(policyLabel(l10n, warning.policy))),
          if (warning.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(warning.message),
          ],
          const SizedBox(height: 12),
          Text(l10n.warningFooter),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.warningAcknowledge),
        ),
      ],
    );
  }
}
