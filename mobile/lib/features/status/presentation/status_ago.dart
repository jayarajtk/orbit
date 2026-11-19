import 'package:orbit/l10n/app_localizations.dart';

/// "Just now", "12m ago" or "3h ago" for something that happened at [then],
/// measured against [now] in local time.
String statusAgoLabel(AppLocalizations l10n, DateTime now, DateTime then) {
  final elapsed = now.toLocal().difference(then.toLocal());
  if (elapsed.inMinutes < 1) return l10n.statusAgo('now', 0);
  if (elapsed.inHours < 1) return l10n.statusAgo('minutes', elapsed.inMinutes);
  return l10n.statusAgo('hours', elapsed.inHours);
}
