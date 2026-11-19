import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/message_bubble.dart';
import 'package:orbit/l10n/app_localizations.dart';

Message _photo({
  required bool fromMe,
  String? mediaId = 'm1',
  bool viewOnce = false,
  bool viewed = false,
  MessageKind kind = MessageKind.photo,
}) => Message(
  id: 'x',
  seq: 1,
  fromMe: fromMe,
  kind: kind,
  sentAt: DateTime.utc(2026, 11, 18),
  mediaId: mediaId,
  viewOnce: viewOnce,
  viewed: viewed,
);

Future<void> _show(WidgetTester tester, Message message) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            profileId: 'bob',
            message: message,
            otherName: 'Bob',
            showStatus: false,
            showReadReceipt: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('media still uploading says so', (tester) async {
    await _show(tester, _photo(fromMe: true, mediaId: null));

    expect(find.text('Uploading…'), findsOneWidget);
  });

  testWidgets('a closed view-once photo waits for a tap', (tester) async {
    await _show(tester, _photo(fromMe: false, viewOnce: true));

    expect(find.text('View-once photo · Tap to open'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an opened view-once photo stays closed', (tester) async {
    await _show(tester, _photo(fromMe: false, viewOnce: true, viewed: true));

    expect(find.text('Opened'), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget); // the bubble's own
  });

  testWidgets('the sender sees when a view-once photo was opened', (
    tester,
  ) async {
    await _show(tester, _photo(fromMe: true, viewOnce: true, viewed: true));

    expect(find.text('View-once photo · Opened'), findsOneWidget);
  });

  testWidgets('voice notes show a play button', (tester) async {
    await _show(tester, _photo(fromMe: false, kind: MessageKind.voice));

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.text('Voice note'), findsOneWidget);
  });
}
