import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/session.dart';
import 'package:orbit/core/widgets/fill_or_scroll.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W1: first screen for signed-out users. Leads with the privacy promise.
/// On launch it resumes a stored session, so returning members go straight
/// to where they left off.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates the welcome screen.
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final router = GoRouter.of(context);
    final SessionDestination destination;
    try {
      destination = await ref.read(sessionProvider).restore();
    } on Exception {
      // Offline or the session expired: the member signs in again.
      return;
    }
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.appName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text(
                      l10n.welcomeHeadline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.welcomeTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _PrivacyPromise(text: l10n.welcomePrivacyPromise),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.signIn),
                child: Text(l10n.welcomeGetStarted),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeAgeNotice,
                textAlign: TextAlign.center,
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

class _PrivacyPromise extends StatelessWidget {
  const _PrivacyPromise({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
