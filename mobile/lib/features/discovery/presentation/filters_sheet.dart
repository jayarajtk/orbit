import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Opens W7, the filters bottom sheet.
Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _FiltersSheet(),
  );
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filters = ref.watch(filtersProvider);
    final notifier = ref.read(filtersProvider.notifier);
    final hasPlus = ref.watch(plusProvider);
    void set(DiscoveryFilters value) => notifier.update((_) => value);

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.filtersTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: notifier.reset,
                child: Text(l10n.filtersReset),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(l10n.filtersAge)),
              Text(l10n.filtersAgeRange(filters.minAge, filters.maxAge)),
            ],
          ),
          RangeSlider(
            min: DiscoveryFilters.minimumAge.toDouble(),
            max: DiscoveryFilters.maximumAge.toDouble(),
            divisions:
                DiscoveryFilters.maximumAge - DiscoveryFilters.minimumAge,
            values: RangeValues(
              filters.minAge.toDouble(),
              filters.maxAge.toDouble(),
            ),
            labels: RangeLabels('${filters.minAge}', '${filters.maxAge}'),
            onChanged: (range) => set(
              filters.copyWith(
                minAge: range.start.round(),
                maxAge: range.end.round(),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.filtersOnlineNow),
            value: filters.onlineOnly,
            onChanged: (value) => set(filters.copyWith(onlineOnly: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.filtersHasPhoto),
            value: filters.photoOnly,
            onChanged: (value) => set(filters.copyWith(photoOnly: value)),
          ),
          const SizedBox(height: 8),
          Text(l10n.lookingForLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final goal in LookingFor.values)
                FilterChip(
                  label: Text(l10n.lookingFor(goal)),
                  selected: filters.lookingFor.contains(goal),
                  onSelected: (selected) => set(
                    filters.copyWith(
                      lookingFor: selected
                          ? {...filters.lookingFor, goal}
                          : ({...filters.lookingFor}..remove(goal)),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 32),
          if (hasPlus)
            _DistanceFilter(filters: filters, onChanged: set)
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.filtersPlusLocked),
              trailing: Chip(
                avatar: const Icon(Icons.lock_outline, size: 16),
                label: Text(l10n.orbitPlus),
              ),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(AppRoutes.plus));
              },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.filtersShowResults),
          ),
        ],
      ),
    );
  }
}

class _DistanceFilter extends StatelessWidget {
  const _DistanceFilter({required this.filters, required this.onChanged});

  static const _anyDistance = 11;

  final DiscoveryFilters filters;
  final ValueChanged<DiscoveryFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final km = filters.maxDistanceKm ?? _anyDistance;
    final label = km == _anyDistance
        ? l10n.filtersAnyDistance
        : l10n.distance(km);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.filtersMaxDistance)),
            Text(label),
          ],
        ),
        Slider(
          min: 1,
          max: _anyDistance.toDouble(),
          divisions: _anyDistance - 1,
          value: km.toDouble(),
          label: label,
          onChanged: (value) {
            final rounded = value.round();
            onChanged(
              rounded == _anyDistance
                  ? filters.copyWith(clearMaxDistance: true)
                  : filters.copyWith(maxDistanceKm: rounded),
            );
          },
        ),
      ],
    );
  }
}
