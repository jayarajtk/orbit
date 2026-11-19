import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_ago.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Opens the "Viewed by" sheet for one of the user's own statuses, newest
/// viewer first. [now] is the app clock, for the "ago" labels.
Future<void> showViewersSheet(
  BuildContext context, {
  required List<StatusSeenBy> viewers,
  required DateTime now,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _ViewersSheet(
    viewers: [...viewers]..sort((a, b) => b.viewedAt.compareTo(a.viewedAt)),
    now: now,
  ),
);

class _ViewersSheet extends StatelessWidget {
  const _ViewersSheet({required this.viewers, required this.now});

  final List<StatusSeenBy> viewers;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
          child: Semantics(
            header: true,
            child: Text(l10n.statusViewedBy, style: theme.textTheme.titleLarge),
          ),
        ),
        if (viewers.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 32),
            child: Text(
              l10n.statusNoViewers,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: viewers.length,
              itemBuilder: (context, i) {
                final viewer = viewers[i];
                return ListTile(
                  leading: ProfileAvatar(
                    name: viewer.name,
                    seed: viewer.id,
                    size: 40,
                    photoUrl: viewer.thumbUrl,
                  ),
                  title: Text(viewer.name),
                  trailing: Text(
                    statusAgoLabel(l10n, now, viewer.viewedAt),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
