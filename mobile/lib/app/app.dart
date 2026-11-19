import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Root widget: theme, localization and routing.
class OrbitApp extends ConsumerWidget {
  /// Creates the root widget.
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: buildOrbitTheme(Brightness.light),
      // `themeMode` stays at its default, ThemeMode.system, so the phone's
      // light or dark setting picks the theme.
      darkTheme: buildOrbitTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
