import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/status/domain/status.dart';

/// 24-hour photo statuses.
abstract interface class StatusRepository {
  /// Posts the uploaded status photo [mediaId]. Throws [ApiException]
  /// (`status-limit`, `invalid-status`).
  Future<MyStatus> post(String mediaId, {String? caption});

  /// The user's live statuses, newest first, with their viewers.
  Future<List<MyStatus>> mine();

  /// Deletes one of the user's statuses.
  Future<void> delete(String id);

  /// [profileId]'s live statuses, oldest first.
  Future<List<StatusItem>> of(String profileId);

  /// Records that the user viewed [id].
  Future<void> markViewed(String id);
}

/// Statuses: the API when configured, else in memory.
final statusRepositoryProvider = Provider<StatusRepository>(
  (ref) => AppEnv.usesApi
      ? ApiStatusRepository(ref.watch(dioProvider))
      : FakeStatusRepository(),
);

/// [StatusRepository] on the Orbit API.
class ApiStatusRepository implements StatusRepository {
  /// Creates the repository on [_dio].
  ApiStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<MyStatus> post(String mediaId, {String? caption}) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/me/statuses',
          data: {'mediaId': mediaId, 'caption': ?caption},
        );
        return MyStatus.fromJson(response.data!);
      });

  @override
  Future<List<MyStatus>> mine() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/me/statuses');
    return [
      for (final item in response.data!)
        MyStatus.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> delete(String id) =>
      guardApi(() => _dio.delete<void>('/me/statuses/$id'));

  @override
  Future<List<StatusItem>> of(String profileId) => guardApi(() async {
    final response = await _dio.get<List<dynamic>>(
      '/profiles/$profileId/statuses',
    );
    return [
      for (final item in response.data!)
        StatusItem.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> markViewed(String id) =>
      guardApi(() => _dio.put<void>('/statuses/$id/view'));
}

/// Demo mode: the user's own statuses live in memory. Other members show a
/// ring on the grid but have no photos to open.
class FakeStatusRepository implements StatusRepository {
  final List<MyStatus> _mine = [];
  var _nextId = 1;

  @override
  Future<MyStatus> post(String mediaId, {String? caption}) async {
    final now = DateTime.now().toUtc();
    final status = MyStatus(
      id: 'demo-status-${_nextId++}',
      url: '',
      caption: caption,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      viewCount: 0,
      viewers: const [],
    );
    _mine.insert(0, status);
    return status;
  }

  @override
  Future<List<MyStatus>> mine() async => List.unmodifiable(_mine);

  @override
  Future<void> delete(String id) async => _mine.removeWhere((s) => s.id == id);

  @override
  Future<List<StatusItem>> of(String profileId) async => const [];

  @override
  Future<void> markViewed(String id) async {}
}
