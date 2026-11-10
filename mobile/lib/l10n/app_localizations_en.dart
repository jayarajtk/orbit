// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'orbit';

  @override
  String get welcomeHeadline => 'Meet people nearby.';

  @override
  String get welcomeTagline => 'Fast. Private. No ads — ever.';

  @override
  String get welcomePrivacyPromise =>
      'Your exact location is never stored — only a rounded area.';

  @override
  String get welcomeGetStarted => 'Get started';

  @override
  String get welcomeAgeNotice => '18+ only';

  @override
  String get signInTitle => 'Sign in to Orbit';

  @override
  String get signInSubtitle => 'Pick any. You can link more later.';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithPhone => 'Continue with phone number';

  @override
  String get signInNoPosting =>
      'We never post anything or show Orbit on your other accounts.';

  @override
  String get backTooltip => 'Back';

  @override
  String get tabNearby => 'Nearby';

  @override
  String get tabInbox => 'Inbox';

  @override
  String get tabMe => 'Me';

  @override
  String get nearbyEmpty => 'No one nearby yet — try widening your filters.';

  @override
  String get inboxEmpty => 'Say hi to someone nearby.';

  @override
  String get meTitle => 'Me';
}
