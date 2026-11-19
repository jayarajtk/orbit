import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:orbit/app/env.dart';

/// Signs the member in with the identity provider and holds their tokens.
abstract interface class AuthRepository {
  /// Runs the sign-in flow. Throws [SignInCancelled] if the user backs out.
  Future<void> signIn();

  /// A valid access token, refreshing it if needed; null when signed out.
  Future<String?> accessToken({bool forceRefresh = false});

  /// Forgets the tokens and ends the provider session.
  Future<void> signOut();
}

/// The user closed the sign-in sheet.
class SignInCancelled implements Exception {
  /// Creates the exception.
  const SignInCancelled();
}

/// The configured [AuthRepository]: OIDC (Authorization Code + PKCE) when an
/// API is configured, otherwise a no-op for demo mode.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppEnv.usesApi ? OidcAuthRepository() : const DemoAuthRepository(),
);

/// Demo mode: nothing to sign in to.
class DemoAuthRepository implements AuthRepository {
  /// Creates the demo repository.
  const DemoAuthRepository();

  @override
  Future<void> signIn() async {}

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> signOut() async {}
}

/// Authorization Code + PKCE through the system browser sheet. Tokens live
/// in the Keychain (iOS) or Keystore-backed storage (Android), never in
/// shared preferences.
class OidcAuthRepository implements AuthRepository {
  /// Creates the repository.
  OidcAuthRepository({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? storage,
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'orbit.access_token';
  static const _refreshKey = 'orbit.refresh_token';
  static const _idKey = 'orbit.id_token';
  static const _expiryKey = 'orbit.access_expiry';
  static const _scopes = ['openid', 'profile', 'offline_access'];
  static const _refreshMargin = Duration(seconds: 30);

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;
  Future<String?>? _refreshing;

  @override
  Future<void> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppEnv.oidcClientId,
          AppEnv.oidcRedirectUri,
          issuer: AppEnv.oidcIssuer,
          scopes: _scopes,
          allowInsecureConnections: AppEnv.allowsInsecure,
          externalUserAgent:
              ExternalUserAgent.ephemeralAsWebAuthenticationSession,
        ),
      );
      await _store(result);
    } on FlutterAppAuthUserCancelledException {
      throw const SignInCancelled();
    }
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    final token = await _storage.read(key: _accessKey);
    if (token == null) return null;
    final expiry = DateTime.tryParse(
      await _storage.read(key: _expiryKey) ?? '',
    );
    final fresh =
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc().add(_refreshMargin));
    if (fresh && !forceRefresh) return token;
    // Single-flight: concurrent callers share one refresh.
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) return null;
    try {
      final result = await _appAuth.token(
        TokenRequest(
          AppEnv.oidcClientId,
          AppEnv.oidcRedirectUri,
          issuer: AppEnv.oidcIssuer,
          refreshToken: refreshToken,
          scopes: _scopes,
          allowInsecureConnections: AppEnv.allowsInsecure,
        ),
      );
      await _store(result);
      return result.accessToken;
    } on FlutterAppAuthPlatformException {
      // Refresh token expired or revoked: the member must sign in again.
      await _clear();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final idToken = await _storage.read(key: _idKey);
    await _clear();
    if (idToken == null) return;
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          postLogoutRedirectUrl: AppEnv.oidcRedirectUri,
          issuer: AppEnv.oidcIssuer,
          allowInsecureConnections: AppEnv.allowsInsecure,
          externalUserAgent:
              ExternalUserAgent.ephemeralAsWebAuthenticationSession,
        ),
      );
    } on FlutterAppAuthPlatformException {
      // Local tokens are already gone; a failed provider logout is harmless.
    }
  }

  Future<void> _store(TokenResponse result) async {
    await _storage.write(key: _accessKey, value: result.accessToken);
    await _storage.write(key: _refreshKey, value: result.refreshToken);
    await _storage.write(key: _idKey, value: result.idToken);
    await _storage.write(
      key: _expiryKey,
      value: result.accessTokenExpirationDateTime?.toUtc().toIso8601String(),
    );
  }

  Future<void> _clear() async {
    for (final key in [_accessKey, _refreshKey, _idKey, _expiryKey]) {
      await _storage.delete(key: key);
    }
  }
}
