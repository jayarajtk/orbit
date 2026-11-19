/// A member's standing with moderation, as the app shows it (ADR-0007).
/// Members never see internal notes or who moderated them.
class Standing {
  /// Creates a standing.
  const Standing({
    required this.status,
    this.suspendedUntil,
    this.restriction,
    this.warnings = const [],
  });

  /// Parses `GET /me/standing`.
  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
    status: json['status'] as String,
    suspendedUntil: _date(json['suspendedUntil']),
    restriction: json['restriction'] == null
        ? null
        : Restriction.fromJson(json['restriction'] as Map<String, dynamic>),
    warnings: [
      for (final w in json['warnings'] as List<dynamic>? ?? const [])
        Warning.fromJson(w as Map<String, dynamic>),
    ],
  );

  /// `ACTIVE`, `SUSPENDED`, `BANNED`, `ONBOARDING` or `DELETING`, as of now.
  final String status;

  /// When a suspension ends.
  final DateTime? suspendedUntil;

  /// The suspension or ban in force, if the server knows why.
  final Restriction? restriction;

  /// Warnings the member hasn't seen yet, oldest first.
  final List<Warning> warnings;

  /// Whether the member is suspended or banned.
  bool get restricted => status == 'SUSPENDED' || status == 'BANNED';

  /// Whether it's a ban rather than a suspension.
  bool get banned => status == 'BANNED';
}

/// Why the member is suspended or banned.
class Restriction {
  /// Creates a restriction.
  const Restriction({
    required this.actionId,
    required this.policy,
    required this.message,
    required this.canAppeal,
    this.appeal,
  });

  /// Parses the `restriction` object.
  factory Restriction.fromJson(Map<String, dynamic> json) => Restriction(
    actionId: json['actionId'] as String,
    policy: json['policy'] as String,
    message: json['message'] as String? ?? '',
    canAppeal: json['canAppeal'] as bool? ?? false,
    appeal: json['appeal'] == null
        ? null
        : Appeal.fromJson(json['appeal'] as Map<String, dynamic>),
  );

  /// The moderation action.
  final String actionId;

  /// The community rule, e.g. `HARASSMENT`.
  final String policy;

  /// What the safety team wrote to the member; may be empty.
  final String message;

  /// Whether the member may appeal now.
  final bool canAppeal;

  /// Their appeal, if they made one.
  final Appeal? appeal;
}

/// Where an appeal stands.
enum AppealStatus {
  /// Waiting for a moderator.
  open,

  /// Reviewed: the action stays.
  upheld,

  /// Reviewed: the action was undone.
  reversed,
}

/// The member's appeal against a suspension or ban.
class Appeal {
  /// Creates an appeal.
  const Appeal({
    required this.status,
    required this.createdAt,
    this.decisionMessage,
  });

  /// Parses an appeal object.
  factory Appeal.fromJson(Map<String, dynamic> json) => Appeal(
    status: AppealStatus.values.byName(
      (json['status'] as String).toLowerCase(),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    decisionMessage: json['decisionMessage'] as String?,
  );

  /// Open, upheld or reversed.
  final AppealStatus status;

  /// When it was sent.
  final DateTime createdAt;

  /// What the reviewer wrote, once decided.
  final String? decisionMessage;
}

/// A warning from the safety team.
class Warning {
  /// Creates a warning.
  const Warning({
    required this.id,
    required this.policy,
    required this.message,
  });

  /// Parses a warning object.
  factory Warning.fromJson(Map<String, dynamic> json) => Warning(
    id: json['id'] as String,
    policy: json['policy'] as String,
    message: json['message'] as String? ?? '',
  );

  /// The warning's id, for acknowledging it.
  final String id;

  /// The community rule, e.g. `HARASSMENT`.
  final String policy;

  /// What the safety team wrote; may be empty.
  final String message;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;
