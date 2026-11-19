import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';

/// Why a member was reported.
enum ReportReason {
  /// Fake profile or spam.
  fake('FAKE'),

  /// Harassment.
  harassment('HARASSMENT'),

  /// May be under 18 (routed to the priority queue).
  underage('UNDERAGE'),

  /// Inappropriate photos.
  photos('PHOTOS'),

  /// Threat or danger.
  threat('THREAT')
  ;

  const ReportReason(this.apiValue);

  /// Value used by the API.
  final String apiValue;
}

/// Blocks and reports on the server.
abstract interface class SafetyRepository {
  /// Blocks member [id] (two-way).
  Future<void> block(String id);

  /// Removes the block on [id].
  Future<void> unblock(String id);

  /// Reports [id]; with [alsoBlock] the server blocks them too. A [statusId]
  /// of one of their statuses is kept as evidence.
  Future<void> report(
    String id,
    ReportReason reason, {
    required bool alsoBlock,
    String? statusId,
  });

  /// Members the user blocked, as id → display name.
  Future<Map<String, String>> blocked();
}

/// The configured [SafetyRepository].
final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => AppEnv.usesApi
      ? ApiSafetyRepository(ref.watch(dioProvider))
      : const DemoSafetyRepository(),
);

/// Demo mode: nothing to sync; state lives on the device.
class DemoSafetyRepository implements SafetyRepository {
  /// Creates the demo repository.
  const DemoSafetyRepository();

  @override
  Future<void> block(String id) async {}

  @override
  Future<void> unblock(String id) async {}

  @override
  Future<void> report(
    String id,
    ReportReason reason, {
    required bool alsoBlock,
    String? statusId,
  }) async {}

  @override
  Future<Map<String, String>> blocked() async => const {};
}

/// Blocks and reports through the Orbit API.
class ApiSafetyRepository implements SafetyRepository {
  /// Creates the repository on [_dio].
  ApiSafetyRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> block(String id) =>
      guardApi(() => _dio.post<void>('/blocks', data: {'accountId': id}));

  @override
  Future<void> unblock(String id) =>
      guardApi(() => _dio.delete<void>('/blocks/$id'));

  @override
  Future<void> report(
    String id,
    ReportReason reason, {
    required bool alsoBlock,
    String? statusId,
  }) => guardApi(
    () => _dio.post<void>(
      '/reports',
      data: {
        'accountId': id,
        'reason': reason.apiValue,
        'alsoBlock': alsoBlock,
        'statusId': ?statusId,
      },
    ),
  );

  @override
  Future<Map<String, String>> blocked() {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>('/me/blocked');
      return {
        for (final item in response.data!.cast<Map<String, dynamic>>())
          item['accountId'] as String: item['displayName'] as String,
      };
    });
  }
}
