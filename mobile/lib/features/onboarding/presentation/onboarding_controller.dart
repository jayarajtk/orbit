import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/data/location_repository.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/onboarding/domain/age_policy.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';

/// Answers collected during onboarding (W3–W5).
class OnboardingDraft {
  /// Creates a draft.
  const OnboardingDraft({
    this.birthDate,
    this.displayName = '',
    this.lookingFor = const {LookingFor.chat},
  });

  /// Chosen birthday, if any.
  final DateTime? birthDate;

  /// Chosen display name.
  final String displayName;

  /// Chosen goals.
  final Set<LookingFor> lookingFor;

  /// Returns a copy with the given fields replaced.
  OnboardingDraft copyWith({
    DateTime? birthDate,
    String? displayName,
    Set<LookingFor>? lookingFor,
  }) {
    return OnboardingDraft(
      birthDate: birthDate ?? this.birthDate,
      displayName: displayName ?? this.displayName,
      lookingFor: lookingFor ?? this.lookingFor,
    );
  }
}

/// The onboarding draft.
final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );

/// Collects onboarding answers and creates the profile at the end.
class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Sets the birthday.
  void setBirthDate(DateTime date) => state = state.copyWith(birthDate: date);

  /// Whether the chosen birthday meets the age requirement today.
  bool get isAdult {
    final birthDate = state.birthDate;
    return birthDate != null &&
        AgePolicy.isAdult(birthDate, ref.read(clockProvider)());
  }

  /// Sets the display name.
  void setDisplayName(String name) => state = state.copyWith(displayName: name);

  /// Adds or removes [goal].
  void toggleLookingFor(LookingFor goal) {
    final goals = {...state.lookingFor};
    if (!goals.remove(goal)) goals.add(goal);
    state = state.copyWith(lookingFor: goals);
  }

  /// The account already exists (signed in mid-onboarding), so the birthday
  /// step is skipped and the server knows the age.
  void markAccountCreated() => _accountCreated = true;

  bool _accountCreated = false;

  /// Creates the account for the chosen birthday. The server re-checks the
  /// age and throws [UnderageException] for under-18s.
  Future<void> confirmBirthDate() async {
    final birthDate = state.birthDate;
    if (birthDate == null || !isAdult) {
      throw StateError('Birthday step is incomplete');
    }
    await ref.read(accountRepositoryProvider).createAccount(birthDate);
    _accountCreated = true;
  }

  /// Saves the member's profile from the draft and, if [shareLocation],
  /// uploads their location.
  ///
  /// Throws a [StateError] if the account or name step was skipped.
  Future<void> finish({required bool shareLocation}) async {
    final birthDate = state.birthDate;
    final name = state.displayName.trim();
    if (!_accountCreated || name.isEmpty) {
      throw StateError('Onboarding is incomplete');
    }
    final today = ref.read(clockProvider)();
    final saved = await ref
        .read(accountRepositoryProvider)
        .saveProfile(
          MyProfile(
            displayName: name,
            // The server returns the real age; this only matters in demo mode.
            age: birthDate == null ? 0 : AgePolicy.ageOn(birthDate, today),
            lookingFor: state.lookingFor,
          ),
        );
    ref.read(myProfileProvider.notifier).save(saved);
    if (shareLocation) {
      try {
        await ref.read(locationRepositoryProvider).shareCurrentLocation();
      } on ApiException {
        // The grid explains how to share location if this didn't work.
      }
    }
  }
}
