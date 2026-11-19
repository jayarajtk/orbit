import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';

/// How far the signed-in member has got.
enum AccountStage {
  /// Signed in but no Orbit account yet: start at the birthday step.
  noAccount,

  /// Account exists (age checked) but no profile yet.
  needsProfile,

  /// Fully onboarded.
  ready,

  /// Suspended or banned (ADR-0007): only the restriction screen is open.
  restricted,
}

/// The member's account state and, when [AccountStage.ready], their profile.
class AccountSnapshot {
  /// Creates a snapshot.
  const AccountSnapshot(this.stage, [this.profile]);

  /// Onboarding stage.
  final AccountStage stage;

  /// The profile, when ready.
  final MyProfile? profile;
}

/// The server refused the birthday: under 18.
class UnderageException implements Exception {
  /// Creates the exception.
  const UnderageException();
}

/// The member's own account and profile.
abstract interface class AccountRepository {
  /// Where the member is in onboarding.
  Future<AccountSnapshot> load();

  /// Creates the account. Throws [UnderageException] if under 18.
  Future<void> createAccount(DateTime birthDate);

  /// Saves the profile and returns it as the server stored it.
  Future<MyProfile> saveProfile(MyProfile profile);

  /// Replaces the public photos with [mediaIds], in order, and returns the
  /// profile as stored.
  Future<MyProfile> setPhotos(List<String> mediaIds);
}

/// The configured [AccountRepository].
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AppEnv.usesApi
      ? ApiAccountRepository(ref.watch(dioProvider))
      : const DemoAccountRepository(),
);

/// Demo mode: every sign-in starts onboarding; nothing is stored remotely.
class DemoAccountRepository implements AccountRepository {
  /// Creates the demo repository.
  const DemoAccountRepository();

  @override
  Future<AccountSnapshot> load() async =>
      const AccountSnapshot(AccountStage.noAccount);

  @override
  Future<void> createAccount(DateTime birthDate) async {}

  @override
  Future<MyProfile> saveProfile(MyProfile profile) async => profile;

  @override
  Future<MyProfile> setPhotos(List<String> mediaIds) =>
      throw UnsupportedError('Photos need the media service (API mode).');
}

/// Account and profile through the Orbit API.
class ApiAccountRepository implements AccountRepository {
  /// Creates the repository on [_dio].
  ApiAccountRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountSnapshot> load() async {
    final Map<String, dynamic> account;
    try {
      account = (await guardApi(
        () => _dio.get<Map<String, dynamic>>('/me'),
      )).data!;
    } on ApiException catch (e) {
      if (e.isProblem('account-not-found')) {
        return const AccountSnapshot(AccountStage.noAccount);
      }
      rethrow;
    }
    if (const {'SUSPENDED', 'BANNED'}.contains(account['status'])) {
      return const AccountSnapshot(AccountStage.restricted);
    }
    try {
      final response = await guardApi(
        () => _dio.get<Map<String, dynamic>>('/me/profile'),
      );
      return AccountSnapshot(
        AccountStage.ready,
        MyProfile.fromJson(response.data!),
      );
    } on ApiException catch (e) {
      if (e.isProblem('profile-not-found')) {
        return const AccountSnapshot(AccountStage.needsProfile);
      }
      rethrow;
    }
  }

  @override
  Future<void> createAccount(DateTime birthDate) async {
    final date =
        '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}';
    try {
      await guardApi(
        () => _dio.post<void>('/accounts', data: {'birthDate': date}),
      );
    } on ApiException catch (e) {
      if (e.isProblem('age-requirement')) throw const UnderageException();
      // A retry after a lost response: the account already exists.
      if (e.isProblem('account-exists')) return;
      rethrow;
    }
  }

  @override
  Future<MyProfile> saveProfile(MyProfile profile) {
    return guardApi(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/me/profile',
        data: profile.toJson(),
      );
      return MyProfile.fromJson(response.data!);
    });
  }

  @override
  Future<MyProfile> setPhotos(List<String> mediaIds) {
    return guardApi(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/me/photos',
        data: {'mediaIds': mediaIds},
      );
      return MyProfile.fromJson(response.data!);
    });
  }
}
