import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';

/// [ids] with the photo at [from] moved so it ends at index [to].
List<String> movePhoto(List<String> ids, int from, int to) {
  final moved = [...ids];
  moved.insert(to, moved.removeAt(from));
  return moved;
}

/// [ids] with [oldId] swapped for [newId], keeping its place.
List<String> replacePhoto(List<String> ids, String oldId, String newId) => [
  for (final id in ids) id == oldId ? newId : id,
];

/// [ids] with [id] moved to the front (the main photo).
List<String> makeMain(List<String> ids, String id) => [
  id,
  for (final other in ids)
    if (other != id) other,
];

/// [ids] without [id].
List<String> withoutPhoto(List<String> ids, String id) => [
  for (final other in ids)
    if (other != id) other,
];

/// The member's public photos, changed and saved at once. Shared by the
/// Edit profile grid and the photo viewer. Every method throws
/// `ApiException` when the server refuses, and then leaves
/// [myProfileProvider] as it was: the caller shows the error.
class MyPhotosActions {
  /// Creates the actions on [_ref].
  MyPhotosActions(this._ref);

  final Ref _ref;

  List<String> get _ids => [
    for (final p in _ref.read(myProfileProvider)?.photos ?? <ProfilePhoto>[])
      p.id,
  ];

  /// Uploads [picked] and appends it.
  Future<void> add(PickedMedia picked) async {
    final uploaded = await _upload(picked);
    await _save([..._ids, uploaded]);
  }

  /// Uploads [picked] in place of [oldId].
  Future<void> replace(String oldId, PickedMedia picked) async {
    final uploaded = await _upload(picked);
    await _save(replacePhoto(_ids, oldId, uploaded));
  }

  /// Makes [id] the main (first) photo.
  Future<void> makeMain(String id) => _save([id, ...withoutPhoto(_ids, id)]);

  /// Removes [id].
  Future<void> delete(String id) => _save(withoutPhoto(_ids, id));

  /// Moves the photo at [from] to index [to].
  Future<void> reorder(int from, int to) => _save(movePhoto(_ids, from, to));

  Future<String> _upload(PickedMedia picked) async {
    final media = _ref.read(mediaRepositoryProvider);
    if (media == null) {
      throw UnsupportedError('Photos need the media service (API mode).');
    }
    final uploaded = await media.upload(
      MediaPurpose.profilePhoto,
      picked.bytes,
      picked.contentType,
    );
    return uploaded.id;
  }

  Future<void> _save(List<String> ids) async {
    final saved = await _ref.read(accountRepositoryProvider).setPhotos(ids);
    _ref.read(myProfileProvider.notifier).save(saved);
  }
}

/// The shared photo actions.
final myPhotosActionsProvider = Provider<MyPhotosActions>(MyPhotosActions.new);
