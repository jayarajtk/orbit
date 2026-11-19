import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
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
  @override
  StatusPosting build() => StatusPosting.idle;

  /// Uploads [photo] and posts it with [caption]. Ignored while another post
  /// is in flight. A failure is left in [state] for the Me screen to show.
  Future<void> post(PickedMedia photo, {String? caption}) async {
    if (state.isPosting) return;
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
      await ref
          .read(myStatusesProvider.notifier)
          .post(uploaded.id, caption: caption);
      if (ref.mounted) state = StatusPosting.idle;
    } on ApiException catch (e) {
      if (!ref.mounted) return;
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
      if (ref.mounted) {
        state = const StatusPosting._(false, StatusPostFailure.other);
      }
    }
  }

  /// Forgets a shown failure.
  void clear() => state = StatusPosting.idle;
}
