import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('editing the profile updates the Me tab', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    expect(find.text('Profile 33% complete'), findsOneWidget);

    await tapText(tester, 'Edit profile');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Robin K',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About me'),
      'Hello there',
    );
    await tapText(tester, 'Save');

    expect(find.text('Robin K, 36'), findsOneWidget);
    expect(find.text('Profile 50% complete'), findsOneWidget);
  });

  testWidgets('rejects an implausible height', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Edit profile');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height (cm)'),
      '999',
    );
    await tapText(tester, 'Save');

    expect(find.text('Enter a height between 120 and 230 cm'), findsOneWidget);
  });

  testWidgets('blocked users can be unblocked from settings', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Sam 31');
    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Block Sam');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');
    await tester.scrollUntilVisible(find.text('Blocked users'), 200);
    await tapText(tester, 'Blocked users');
    await tapText(tester, 'Unblock');

    expect(find.text("You haven't blocked anyone."), findsOneWidget);
  });

  testWidgets('safety centre topics open', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Safety centre');

    await tapText(tester, 'Meeting someone new');

    expect(
      find.textContaining('Meet somewhere public the first time'),
      findsOneWidget,
    );
  });

  testWidgets('signing out returns to Welcome and clears state', (
    tester,
  ) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapText(tester, 'Sign out');

    expect(find.text('Meet people nearby.'), findsOneWidget);
  });
}
