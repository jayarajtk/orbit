import 'package:orbit/core/widgets/media_image.dart';

/// Records what the app asks of the image cache and never touches the disk
/// (the real one needs platform channels that widget tests don't have).
class FakeImageCache extends OrbitImageCache {
  /// Calls in order, as `clearAll` or `evictOwner:<id>`.
  final List<String> calls = [];

  @override
  Future<void> clearAll() async => calls.add('clearAll');

  @override
  Future<void> evictOwner(String ownerId) async =>
      calls.add('evictOwner:$ownerId');
}
