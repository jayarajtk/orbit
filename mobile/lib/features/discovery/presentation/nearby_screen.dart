import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W6: nearby grid. Shows its empty state until the discovery API exists.
class NearbyScreen extends StatelessWidget {
  /// Creates the Nearby tab.
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: EmptyState(
        icon: Icons.grid_view_outlined,
        message: l10n.nearbyEmpty,
      ),
    );
  }
}
