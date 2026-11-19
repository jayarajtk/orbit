import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

enum _Plan { monthly, yearly }

/// W17: the optional Orbit+ subscription.
///
/// Demo build: "Subscribe" unlocks Orbit+ locally without payment, so gated
/// features can be tried. Store billing replaces this.
class OrbitPlusScreen extends ConsumerStatefulWidget {
  /// Creates the Orbit+ screen.
  const OrbitPlusScreen({super.key});

  @override
  ConsumerState<OrbitPlusScreen> createState() => _OrbitPlusScreenState();
}

class _OrbitPlusScreenState extends ConsumerState<OrbitPlusScreen> {
  _Plan _plan = _Plan.yearly;

  void _subscribe() {
    ref.read(plusProvider.notifier).subscribe();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).plusWelcome)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasPlus = ref.watch(plusProvider);
    final perks = [
      l10n.perkMoreProfiles,
      l10n.perkFilters,
      l10n.perkIncognito,
      l10n.perkViewedMe,
      l10n.perkFavorites,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orbitPlus)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.plusIntro, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          for (final perk in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check, color: context.tokens.online),
                  const SizedBox(width: 12),
                  Expanded(child: Text(perk)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.plusSafetyFree),
            ),
          ),
          const SizedBox(height: 24),
          if (hasPlus) ...[
            Text(l10n.plusActive, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(plusProvider.notifier).cancel(),
              child: Text(l10n.plusCancel),
            ),
          ] else ...[
            Row(
              children: [
                for (final (plan, label) in [
                  (_Plan.monthly, l10n.planMonthly),
                  (_Plan.yearly, l10n.planYearly),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _PlanCard(
                        label: label,
                        badge: plan == _Plan.yearly ? l10n.planBestValue : null,
                        selected: _plan == plan,
                        onTap: () => setState(() => _plan = plan),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _subscribe,
              child: Text(l10n.plusSubscribe),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.plusDemoNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.planPriceTbd,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (badge case final text?) ...[
                  const SizedBox(height: 4),
                  Text(text, style: TextStyle(color: scheme.primary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
