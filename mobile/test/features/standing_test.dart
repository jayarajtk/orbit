import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/core/network/account_restriction.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/standing/data/standing_repository.dart';
import 'package:orbit/features/standing/domain/standing.dart';
import 'package:orbit/features/standing/presentation/restricted_screen.dart';
import 'package:orbit/features/standing/presentation/warning_notice.dart';
import 'package:orbit/l10n/app_localizations.dart';

import '../helpers/fake_api.dart';

/// Answers standing calls from memory and records what was sent.
class FakeStandingRepository implements StandingRepository {
  FakeStandingRepository(this.current);

  Standing current;
  final appeals = <String>[];
  final acknowledged = <String>[];

  @override
  Future<Standing> standing() async => current;

  @override
  Future<Appeal> appeal(String text) async {
    appeals.add(text);
    final appeal = Appeal(
      status: AppealStatus.open,
      createdAt: DateTime.utc(2026, 11, 18),
    );
    final restriction = current.restriction!;
    current = Standing(
      status: current.status,
      suspendedUntil: current.suspendedUntil,
      restriction: Restriction(
        actionId: restriction.actionId,
        policy: restriction.policy,
        message: restriction.message,
        canAppeal: false,
        appeal: appeal,
      ),
    );
    return appeal;
  }

  @override
  Future<void> acknowledge(String warningId) async =>
      acknowledged.add(warningId);
}

Standing _banned({Appeal? appeal}) => Standing(
  status: 'BANNED',
  restriction: Restriction(
    actionId: 'a1',
    policy: 'THREAT',
    message: "Threats aren't allowed.",
    canAppeal: appeal == null,
    appeal: appeal,
  ),
);

Future<void> _showRestricted(
  WidgetTester tester,
  StandingRepository repository,
) async {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const RestrictedScreen())],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [standingRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('standing from the API', () {
    test('reads a suspension with an appeal and warnings', () {
      final standing = Standing.fromJson({
        'status': 'SUSPENDED',
        'suspendedUntil': '2026-11-19T12:00:00Z',
        'restriction': {
          'actionId': 'a1',
          'kind': 'SUSPEND',
          'policy': 'SPAM',
          'message': 'Stop advertising.',
          'suspendedUntil': '2026-11-19T12:00:00Z',
          'createdAt': '2026-11-18T12:00:00Z',
          'appeal': {
            'id': 'p1',
            'status': 'UPHELD',
            'decisionMessage': 'It stays.',
            'createdAt': '2026-11-18T13:00:00Z',
            'decidedAt': '2026-11-18T14:00:00Z',
          },
          'canAppeal': false,
        },
        'warnings': [
          {
            'id': 'w1',
            'policy': 'HARASSMENT',
            'message': '',
            'createdAt': '2026-11-01T00:00:00Z',
          },
        ],
      });

      expect(standing.restricted, isTrue);
      expect(standing.banned, isFalse);
      expect(standing.suspendedUntil, DateTime.utc(2026, 11, 19, 12));
      expect(standing.restriction!.appeal!.status, AppealStatus.upheld);
      expect(standing.restriction!.appeal!.decisionMessage, 'It stays.');
      expect(standing.warnings.single.id, 'w1');
    });

    test('sends an appeal and acknowledges warnings', () async {
      final api = FakeAdapter({
        'POST /me/appeals': (
          201,
          {
            'id': 'p1',
            'status': 'OPEN',
            'decisionMessage': null,
            'createdAt': '2026-11-18T13:00:00Z',
            'decidedAt': null,
          },
        ),
        'POST /me/warnings/w1/ack': (204, null),
      });
      final repository = ApiStandingRepository(dioWith(api));

      final appeal = await repository.appeal('It was a joke.');
      await repository.acknowledge('w1');

      expect(appeal.status, AppealStatus.open);
      expect(api.requests.first.data, {'text': 'It was a joke.'});
      expect(api.requests.last.path, '/me/warnings/w1/ack');
    });
  });

  test('a suspended or banned account is its own onboarding stage', () async {
    final api = FakeAdapter({
      'GET /me': (200, {'id': 'me', 'status': 'BANNED'}),
    });

    final snapshot = await ApiAccountRepository(dioWith(api)).load();

    expect(snapshot.stage, AccountStage.restricted);
    expect(api.requests, hasLength(1), reason: 'no profile call');
  });

  test('any account-restricted answer raises the restriction flag', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = dioWith(
      FakeAdapter({
        'GET /me/profile': (403, problem('account-restricted', 403)),
        'GET /me/settings': (403, problem('account-required', 403)),
      }),
    );
    dio.interceptors.add(
      AccountRestrictionInterceptor(
        () => container.read(accountRestrictedProvider.notifier).flag(),
      ),
    );

    await expectLater(
      guardApi(() => dio.get<void>('/me/settings')),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(accountRestrictedProvider), isFalse);

    await expectLater(
      guardApi(() => dio.get<void>('/me/profile')),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(accountRestrictedProvider), isTrue);
  });

  group('restriction screen', () {
    testWidgets('explains a ban and takes one appeal', (tester) async {
      final repository = FakeStandingRepository(_banned());
      await _showRestricted(tester, repository);

      expect(find.text('Your account is banned'), findsOneWidget);
      expect(find.text('Reason: threats or violence.'), findsOneWidget);
      expect(find.text("Threats aren't allowed."), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Send appeal');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'It was a joke.');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(repository.appeals, ['It was a joke.']);
      expect(
        find.textContaining('Your appeal is with the safety team'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows the outcome of a reviewed appeal', (tester) async {
      await _showRestricted(
        tester,
        FakeStandingRepository(
          _banned(
            appeal: Appeal(
              status: AppealStatus.upheld,
              createdAt: DateTime.utc(2026, 11, 18),
              decisionMessage: 'The ban stays.',
            ),
          ),
        ),
      );

      expect(
        find.text('Your appeal was reviewed, and the decision stands.'),
        findsOneWidget,
      );
      expect(find.text('The ban stays.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('says when a suspension ends', (tester) async {
      await _showRestricted(
        tester,
        FakeStandingRepository(
          Standing(
            status: 'SUSPENDED',
            suspendedUntil: DateTime.utc(2026, 11, 19, 12),
          ),
        ),
      );

      expect(find.text('Your account is suspended'), findsOneWidget);
      expect(
        find.textContaining('You can use Orbit again after'),
        findsOneWidget,
      );
    });
  });

  testWidgets('warnings are shown once each and then marked seen', (
    tester,
  ) async {
    final repository = FakeStandingRepository(
      const Standing(
        status: 'ACTIVE',
        warnings: [
          Warning(id: 'w1', policy: 'HARASSMENT', message: 'Be kind.'),
          Warning(id: 'w2', policy: 'SPAM', message: ''),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [standingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showPendingWarnings(context, ref),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(find.text('Be kind.'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.textContaining('spam or scams'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.acknowledged, ['w1', 'w2']);
  });
}
