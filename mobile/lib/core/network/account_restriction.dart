import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the server has said the member is suspended or banned
/// (`account-restricted`, ADR-0007). Raised by the API client and the chat
/// socket; the router then shows the restriction screen. Cleared when the
/// member is reinstated or signs out.
final accountRestrictedProvider = NotifierProvider<AccountRestriction, bool>(
  AccountRestriction.new,
);

/// Holds the restricted flag.
class AccountRestriction extends Notifier<bool> {
  @override
  bool build() => false;

  /// The server refused the member as suspended or banned.
  void flag() => state = true;

  /// The member is active again.
  void clear() => state = false;
}
