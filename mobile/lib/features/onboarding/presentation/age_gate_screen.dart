import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W3: birthday and the 18+ gate.
class AgeGateScreen extends ConsumerWidget {
  /// Creates the age gate.
  const AgeGateScreen({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final today = ref.read(clockProvider)();
    final chosen = ref.read(onboardingProvider).birthDate;
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.input,
      initialDate: chosen ?? DateTime(today.year - 25),
      firstDate: DateTime(today.year - 100),
      lastDate: today,
      helpText: AppLocalizations.of(context).ageGateHelp,
    );
    if (picked != null) {
      ref.read(onboardingProvider.notifier).setBirthDate(picked);
    }
  }

  /// Creates the account; the server re-checks the age.
  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(onboardingProvider.notifier).confirmBirthDate();
    } on UnderageException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.ageGateUnderage)));
      return;
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
      return;
    }
    await router.push(AppRoutes.onboardingProfile);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final birthDate = ref.watch(onboardingProvider).birthDate;
    final isAdult = ref.read(onboardingProvider.notifier).isAdult;

    return OnboardingScaffold(
      step: 1,
      actions: [
        FilledButton(
          onPressed: isAdult ? () => _confirm(context, ref) : null,
          child: Text(l10n.continueButton),
        ),
      ],
      children: [
        Text(l10n.ageGateTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        if (birthDate == null)
          OutlinedButton.icon(
            onPressed: () => _pickDate(context, ref),
            icon: const Icon(Icons.cake_outlined),
            label: Text(l10n.ageGatePick),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                MaterialLocalizations.of(context).formatMediumDate(birthDate),
              ),
              trailing: TextButton(
                onPressed: () => _pickDate(context, ref),
                child: Text(l10n.ageGateChange),
              ),
            ),
          ),
        if (birthDate != null && !isAdult) ...[
          const SizedBox(height: 12),
          Text(
            l10n.ageGateUnderage,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.ageGateBody,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
