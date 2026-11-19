import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W4: display name and what the member is looking for.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Creates the profile setup step.
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(onboardingProvider).displayName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      step: 2,
      actions: [
        FilledButton(
          onPressed: draft.displayName.trim().isEmpty
              ? null
              : () => context.push(AppRoutes.onboardingLocation),
          child: Text(l10n.continueButton),
        ),
      ],
      children: [
        Text(l10n.profileSetupTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          onChanged: controller.setDisplayName,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: l10n.displayNameLabel,
            hintText: l10n.displayNameHint,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.lookingForLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final goal in LookingFor.values)
              FilterChip(
                label: Text(l10n.lookingFor(goal)),
                selected: draft.lookingFor.contains(goal),
                onSelected: (_) => controller.toggleLookingFor(goal),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.photoLaterNote,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
