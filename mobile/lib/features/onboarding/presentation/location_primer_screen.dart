import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W5: explains location use, then asks for "while using" permission and
/// saves the profile.
class LocationPrimerScreen extends ConsumerStatefulWidget {
  /// Creates the location primer.
  const LocationPrimerScreen({super.key});

  @override
  ConsumerState<LocationPrimerScreen> createState() =>
      _LocationPrimerScreenState();
}

class _LocationPrimerScreenState extends ConsumerState<LocationPrimerScreen> {
  bool _saving = false;

  Future<void> _finish({required bool shareLocation}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingProvider.notifier)
          .finish(shareLocation: shareLocation);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) context.go(AppRoutes.nearby);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Color(0xFF4ADE80)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return OnboardingScaffold(
      step: 3,
      actions: [
        FilledButton(
          onPressed: _saving ? null : () => _finish(shareLocation: true),
          child: Text(l10n.locationAllow),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : () => _finish(shareLocation: false),
          child: Text(l10n.locationNotNow),
        ),
      ],
      children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 44,
          backgroundColor: scheme.surfaceContainer,
          child: Icon(Icons.place_outlined, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 24),
        Text(l10n.locationTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        point(l10n.locationPointWhileUsing),
        point(l10n.locationPointRounded),
        point(l10n.locationPointHide),
      ],
    );
  }
}
