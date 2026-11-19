import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Opens W9, the block / report sheet. Completes with true if the member
/// was blocked, so callers can leave screens about them. A [statusId] makes
/// the report about that status, which the server keeps as evidence.
Future<bool> showSafetySheet(
  BuildContext context,
  Profile profile, {
  String? statusId,
}) async {
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SafetySheet(profile: profile, statusId: statusId),
  );
  return blocked ?? false;
}

class _SafetySheet extends ConsumerStatefulWidget {
  const _SafetySheet({required this.profile, this.statusId});

  final Profile profile;
  final String? statusId;

  @override
  ConsumerState<_SafetySheet> createState() => _SafetySheetState();
}

class _SafetySheetState extends ConsumerState<_SafetySheet> {
  ReportReason? _reason;
  bool _alsoBlock = true;
  bool _submitting = false;

  String get _name => widget.profile.name;

  Future<void> _block() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.blockConfirmTitle(_name)),
        content: Text(l10n.blockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.blockAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(blockedProvider.notifier)
          .block(widget.profile.id, name: _name);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.blockedSnack(_name))));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submitReport() async {
    final reason = _reason;
    if (reason == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref
          .read(blockedProvider.notifier)
          .report(
            widget.profile.id,
            reason,
            name: _name,
            alsoBlock: _alsoBlock,
            statusId: widget.statusId,
          );
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      if (mounted) setState(() => _submitting = false);
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.reportSent)));
    if (mounted) Navigator.of(context).pop(_alsoBlock);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reasons = {
      ReportReason.fake: l10n.reportFake,
      ReportReason.harassment: l10n.reportHarassment,
      ReportReason.underage: l10n.reportUnderage,
      ReportReason.photos: l10n.reportPhotos,
      ReportReason.threat: l10n.reportThreat,
    };

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _block,
            icon: Icon(Icons.block, color: theme.colorScheme.primary),
            label: Text(l10n.blockName(_name)),
          ),
          const SizedBox(height: 24),
          Text(l10n.reportTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.reportModeratorNote(_name),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              children: [
                for (final entry in reasons.entries)
                  RadioListTile<ReportReason>(
                    contentPadding: EdgeInsets.zero,
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _alsoBlock,
            onChanged: (value) => setState(() => _alsoBlock = value ?? false),
            title: Text(l10n.reportAlsoBlock(_name)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _reason == null || _submitting ? null : _submitReport,
            child: Text(l10n.reportSubmit),
          ),
        ],
      ),
    );
  }
}
