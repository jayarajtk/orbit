import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/status_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    final icons = dark ? 'light' : 'dark';

    group('in ${brightness.name} mode', () {
      Future<void> start(WidgetTester tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await pumpOrbit(tester);
        await onboard(tester);
      }

      void expectIcons(WidgetTester tester, {required bool light}) {
        final style = effectiveStatusBarStyle(tester);
        expect(
          light ? hasLightIcons(style) : hasDarkIcons(style),
          isTrue,
          reason: 'expected ${light ? 'light' : 'dark'} icons, got $style',
        );
      }

      testWidgets('Nearby has $icons status bar icons', (tester) async {
        await start(tester);
        expectIcons(tester, light: dark);
      });

      testWidgets('Inbox has $icons status bar icons', (tester) async {
        await start(tester);
        await tapText(tester, 'Inbox');
        expectIcons(tester, light: dark);
      });

      testWidgets('Me has $icons status bar icons', (tester) async {
        await start(tester);
        await tapText(tester, 'Me');
        expectIcons(tester, light: dark);
      });

      testWidgets('a profile over its photo has light icons', (tester) async {
        await start(tester);
        await tapText(tester, 'Alex 27');
        expectIcons(tester, light: true);
      });
    });
  }
}
