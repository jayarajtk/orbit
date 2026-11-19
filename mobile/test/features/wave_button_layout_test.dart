import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/discovery/data/dummy_profiles.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/discovery/presentation/profile_screen.dart';
import 'package:orbit/l10n/app_localizations.dart';

import '../helpers/fake_image_cache.dart';
import '../helpers/pump_app.dart';
import '../helpers/sdk_fonts.dart';

/// Demo chat where the user has already waved at Alex twice in the last hour.
class _WavedTwiceChat extends DemoChatController {
  @override
  Map<String, Conversation> build() {
    final alexId = dummyProfiles.first.id;
    return {
      ...super.build(),
      alexId: Conversation(
        profileId: alexId,
        messages: [
          for (final (i, minutes) in [40, 20].indexed)
            Message(
              id: 'w$i',
              fromMe: true,
              kind: MessageKind.wave,
              sentAt: testNow.subtract(Duration(minutes: minutes)),
            ),
        ],
      ),
    };
  }
}

void main() {
  // The test font is as wide as it is tall, which says nothing about line
  // breaks; real glyphs do.
  setUpAll(loadSdkFonts);

  testWidgets('the locked Wave label fits on one line at 375 pt', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(375 * 3, 812 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final base = buildOrbitTheme(Brightness.light);
    // The theme's button text has no font family, which the test engine
    // draws in the wide test font; name the SDK's Roboto for real widths.
    const label = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => testNow),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(latency: Duration.zero),
          ),
          chatProvider.overrideWith(_WavedTwiceChat.new),
          orbitImageCacheProvider.overrideWithValue(FakeImageCache()),
        ],
        child: MaterialApp(
          theme: base.copyWith(
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: base.outlinedButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(label),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: base.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(label),
              ),
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(profileId: dummyProfiles.first.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wave = find.descendant(
      of: find.byType(OutlinedButton),
      matching: find.textContaining('24h'),
    );
    expect(wave, findsOneWidget);
    await tester.ensureVisible(wave);
    await tester.pumpAndSettle();

    // "Message" is one line in the same button style, so equal heights mean
    // the label did not wrap.
    final oneLine = tester.getSize(find.text('Message')).height;
    expect(oneLine, lessThan(25), reason: 'Message itself must not wrap');
    expect(tester.getSize(wave).height, oneLine);
    // The shorter label is spoken in full.
    expect(find.bySemanticsLabel('Wave again in 24h'), findsOneWidget);
    semantics.dispose();
  });
}
