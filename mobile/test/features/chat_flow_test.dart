import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Future<void> openChatWith(WidgetTester tester, String name) async {
  await pumpOrbit(tester);
  await onboard(tester);
  await tapText(tester, 'Inbox');
  await tapText(tester, name);
}

Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

void main() {
  testWidgets('opening a chat clears its unread count', (tester) async {
    await openChatWith(tester, 'Alex');
    expect(find.text("There's a new gym near the river"), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNothing);
  });

  testWidgets('a dummy member types, then replies, and reads yours', (
    tester,
  ) async {
    await openChatWith(tester, 'Alex');

    await sendMessage(tester, 'Want to climb on Saturday');
    expect(find.text('Want to climb on Saturday'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);

    await tester.pump(testReplyAfter);
    expect(find.text('Alex is typing…'), findsOneWidget);

    await tester.pump(testTypingFor);
    await tester.pumpAndSettle();
    expect(find.text('Hey! Nice to hear from you 🙂'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('turning off read receipts hides "Read"', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');
    await tapText(tester, 'Read receipts');
    await tapText(tester, 'Inbox');
    await tapText(tester, 'Alex');

    await sendMessage(tester, 'hello');
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsNothing);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('own messages can be unsent', (tester) async {
    await openChatWith(tester, 'Alex');
    await sendMessage(tester, 'oops wrong chat');

    await tester.longPress(find.text('oops wrong chat'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Unsend');

    expect(find.text('oops wrong chat'), findsNothing);
    expect(find.text('This message was unsent'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();
  });

  testWidgets('sharing an album posts a card in the chat', (tester) async {
    await openChatWith(tester, 'Alex');

    await tester.tap(find.byTooltip('Share an album'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Travel');
    await tapText(tester, 'Share album');

    expect(find.text('You shared “Travel”'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();
    expect(find.text('Thanks for sharing — great pics!'), findsOneWidget);
  });

  testWidgets('waving from a profile starts a conversation', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Omar 32');

    await tapText(tester, 'Wave');
    expect(find.text('You waved at Omar'), findsOneWidget);
    await tester.pump(testReplyAfter + testTypingFor);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Inbox');
    expect(find.text('Hey, thanks for the wave! 👋'), findsOneWidget);
  });
}
