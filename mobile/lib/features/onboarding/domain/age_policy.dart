/// Orbit is 18+ only. Mirrors the server's `AgePolicy`; the server is the
/// authority and rejects under-18 sign-ups even if this check is bypassed.
abstract final class AgePolicy {
  /// Minimum age to hold an account.
  static const minimumAge = 18;

  /// Age in whole years on [today]; changes on the birthday itself.
  static int ageOn(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// Whether someone born on [birthDate] is at least [minimumAge] on
  /// [today].
  static bool isAdult(DateTime birthDate, DateTime today) =>
      ageOn(birthDate, today) >= minimumAge;
}
