import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/session.dart';
import 'package:orbit/core/auth/auth_repository.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/fill_or_scroll.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W2: sign in with the identity provider (Authorization Code + PKCE in the
/// system browser sheet). Locally every option opens the Keycloak login;
/// Apple, Google and phone brokering are configured with ADR-0005.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final destination = await ref.read(sessionProvider).signIn();
      switch (destination) {
        case SessionDestination.welcome:
          break;
        case SessionDestination.birthday:
          await router.push(AppRoutes.onboardingBirthday);
        case SessionDestination.profileSetup:
          await router.push(AppRoutes.onboardingProfile);
        case SessionDestination.home:
          router.go(AppRoutes.nearby);
        case SessionDestination.restricted:
          router.go(AppRoutes.restricted);
      }
    } on SignInCancelled {
      // Backed out of the sign-in sheet: stay here.
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.signInFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPressed = _busy ? null : _signIn;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: FillOrScroll(
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
                onPressed: onPressed,
                child: Text(l10n.signInWithApple),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onPressed,
                child: Text(l10n.signInWithGoogle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onPressed,
                child: Text(l10n.signInWithPhone),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
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
