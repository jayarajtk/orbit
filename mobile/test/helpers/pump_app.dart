import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/app.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/profile_repository.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';

/// Fixed "now" for every widget test.
final testNow = DateTime(2026, 11, 9, 12);

/// How long dummy members take to reply in tests.
const testReplyAfter = Duration(milliseconds: 100);

/// How long dummy members "type" in tests.
const testTypingFor = Duration(milliseconds: 100);

/// Pumps the app on a phone-sized screen with a fixed clock, no profile
/// latency and fast dummy replies. [profiles] replaces the dummy repository.
Future<void> pumpOrbit(
  WidgetTester tester, {
  ProfileRepository? profiles,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => testNow),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(latency: Duration.zero),
        ),
        chatTimingProvider.overrideWithValue(
          const ChatTiming(
            replyAfter: testReplyAfter,
            typingFor: testTypingFor,
          ),
        ),
      ],
      child: const OrbitApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the widget showing [text] into view, taps it and settles.
Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Enters [date] (MM/DD/YYYY) in the birthday picker on the age gate.
Future<void> enterBirthday(WidgetTester tester, String date) async {
  await tapText(tester, 'Choose your birthday');
  await tester.enterText(
    find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    ),
    date,
  );
  await tapText(tester, 'OK');
}

/// Goes from Welcome through onboarding to the Nearby grid as an adult.
Future<void> onboard(WidgetTester tester, {String name = 'Robin'}) async {
  await tapText(tester, 'Get started');
  await tapText(tester, 'Continue with Apple');
  await enterBirthday(tester, '05/01/1990');
  await tapText(tester, 'Continue');
  await tester.enterText(find.byType(TextField), name);
  await tester.pumpAndSettle();
  await tapText(tester, 'Continue');
  await tapText(tester, 'Allow while using');
}
