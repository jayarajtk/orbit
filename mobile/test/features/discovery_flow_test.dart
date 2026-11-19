import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('the Online chip hides offline members', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    expect(find.text('Sam 31'), findsOneWidget);

    await tapText(tester, 'Online');

    expect(find.text('Sam 31'), findsNothing);
    expect(find.text('Alex 27'), findsOneWidget);
  });

  testWidgets('opens a profile with bio, details and tags', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);

    await tapText(tester, 'Alex 27');

    expect(find.text('Alex, 27'), findsOneWidget);
    expect(find.text('he/him · 180 cm · Single'), findsOneWidget);
    expect(find.text('#climbing'), findsOneWidget);
  });

  testWidgets('favoriting a profile lists it under Favorites', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Me');
    await tapText(tester, 'Favorites');
    expect(find.text('Alex, 27'), findsOneWidget);
  });

  testWidgets('blocking removes the member from the grid and inbox', (
    tester,
  ) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Block Alex');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    expect(find.text('Alex 27'), findsNothing);
    expect(find.text('Alex is blocked'), findsOneWidget);
    await tapText(tester, 'Inbox');
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('reporting needs a reason and can also block', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Sam 31');
    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Submit report');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapText(tester, 'Harassment');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Thanks. A moderator will review your report.'),
      findsOneWidget,
    );
    expect(find.text('Sam 31'), findsNothing);
  });

  testWidgets('the distance filter is an Orbit+ feature', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum distance'), findsNothing);

    await tapText(tester, 'Distance and more filters');
    await tapText(tester, 'Subscribe');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Maximum distance'), findsOneWidget);
  });
}
