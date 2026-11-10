import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/app.dart';

/// Regression: the onboarding screens overflowed ("BOTTOM OVERFLOWED") on
/// short viewports and at large text sizes because they could not scroll.
void main() {
  Future<void> pumpSmallLargeText(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: OrbitApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('welcome fits a small screen at 200% text', (tester) async {
    await pumpSmallLargeText(tester);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Get started'), 100);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('sign in fits a small screen at 200% text', (tester) async {
    await pumpSmallLargeText(tester);
    await tester.scrollUntilVisible(find.text('Get started'), 100);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Continue with phone number'),
      100,
    );
    expect(find.text('Continue with phone number'), findsOneWidget);
  });
}
