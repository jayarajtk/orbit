import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/standing/domain/standing.dart';

/// The member's own moderation standing (ADR-0007). These calls work while
/// the account is suspended or banned.
abstract interface class StandingRepository {
  /// Where the member stands, with any restriction and unseen warnings.
  Future<Standing> standing();

  /// Appeals the current suspension or ban. Throws [ApiException]
  /// (`appeal-exists`, `not-restricted`).
  Future<Appeal> appeal(String text);

  /// Marks a warning as seen.
  Future<void> acknowledge(String warningId);
}

/// The repository, or null in demo mode (nobody moderates demo members).
final standingRepositoryProvider = Provider<StandingRepository?>(
  (ref) =>
      AppEnv.usesApi ? ApiStandingRepository(ref.watch(dioProvider)) : null,
);

/// [StandingRepository] on the Orbit API.
class ApiStandingRepository implements StandingRepository {
  /// Creates the repository.
  ApiStandingRepository(this._dio);

  final Dio _dio;

  @override
  Future<Standing> standing() async {
    final response = await guardApi(
      () => _dio.get<Map<String, dynamic>>('/me/standing'),
    );
    return Standing.fromJson(response.data!);
  }

  @override
  Future<Appeal> appeal(String text) async {
    final response = await guardApi(
      () => _dio.post<Map<String, dynamic>>(
        '/me/appeals',
        data: {'text': text},
      ),
    );
    return Appeal.fromJson(response.data!);
  }

  @override
  Future<void> acknowledge(String warningId) =>
      guardApi(() => _dio.post<void>('/me/warnings/$warningId/ack'));
}
