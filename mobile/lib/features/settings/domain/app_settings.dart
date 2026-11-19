/// Privacy and security preferences. Defaults are private by default
/// (design doc §1): message text stays out of notifications.
class AppSettings {
  /// Creates settings.
  const AppSettings({
    this.readReceipts = true,
    this.messagePreviews = false,
    this.incognito = false,
    this.discreetIcon = false,
    this.shakeToHide = true,
    this.appLock = false,
    this.deletionRequested = false,
  });

  /// Whether others see when the user has read their messages.
  final bool readReceipts;

  /// Whether push notifications include message text.
  final bool messagePreviews;

  /// Orbit+ only: browse without appearing in grids.
  final bool incognito;

  /// Use a neutral app icon and name on the home screen.
  final bool discreetIcon;

  /// Shaking the phone hides the app.
  final bool shakeToHide;

  /// Require Face ID or a fingerprint to open the app.
  final bool appLock;

  /// The user asked to delete their account (14-day grace period).
  final bool deletionRequested;

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    bool? readReceipts,
    bool? messagePreviews,
    bool? incognito,
    bool? discreetIcon,
    bool? shakeToHide,
    bool? appLock,
    bool? deletionRequested,
  }) {
    return AppSettings(
      readReceipts: readReceipts ?? this.readReceipts,
      messagePreviews: messagePreviews ?? this.messagePreviews,
      incognito: incognito ?? this.incognito,
      discreetIcon: discreetIcon ?? this.discreetIcon,
      shakeToHide: shakeToHide ?? this.shakeToHide,
      appLock: appLock ?? this.appLock,
      deletionRequested: deletionRequested ?? this.deletionRequested,
    );
  }
}
