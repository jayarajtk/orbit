import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W13: the user's own hub. Placeholder until the profile API exists.
class MeScreen extends StatelessWidget {
  /// Creates the Me tab.
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.meTitle)));
  }
}
