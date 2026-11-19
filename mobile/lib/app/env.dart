/// Build-time configuration, supplied with
/// `--dart-define-from-file=config/<flavor>.json`. Holds no secrets: anything
/// in the app binary can be extracted.
abstract final class AppEnv {
  /// `dev`, `staging`, `prod` or `demo`.
  static const flavor = String.fromEnvironment(
    'ORBIT_FLAVOR',
    defaultValue: 'demo',
  );

  /// Base URL of the Orbit API, without the `/api/v1` suffix. Empty means
  /// demo mode: the app runs on built-in fake data with no server.
  static const apiBaseUrl = String.fromEnvironment('ORBIT_API_BASE_URL');

  /// OIDC issuer (Keycloak realm URL locally).
  static const oidcIssuer = String.fromEnvironment('ORBIT_OIDC_ISSUER');

  /// Public OIDC client id of the mobile app.
  static const oidcClientId = String.fromEnvironment(
    'ORBIT_OIDC_CLIENT_ID',
    defaultValue: 'orbit-mobile',
  );

  /// Redirect URI registered for the app's custom scheme.
  static const oidcRedirectUri = String.fromEnvironment(
    'ORBIT_OIDC_REDIRECT_URI',
    defaultValue: 'com.orbit.orbit:/oauthredirect',
  );

  /// Whether the app talks to a real server.
  static bool get usesApi => apiBaseUrl.isNotEmpty;

  /// Whether plain-HTTP endpoints are allowed (local development only).
  static bool get allowsInsecure =>
      apiBaseUrl.startsWith('http://localhost') ||
      apiBaseUrl.startsWith('http://10.0.2.2');
}
