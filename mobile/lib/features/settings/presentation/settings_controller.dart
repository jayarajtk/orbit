import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/settings/domain/app_settings.dart';

/// Privacy and security settings.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Holds settings. In memory until the settings API exists.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  /// Applies [change] to the current settings.
  void update(AppSettings Function(AppSettings) change) {
    state = change(state);
  }
}
