import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/data/api_profile_repository.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/domain/profile_repository.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/safety/data/safety_repository.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations_en.dart';

import '../helpers/fake_api.dart';

const Map<String, Object?> alexJson = {
  'id': 'a1',
  'displayName': 'Alex',
  'age': 27,
  'distanceKm': 0,
  'online': true,
  'isNew': true,
  'favorite': false,
  'photoCount': 0,
  'bio': 'Climbing',
  'pronouns': '',
  'heightCm': 180,
  'relationship': 'SINGLE',
  'lookingFor': ['CHAT', 'RIGHT_NOW', 'SOMETHING_NEW'],
  'tags': ['climbing'],
};

void main() {
  final l10n = AppLocalizationsEn();

  group('Profile.fromJson', () {
    test('maps API values and ignores unknown enum values', () {
      final p = Profile.fromJson(alexJson);
      expect(p.name, 'Alex');
      expect(p.lookingFor, {LookingFor.chat, LookingFor.rightNow});
      expect(p.relationship, RelationshipStatus.single);
      expect(p.pronouns, isNull, reason: 'empty pronouns are not shown');
      expect(p.isNew, isTrue);
    });

    test('hidden age and distance stay hidden', () {
      final p = Profile.fromJson({
        ...alexJson,
        'age': null,
        'distanceKm': null,
      });
      expect(l10n.nameWithAge(p.name, p.age), 'Alex');
      expect(l10n.distance(p.distanceKm), 'Distance hidden');
    });

    test('distance buckets read as the server sends them', () {
      expect(l10n.distance(0), '<1 km');
      expect(l10n.distance(4), '4 km');
      expect(l10n.distance(Profile.tenPlusKm), '10+ km');
    });
  });

  group('Profile status ring', () {
    test('UNSEEN, SEEN and NONE parse to the ring', () {
      expect(
        Profile.fromJson({...alexJson, 'status': 'UNSEEN'}).status,
        StatusRing.unseen,
      );
      expect(
        Profile.fromJson({...alexJson, 'status': 'SEEN'}).status,
        StatusRing.seen,
      );
      expect(
        Profile.fromJson({...alexJson, 'status': 'NONE'}).status,
        StatusRing.none,
      );
    });

    test('a missing or unknown status is none', () {
      expect(Profile.fromJson(alexJson).status, StatusRing.none);
      expect(
        Profile.fromJson({...alexJson, 'status': 'NEW'}).status,
        StatusRing.none,
      );
    });

    test('ringFor greys an unseen ring once the owner was viewed', () {
      final unseen = Profile.fromJson({...alexJson, 'status': 'UNSEEN'});
      final none = Profile.fromJson(alexJson);
      expect(ringFor(unseen, const {}), StatusRing.unseen);
      expect(ringFor(unseen, {'a1'}), StatusRing.seen);
      expect(ringFor(none, {'a1'}), StatusRing.none);
    });
  });

  group('toApiException', () {
    test('strips the problem URN prefix', () {
      final e = toApiException(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 409,
            data: problem('location-required', 409),
          ),
        ),
      );
      expect(e.status, 409);
      expect(e.isProblem('location-required'), isTrue);
    });

    test('no response means the network is unreachable', () {
      final e = toApiException(
        DioException(requestOptions: RequestOptions()),
      );
      expect(e.type, 'network');
      expect(e.status, 0);
    });
  });

  group('ApiProfileRepository', () {
    test('sends only non-default filters', () {
      expect(ApiProfileRepository.gridQuery(const DiscoveryFilters()), {
        'limit': 60,
      });
      expect(
        ApiProfileRepository.gridQuery(
          const DiscoveryFilters(
            minAge: 25,
            onlineOnly: true,
            lookingFor: {LookingFor.rightNow},
            maxDistanceKm: 5,
          ),
        ),
        {
          'limit': 60,
          'minAge': 25,
          'onlineOnly': true,
          'lookingFor': ['RIGHT_NOW'],
          'maxDistanceKm': 5,
        },
      );
    });

    test('parses the grid page', () async {
      final adapter = FakeAdapter({
        'GET /discovery/grid': (
          200,
          {
            'items': [alexJson],
            'nextCursor': null,
          },
        ),
      });
      final profiles = await ApiProfileRepository(
        dioWith(adapter),
      ).nearby(const DiscoveryFilters());
      expect(profiles.single.name, 'Alex');
    });

    test('a profile that is gone or blocked is null, not an error', () async {
      final adapter = FakeAdapter({
        'GET /profiles/x': (404, problem('profile-unavailable', 404)),
      });
      expect(await ApiProfileRepository(dioWith(adapter)).byId('x'), isNull);
    });
  });

  group('ApiAccountRepository', () {
    test('no account means onboarding starts at the birthday', () async {
      final adapter = FakeAdapter({
        'GET /me': (404, problem('account-not-found', 404)),
      });
      final snapshot = await ApiAccountRepository(dioWith(adapter)).load();
      expect(snapshot.stage, AccountStage.noAccount);
    });

    test('an account without a profile resumes at the profile step', () async {
      final adapter = FakeAdapter({
        'GET /me': (200, {'id': 'me', 'status': 'ONBOARDING'}),
        'GET /me/profile': (404, problem('profile-not-found', 404)),
      });
      final snapshot = await ApiAccountRepository(dioWith(adapter)).load();
      expect(snapshot.stage, AccountStage.needsProfile);
    });

    test('a full account loads the profile', () async {
      final adapter = FakeAdapter({
        'GET /me': (200, {'id': 'me', 'status': 'ACTIVE'}),
        'GET /me/profile': (
          200,
          {
            'displayName': 'Robin',
            'age': 36,
            'lookingFor': ['DATES'],
            'tags': <String>[],
            'showAge': true,
            'showDistance': false,
          },
        ),
      });
      final snapshot = await ApiAccountRepository(dioWith(adapter)).load();
      expect(snapshot.stage, AccountStage.ready);
      expect(snapshot.profile!.age, 36);
      expect(snapshot.profile!.showDistance, isFalse);
    });

    test('the server age check becomes UnderageException', () async {
      final adapter = FakeAdapter({
        'POST /accounts': (422, problem('age-requirement', 422)),
      });
      expect(
        ApiAccountRepository(dioWith(adapter)).createAccount(DateTime(2012)),
        throwsA(isA<UnderageException>()),
      );
    });

    test('a retried sign-up that already succeeded is fine', () async {
      final adapter = FakeAdapter({
        'POST /accounts': (409, problem('account-exists', 409)),
      });
      await ApiAccountRepository(
        dioWith(adapter),
      ).createAccount(DateTime(1990));
      expect(adapter.requests.single.data, {'birthDate': '1990-01-01'});
    });

    test('profile save sends API enum values', () async {
      final adapter = FakeAdapter({
        'PUT /me/profile': (
          200,
          {
            'displayName': 'Robin',
            'age': 36,
            'lookingFor': ['RIGHT_NOW'],
          },
        ),
      });
      await ApiAccountRepository(dioWith(adapter)).saveProfile(
        const MyProfile(
          displayName: 'Robin',
          age: 0,
          lookingFor: {LookingFor.rightNow},
        ),
      );
      final body = adapter.requests.single.data as Map<String, Object?>;
      expect(body['lookingFor'], ['RIGHT_NOW']);
    });
  });

  group('ApiSafetyRepository', () {
    test('reports send the reason and the block choice', () async {
      final adapter = FakeAdapter({
        'POST /reports': (202, {'id': 'r1'}),
      });
      await ApiSafetyRepository(
        dioWith(adapter),
      ).report('a1', ReportReason.threat, alsoBlock: true);
      expect(adapter.requests.single.data, {
        'accountId': 'a1',
        'reason': 'THREAT',
        'alsoBlock': true,
      });
    });

    test('reports name the status only when one is given', () async {
      final adapter = FakeAdapter({
        'POST /reports': (202, {'id': 'r1'}),
      });
      await ApiSafetyRepository(dioWith(adapter)).report(
        'a1',
        ReportReason.photos,
        alsoBlock: false,
        statusId: 's1',
      );
      expect(adapter.requests.single.data, {
        'accountId': 'a1',
        'reason': 'PHOTOS',
        'alsoBlock': false,
        'statusId': 's1',
      });
    });
  });

  group('ApiStatusRepository', () {
    const myJson = <String, Object?>{
      'id': 's1',
      'url': 'https://x/full',
      'thumbUrl': 'https://x/thumb',
      'caption': 'Hi',
      'createdAt': '2026-11-18T10:00:00Z',
      'expiresAt': '2026-11-19T10:00:00Z',
      'viewCount': 1,
      'viewers': [
        {
          'id': 'v1',
          'name': 'Sam',
          'thumbUrl': null,
          'viewedAt': '2026-11-18T11:30:00Z',
        },
      ],
    };

    test('post sends the media id and caption and parses the status', () async {
      final adapter = FakeAdapter({'POST /me/statuses': (201, myJson)});
      final status = await ApiStatusRepository(
        dioWith(adapter),
      ).post('m1', caption: 'Hi');
      expect(adapter.requests.single.data, {'mediaId': 'm1', 'caption': 'Hi'});
      expect(status.id, 's1');
      expect(status.caption, 'Hi');
      expect(status.viewCount, 1);
      expect(status.createdAt, DateTime.utc(2026, 11, 18, 10));
      expect(status.createdAt.isUtc, isTrue);
      expect(status.expiresAt, DateTime.utc(2026, 11, 19, 10));
      expect(status.viewers.single.name, 'Sam');
      expect(status.viewers.single.thumbUrl, isNull);
      expect(status.viewers.single.viewedAt.isUtc, isTrue);
    });

    test('post leaves the caption out when there is none', () async {
      final adapter = FakeAdapter({'POST /me/statuses': (201, myJson)});
      await ApiStatusRepository(dioWith(adapter)).post('m1');
      expect(adapter.requests.single.data, {'mediaId': 'm1'});
    });

    test('a 409 status-limit surfaces as an ApiException', () async {
      final adapter = FakeAdapter({
        'POST /me/statuses': (409, problem('status-limit', 409)),
      });
      await expectLater(
        ApiStatusRepository(dioWith(adapter)).post('m1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', 'status-limit')
              .having((e) => e.status, 'status', 409),
        ),
      );
    });

    test('mine parses the list', () async {
      final adapter = FakeAdapter({
        'GET /me/statuses': (200, [myJson]),
      });
      final list = await ApiStatusRepository(dioWith(adapter)).mine();
      expect(list.single.id, 's1');
      expect(list.single.viewers, hasLength(1));
    });

    test('delete sends DELETE for the id', () async {
      final adapter = FakeAdapter({'DELETE /me/statuses/s1': (204, null)});
      await ApiStatusRepository(dioWith(adapter)).delete('s1');
      expect(adapter.requests.single.method, 'DELETE');
    });

    test("of parses another member's statuses", () async {
      final adapter = FakeAdapter({
        'GET /profiles/p1/statuses': (
          200,
          [
            {
              'id': 's2',
              'url': 'https://x/full',
              'thumbUrl': null,
              'caption': null,
              'createdAt': '2026-11-18T09:00:00Z',
              'seen': true,
            },
          ],
        ),
      });
      final items = await ApiStatusRepository(dioWith(adapter)).of('p1');
      expect(items.single.id, 's2');
      expect(items.single.seen, isTrue);
      expect(items.single.caption, isNull);
      expect(items.single.createdAt, DateTime.utc(2026, 11, 18, 9));
    });

    test('markViewed sends PUT to the view endpoint', () async {
      final adapter = FakeAdapter({'PUT /statuses/s2/view': (204, null)});
      await ApiStatusRepository(dioWith(adapter)).markViewed('s2');
      expect(adapter.requests.single.method, 'PUT');
    });

    test('a missing status is an ApiException', () async {
      final adapter = FakeAdapter({
        'PUT /statuses/s2/view': (404, problem('status-not-found', 404)),
      });
      await expectLater(
        ApiStatusRepository(dioWith(adapter)).markViewed('s2'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', 'status-not-found'),
        ),
      );
    });
  });

  group('status providers', () {
    test('post and delete update the list from the repository', () async {
      final repository = FakeStatusRepository();
      final container = ProviderContainer(
        overrides: [statusRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(await container.read(myStatusesProvider.future), isEmpty);
      await container
          .read(myStatusesProvider.notifier)
          .post('m1', caption: 'A');
      final posted = container.read(myStatusesProvider).requireValue;
      expect(posted.single.caption, 'A');

      await container
          .read(myStatusesProvider.notifier)
          .delete(posted.single.id);
      expect(container.read(myStatusesProvider).requireValue, isEmpty);
    });

    test('seen owners accumulate', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(seenStatusOwnersProvider.notifier).markSeen('a1');
      expect(container.read(seenStatusOwnersProvider), {'a1'});
    });
  });

  group('FavoritesNotifier', () {
    test('reverts the star when the server refuses', () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_RefusingRepository()),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(favoritesProvider.notifier).toggle('a1'),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(favoritesProvider), isEmpty);
    });
  });
}

class _RefusingRepository implements ProfileRepository {
  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) async => const [];

  @override
  Future<Profile?> byId(String id) async => null;

  @override
  Future<Set<String>> favoriteIds() async => const {};

  @override
  Future<void> setFavorite(String id, {required bool favorite}) =>
      Future.error(const ApiException(status: 0, type: 'network'));
}
