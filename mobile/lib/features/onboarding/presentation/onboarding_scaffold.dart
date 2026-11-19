import 'package:flutter/material.dart';
import 'package:orbit/core/widgets/fill_or_scroll.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Shared layout for onboarding steps: back button, step progress, scrolling
/// content and the primary action pinned to the bottom when there's room.
class OnboardingScaffold extends StatelessWidget {
  /// Creates a step [step] of [totalSteps].
  const OnboardingScaffold({
    required this.step,
    required this.children,
    required this.actions,
    this.totalSteps = 3,
    super.key,
  });

  /// 1-based step number.
  final int step;

  /// Total steps.
  final int totalSteps;

  /// Step content.
  final List<Widget> children;

  /// Buttons at the bottom.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: l10n.stepOf(step, totalSteps),
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= totalSteps; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      decoration: BoxDecoration(
                        color: i <= step ? scheme.primary : scheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              const Spacer(),
              const SizedBox(height: 24),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
