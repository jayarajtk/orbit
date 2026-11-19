import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('onboarding', () {
    testWidgets('welcome screen leads with the privacy promise', (
      tester,
    ) async {
      await pumpOrbit(tester);

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
      await pumpOrbit(tester);

      await tapText(tester, 'Get started');
      expect(find.text('Sign in to Orbit'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Meet people nearby.'), findsOneWidget);
    });

    testWidgets('blocks under-18s at the age gate', (tester) async {
      await pumpOrbit(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Continue with Apple');

      await enterBirthday(tester, '01/01/2012');

      expect(
        find.text('Sorry — Orbit is only for people 18 and over.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('adults finish onboarding and land on a grid of profiles', (
      tester,
    ) async {
      await pumpOrbit(tester);

      await onboard(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Alex 27'), findsOneWidget);
      expect(find.text('Fresh faces'), findsOneWidget);
    });
  });

  group('home tabs', () {
    testWidgets('tabs switch between Nearby, Inbox and Me', (tester) async {
      await pumpOrbit(tester);
      await onboard(tester);

      await tapText(tester, 'Inbox');
      expect(find.text('Alex'), findsOneWidget);

      await tapText(tester, 'Me');
      expect(find.text('Robin, 36'), findsOneWidget);
    });

    testWidgets('the inbox tab shows the unread count', (tester) async {
      await pumpOrbit(tester);
      await onboard(tester);

      final badge = tester.widget<Badge>(
        find.ancestor(
          of: find.byIcon(Icons.chat_bubble_outline),
          matching: find.byType(Badge),
        ),
      );
      expect((badge.label! as Text).data, '3');
    });
  });

  group('frosted bars and large titles', () {
    testWidgets('bottom bar is frosted and has no pill indicator', (
      tester,
    ) async {
      await pumpOrbit(tester);
      await onboard(tester);

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
        reason: 'the blur sits around the bar, not inside it',
      );
      expect(
        find.ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.indicatorColor, Colors.transparent);
    });

    testWidgets('inbox title collapses when scrolled', (tester) async {
      await pumpOrbit(tester);
      await onboard(tester);
      await tapText(tester, 'Inbox');
      // A short screen, so the three conversations overflow and scroll.
      tester.view.physicalSize = const Size(1170, 900);
      await tester.pumpAndSettle();

      double sizeOf(Finder f) =>
          (tester.renderObject(f) as RenderParagraph).text.style!.fontSize!;
      final titles = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.text('Inbox'),
      );
      final large = titles.first;
      final compact = titles.last;
      double compactOpacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: compact,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      expect(sizeOf(large), 34);
      expect(sizeOf(compact), 17);
      expect(compactOpacity(), 0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(compactOpacity(), 1);
    });
  });

  testWidgets('primary action meets the 48dp minimum touch target', (
    tester,
  ) async {
    await pumpOrbit(tester);

    final size = tester.getSize(
      find.widgetWithText(FilledButton, 'Get started'),
    );

    expect(size.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
