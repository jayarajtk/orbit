import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';

/// The signed-in member's profile; null until onboarding finishes.
final myProfileProvider = NotifierProvider<MyProfileController, MyProfile?>(
  MyProfileController.new,
);

/// Holds the member's own profile. In memory until the profile API exists.
class MyProfileController extends Notifier<MyProfile?> {
  @override
  MyProfile? build() => null;

  /// Saves [profile], trimming the display name.
  void save(MyProfile profile) =>
      state = profile.copyWith(displayName: profile.displayName.trim());
}
