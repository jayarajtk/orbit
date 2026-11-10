/// Build-time configuration, supplied with
/// `--dart-define-from-file=config/<flavor>.json`. Holds no secrets: anything
/// in the app binary can be extracted.
abstract final class AppEnv {
  /// `dev`, `staging` or `prod`.
  static const flavor = String.fromEnvironment(
    'ORBIT_FLAVOR',
    defaultValue: 'dev',
  );

  /// Base URL of the Orbit API, without the `/api/v1` suffix.
  static const apiBaseUrl = String.fromEnvironment('ORBIT_API_BASE_URL');
}
