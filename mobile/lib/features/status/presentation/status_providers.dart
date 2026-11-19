import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/domain/status.dart';

/// The user's own live statuses.
final myStatusesProvider =
    AsyncNotifierProvider<MyStatusesNotifier, List<MyStatus>>(
      MyStatusesNotifier.new,
    );

/// Holds the user's statuses and posts or deletes them.
class MyStatusesNotifier extends AsyncNotifier<List<MyStatus>> {
  @override
  Future<List<MyStatus>> build() => ref.watch(statusRepositoryProvider).mine();

  /// Posts a status and reloads.
  Future<void> post(String mediaId, {String? caption}) async {
    await ref.read(statusRepositoryProvider).post(mediaId, caption: caption);
    await _reload();
  }

  /// Deletes a status.
  Future<void> delete(String id) async {
    await ref.read(statusRepositoryProvider).delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    final statuses = await ref.read(statusRepositoryProvider).mine();
    if (ref.mounted) state = AsyncData(statuses);
  }
}

/// A member's live statuses (keyed by profile id), fetched on every visit.
final FutureProviderFamily<List<StatusItem>, String> profileStatusesProvider =
    FutureProvider.autoDispose.family<List<StatusItem>, String>(
      (ref, profileId) => ref.watch(statusRepositoryProvider).of(profileId),
    );

/// Owners whose statuses the user has viewed this session, so rings turn
/// grey at once.
final seenStatusOwnersProvider =
    NotifierProvider<SeenStatusOwnersNotifier, Set<String>>(
      SeenStatusOwnersNotifier.new,
    );

/// Holds the locally seen owners.
class SeenStatusOwnersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Marks [ownerId] as seen.
  void markSeen(String ownerId) => state = {...state, ownerId};
}

/// The ring to draw for [p], counting [seenLocally] owners as seen.
StatusRing ringFor(Profile p, Set<String> seenLocally) =>
    p.status == StatusRing.unseen && seenLocally.contains(p.id)
    ? StatusRing.seen
    : p.status;
