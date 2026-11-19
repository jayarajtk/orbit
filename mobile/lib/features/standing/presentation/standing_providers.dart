import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/standing/data/standing_repository.dart';
import 'package:orbit/features/standing/domain/standing.dart';

/// The member's standing, fetched fresh each time a screen needs it.
/// Null in demo mode.
final FutureProvider<Standing?> standingProvider =
    FutureProvider.autoDispose<Standing?>(
      (ref) async => ref.watch(standingRepositoryProvider)?.standing(),
    );
