import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/features/safety/data/safety_repository.dart';

export 'package:orbit/features/safety/data/safety_repository.dart'
    show ReportReason;

/// A report the user filed.
class Report {
  /// Creates a report.
  const Report({required this.profileId, required this.reason});

  /// Who was reported.
  final String profileId;

  /// Why.
  final ReportReason reason;
}

/// Blocked members as id → display name. Blocks are two-way: neither member
/// sees the other. The map is the UI's source of truth; changes are sent to
/// the server first and only applied locally once it accepts them.
final blockedProvider = NotifierProvider<BlockedNotifier, Set<String>>(
  BlockedNotifier.new,
);

/// Display names of blocked members, for the "Blocked users" screen.
final blockedNamesProvider =
    NotifierProvider<BlockedNamesNotifier, Map<String, String>>(
      BlockedNamesNotifier.new,
    );

/// Holds names of blocked members.
class BlockedNamesNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// Replaces all names (after loading from the server).
  void replaceAll(Map<String, String> names) => state = Map.unmodifiable(names);

  /// Remembers [name] for [id].
  void put(String id, String name) => state = {...state, id: name};
}

/// Blocked member ids, synced with the server.
class BlockedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  SafetyRepository get _repository => ref.read(safetyRepositoryProvider);

  /// Blocks [id] (named [name] for the blocked list).
  Future<void> block(String id, {required String name}) async {
    await _repository.block(id);
    await _add(id, name);
  }

  /// Unblocks [id].
  Future<void> unblock(String id) async {
    await _repository.unblock(id);
    state = {...state}..remove(id);
  }

  /// Reports [id]; with [alsoBlock] they are blocked too. A [statusId] makes
  /// the report about one of their statuses.
  Future<void> report(
    String id,
    ReportReason reason, {
    required String name,
    required bool alsoBlock,
    String? statusId,
  }) async {
    await _repository.report(
      id,
      reason,
      alsoBlock: alsoBlock,
      statusId: statusId,
    );
    ref
        .read(reportsProvider.notifier)
        .file(Report(profileId: id, reason: reason));
    if (alsoBlock) await _add(id, name);
  }

  /// Loads the blocked list from the server (after sign-in).
  Future<void> load() async {
    final blocked = await _repository.blocked();
    ref.read(blockedNamesProvider.notifier).replaceAll(blocked);
    state = blocked.keys.toSet();
  }

  Future<void> _add(String id, String name) async {
    ref.read(blockedNamesProvider.notifier).put(id, name);
    state = {...state, id};
    // The block already succeeded; a cache failure must not look like one.
    try {
      await ref.read(orbitImageCacheProvider).evictOwner(id);
    } on Exception catch (error, stack) {
      developer.log(
        "Could not evict a blocked member's cached images",
        name: 'orbit.safety',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// Reports filed this session.
final reportsProvider = NotifierProvider<ReportsNotifier, List<Report>>(
  ReportsNotifier.new,
);

/// Holds filed reports.
class ReportsNotifier extends Notifier<List<Report>> {
  @override
  List<Report> build() => const [];

  /// Records a filed report.
  void file(Report report) => state = [...state, report];
}
