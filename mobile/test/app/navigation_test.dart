import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/app.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: OrbitApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('onboarding', () {
    testWidgets('welcome screen leads with the privacy promise', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Meet people nearby.'), findsOneWidget);
      expect(
        find.text('Your exact location is never stored — only a rounded area.'),
        findsOneWidget,
      );
      expect(find.text('18+ only'), findsOneWidget);
    });

    testWidgets('get started opens sign in, and back returns to welcome', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to Orbit'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Meet people nearby.'), findsOneWidget);
    });
  });

  group('home tabs', () {
    Future<void> signIn(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();
    }

    testWidgets('signing in lands on the Nearby tab', (tester) async {
      await signIn(tester);

      expect(
        find.text('No one nearby yet — try widening your filters.'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('tabs switch between Nearby, Inbox and Me', (tester) async {
      await signIn(tester);

      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Say hi to someone nearby.'), findsOneWidget);

      await tester.tap(find.text('Me').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Me'), findsOneWidget);
    });
  });

  testWidgets('primary action meets the 48dp minimum touch target', (
    tester,
  ) async {
    await pumpApp(tester);

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Get started'),
    );

    expect(size.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
