import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/auth/auth_repository.dart';
import 'package:orbit/core/network/account_restriction.dart';

/// A failed API call, from the server's RFC 9457 problem or the network.
class ApiException implements Exception {
  /// Creates an exception.
  const ApiException({required this.status, required this.type, this.detail});

  /// HTTP status, or 0 when the server could not be reached.
  final int status;

  /// Problem type without the `urn:orbit:problem:` prefix (e.g.
  /// `age-requirement`), `network` when offline, or `about:blank`.
  final String type;

  /// Human-readable detail from the server, if any.
  final String? detail;

  /// Whether this is the given problem type.
  bool isProblem(String problemType) => type == problemType;

  @override
  String toString() => 'ApiException($status, $type)';
}

/// Dio configured for the Orbit API: base URL, timeouts, bearer token, one
/// retry after a forced token refresh on 401, problem+json errors converted
/// to [ApiException], and `account-restricted` reported to
/// [accountRestrictedProvider] wherever it comes from.
final dioProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: '${AppEnv.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.addAll([
    _AuthInterceptor(auth, dio),
    AccountRestrictionInterceptor(
      () => ref.read(accountRestrictedProvider.notifier).flag(),
    ),
  ]);
  return dio;
});

/// Spots `403 account-restricted` on any request (ADR-0007) and reports it.
class AccountRestrictionInterceptor extends Interceptor {
  /// Calls [_onRestricted] whenever the server says the member is suspended
  /// or banned.
  AccountRestrictionInterceptor(this._onRestricted);

  final void Function() _onRestricted;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        toApiException(err).isProblem('account-restricted')) {
      _onRestricted();
    }
    handler.next(err);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._auth, this._dio);

  static const _retriedKey = 'orbit.retried';

  final AuthRepository _auth;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _auth.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode == 401 && options.extra[_retriedKey] != true) {
      final token = await _auth.accessToken(forceRefresh: true);
      if (token != null) {
        options
          ..extra[_retriedKey] = true
          ..headers['Authorization'] = 'Bearer $token';
        try {
          return handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      }
    }
    handler.next(err);
  }
}

/// Converts a [DioException] into an [ApiException].
ApiException toApiException(DioException error) {
  final response = error.response;
  if (response == null) {
    return const ApiException(status: 0, type: 'network');
  }
  final data = response.data;
  var type = 'about:blank';
  String? detail;
  if (data is Map<String, dynamic>) {
    final rawType = data['type'];
    if (rawType is String) {
      type = rawType.replaceFirst('urn:orbit:problem:', '');
    }
    final rawDetail = data['detail'];
    if (rawDetail is String) detail = rawDetail;
  }
  return ApiException(
    status: response.statusCode ?? 0,
    type: type,
    detail: detail,
  );
}

/// Runs [call] and rethrows any [DioException] as an [ApiException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw toApiException(e);
  }
}
