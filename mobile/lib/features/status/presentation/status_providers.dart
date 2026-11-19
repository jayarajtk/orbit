import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
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

  /// Fetches the list again so new viewers and expiries show. Keeps the
  /// current list when the server can't be reached.
  Future<void> refresh() async {
    try {
      await _reload();
    } on ApiException catch (error, stack) {
      developer.log(
        'Could not refresh my statuses (status ${error.status})',
        name: 'orbit.status',
        stackTrace: stack,
      );
    }
  }

  Future<void> _reload() async {
    final statuses = await ref.read(statusRepositoryProvider).mine();
    if (ref.mounted) state = AsyncData(statuses);
  }
}

/// The user's statuses that have not expired by the app clock, so the Me
/// ring and the own viewer drop a status at its expiry even before the
/// server's list catches up.
final liveMyStatusesProvider = Provider<AsyncValue<List<MyStatus>>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(myStatusesProvider)
      .whenData(
        (statuses) => [
          for (final status in statuses)
            if (status.isLiveAt(now)) status,
        ],
      );
});

/// A member's live statuses (keyed by profile id), fetched on every visit.
final FutureProviderFamily<List<StatusItem>, String> profileStatusesProvider =
    FutureProvider.autoDispose.family<List<StatusItem>, String>(
      (ref, profileId) => ref.watch(statusRepositoryProvider).of(profileId),
    );

/// Owners whose every live status the user has now viewed, so rings turn
/// grey at once. Only until the grid's next answer: the server's ring wins
/// from then on, so a status posted since shows as unseen again.
final seenStatusOwnersProvider =
    NotifierProvider<SeenStatusOwnersNotifier, Set<String>>(
      SeenStatusOwnersNotifier.new,
    );

/// Holds the locally seen owners.
class SeenStatusOwnersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // A reload, not the grid's first load: that one answers nothing the
    // user has viewed since.
    ref.listen(allProfilesProvider, (previous, next) {
      final reloaded = (previous?.hasValue ?? false) && !next.isLoading;
      if (reloaded && next.hasValue && state.isNotEmpty) state = const {};
    });
    return const {};
  }

  /// Marks [ownerId] as seen.
  void markSeen(String ownerId) => state = {...state, ownerId};
}

/// The ring to draw for [p], counting [seenLocally] owners as seen.
StatusRing ringFor(Profile p, Set<String> seenLocally) =>
    p.status == StatusRing.unseen && seenLocally.contains(p.id)
    ? StatusRing.seen
    : p.status;

/// Why a status post failed.
enum StatusPostFailure {
  /// The member already has 10 live statuses.
  limit,

  /// The server could not use the photo.
  rejected,

  /// Anything else (offline, server error).
  other,
}

/// Where a status post stands.
class StatusPosting {
  const StatusPosting._(this.isPosting, this.failure);

  /// Nothing in flight.
  static const idle = StatusPosting._(false, null);

  /// An upload and post are in flight.
  static const posting = StatusPosting._(true, null);

  /// Whether a post is in flight.
  final bool isPosting;

  /// Set when the last post failed, until [StatusPostingNotifier.clear].
  final StatusPostFailure? failure;
}

/// Uploads and posts a status in the background, so the composer can close
/// at once and the Me avatar can show progress.
final statusPostingProvider =
    NotifierProvider<StatusPostingNotifier, StatusPosting>(
      StatusPostingNotifier.new,
    );

/// Runs one status post at a time.
class StatusPostingNotifier extends Notifier<StatusPosting> {
  // Invalidating the provider (sign-out) rebuilds this notifier rather than
  // unmounting it, so a post started before that is told apart by this count.
  int _generation = 0;

  @override
  StatusPosting build() {
    _generation++;
    return StatusPosting.idle;
  }

  /// Uploads [photo] and posts it with [caption]. Ignored while another post
  /// is in flight. A failure is left in [state] for the Me screen to show.
  Future<void> post(PickedMedia photo, {String? caption}) async {
    if (state.isPosting) return;
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    state = StatusPosting.posting;
    try {
      final media = ref.read(mediaRepositoryProvider);
      if (media == null) {
        throw UnsupportedError('Statuses need the media service (API mode).');
      }
      final uploaded = await media.upload(
        MediaPurpose.statusPhoto,
        photo.bytes,
        photo.contentType,
      );
      // Signing out resets this notifier mid-upload: the photo belongs to
      // the old session and must not be posted into the next one.
      if (!current()) return;
      await ref
          .read(myStatusesProvider.notifier)
          .post(uploaded.id, caption: caption);
      if (current()) state = StatusPosting.idle;
    } on ApiException catch (e) {
      if (!current()) return;
      state = StatusPosting._(
        false,
        e.isProblem('status-limit')
            ? StatusPostFailure.limit
            : e.status == 422
            ? StatusPostFailure.rejected
            : StatusPostFailure.other,
      );
    } on Object catch (e, stack) {
      // Not an API refusal (for example no media service): the cause goes to
      // the developer log, the member only learns it failed.
      developer.log('Status post failed', error: e, stackTrace: stack);
      if (current()) {
        state = const StatusPosting._(false, StatusPostFailure.other);
      }
    }
  }

  /// Forgets a shown failure.
  void clear() => state = StatusPosting.idle;
}
