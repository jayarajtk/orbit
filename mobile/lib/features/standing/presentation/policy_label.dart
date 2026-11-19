import 'package:orbit/l10n/app_localizations.dart';

/// The community rule behind an action, in plain words.
String policyLabel(AppLocalizations l10n, String policy) => switch (policy) {
  'FAKE_PROFILE' => l10n.policyFakeProfile,
  'HARASSMENT' => l10n.policyHarassment,
  'UNDERAGE' => l10n.policyUnderage,
  'EXPLICIT_PHOTO' => l10n.policyExplicitPhoto,
  'THREAT' => l10n.policyThreat,
  'SPAM' => l10n.policySpam,
  _ => l10n.policyOther,
};
