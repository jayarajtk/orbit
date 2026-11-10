import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W2: choose an identity provider.
///
/// Scaffold stage: every option goes straight to the Nearby tab. Real OIDC
/// sign-in replaces this once the identity provider is chosen (ADR-0005).
class SignInScreen extends StatelessWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    void continueToApp() => context.go(AppRoutes.nearby);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.signInTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                l10n.signInSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: continueToApp,
                child: Text(l10n.signInWithApple),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: continueToApp,
                child: Text(l10n.signInWithGoogle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: continueToApp,
                child: Text(l10n.signInWithPhone),
              ),
              const Spacer(),
              Text(
                l10n.signInNoPosting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
