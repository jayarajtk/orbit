import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/media_image.dart';

/// Records what is removed instead of touching the disk.
class _RecordingManager extends Fake implements BaseCacheManager {
  final List<String> removed = [];
  int emptied = 0;

  @override
  Future<void> removeFile(String key) async => removed.add(key);

  @override
  Future<void> emptyCache() async => emptied++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test, like every other test that builds the real managers:
  // they open their stores through path_provider, which tests don't have.
  testWidgets('status photos are cached for at most a day', (tester) async {
    expect(StatusImageCacheManager.stalePeriod, const Duration(hours: 24));
    expect(
      OrbitImageCache(manager: _RecordingManager()).statusManager,
      isA<StatusImageCacheManager>(),
    );
  });

  test('sign-out empties the status cache too', () async {
    final shared = _RecordingManager();
    final statuses = _RecordingManager();
    final cache = OrbitImageCache(manager: shared, statusManager: statuses);

    await cache.clearAll();

    expect(shared.emptied, 1);
    expect(statuses.emptied, 1);
  });

  test('blocking evicts the member from the status cache too', () async {
    final shared = _RecordingManager();
    final statuses = _RecordingManager();
    final cache = OrbitImageCache(manager: shared, statusManager: statuses)
      ..register('bob', ['s1:full']);

    await cache.evictOwner('bob');

    expect(shared.removed, ['s1:full']);
    expect(statuses.removed, ['s1:full']);
  });
}
