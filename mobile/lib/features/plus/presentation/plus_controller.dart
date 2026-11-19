import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the member has Orbit+. Demo builds toggle it locally; store
/// billing and server-side entitlements replace this.
final plusProvider = NotifierProvider<PlusController, bool>(
  PlusController.new,
);

/// Holds the Orbit+ entitlement.
class PlusController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Turns Orbit+ on (demo only: no payment is taken).
  void subscribe() => state = true;

  /// Turns Orbit+ off.
  void cancel() => state = false;
}
