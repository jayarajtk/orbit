import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/features/chat/domain/message.dart';

/// Waves one member may send another within [waveWindow]. Mirrors the
/// server's `orbit.chat.wave-limit`, which is what actually enforces it.
const int waveLimit = 2;

/// The rolling window the wave limit is counted over.
const Duration waveWindow = Duration(hours: 24);

/// When waving at a member unlocks again, per profile id; null when the
/// member may wave. Cleared on read once the time has passed.
final NotifierProviderFamily<WaveLimit, DateTime?, String> waveLimitProvider =
    NotifierProvider.family<WaveLimit, DateTime?, String>(WaveLimit.new);

/// The wave lock for one recipient.
class WaveLimit extends Notifier<DateTime?> {
  /// Creates the lock for [profileId].
  WaveLimit(this.profileId);

  /// The member being waved at.
  final String profileId;

  @override
  DateTime? build() => null;

  DateTime get _now => ref.read(clockProvider)();

  /// Locks waving until [retryAt].
  void block(DateTime retryAt) {
    state = retryAt.isAfter(_now) ? retryAt : null;
  }

  /// Locks waving when [messages] hold [waveLimit] or more of the user's
  /// stored waves from the last [waveWindow] before [now]; otherwise leaves
  /// the lock as it is.
  void fromHistory(List<Message> messages, DateTime now) {
    final since = now.subtract(waveWindow);
    final waves = [
      for (final m in messages)
        if (m.fromMe &&
            m.kind == MessageKind.wave &&
            m.status != DeliveryStatus.pending &&
            m.status != DeliveryStatus.failed &&
            m.sentAt.isAfter(since))
          m.sentAt,
    ]..sort();
    if (waves.length < waveLimit) return;
    block(waves[waves.length - waveLimit].add(waveWindow));
  }

  /// Drops the lock once its time has passed.
  void clear() => state = null;
}

/// When waving at a profile id unlocks, or null when it is allowed now.
///
/// Checked against the app clock on every read, and an expired lock is
/// cleared from [waveLimitProvider].
final ProviderFamily<DateTime?, String> waveBlockedUntilProvider =
    Provider.family<DateTime?, String>((
      ref,
      profileId,
    ) {
      final retryAt = ref.watch(waveLimitProvider(profileId));
      if (retryAt == null) return null;
      if (retryAt.isAfter(ref.read(clockProvider)())) return retryAt;
      unawaited(
        Future.microtask(() {
          if (ref.mounted) {
            ref.read(waveLimitProvider(profileId).notifier).clear();
          }
        }),
      );
      return null;
    });

/// A wave the server refused, so a screen can tell the member once.
class WaveRefusal {
  /// Creates the notice.
  const WaveRefusal(this.profileId, this.retryAt);

  /// The member who was waved at.
  final String profileId;

  /// When waving unlocks.
  final DateTime retryAt;
}

/// The latest refused wave. Each refusal is a new object, so listeners fire
/// every time.
final NotifierProvider<WaveRefusalNotifier, WaveRefusal?> waveRefusalProvider =
    NotifierProvider<WaveRefusalNotifier, WaveRefusal?>(
      WaveRefusalNotifier.new,
    );

/// Holds the latest [WaveRefusal].
class WaveRefusalNotifier extends Notifier<WaveRefusal?> {
  @override
  WaveRefusal? build() => null;

  /// The latest refusal; setting it announces a refused wave.
  WaveRefusal? get refusal => state;

  set refusal(WaveRefusal? value) => state = value;
}

/// How long to wait, for a button or message: whole hours rounded up
/// ("6h"), or whole minutes rounded up under an hour ("25m").
String waitLabel(Duration d) {
  if (d >= const Duration(hours: 1)) {
    return '${(d.inSeconds + 3599) ~/ 3600}h';
  }
  final minutes = (d.inSeconds + 59) ~/ 60;
  return '${minutes < 1 ? 1 : minutes}m';
}
