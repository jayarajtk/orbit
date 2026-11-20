import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';

import 'theme_test.dart' show contrastRatio, tokensOf;

/// The colour the engine paints [text] with; null means the engine default,
/// which iOS draws white.
Color? paintedColour(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  return paragraph.text.style?.color;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('switch tile help text is readable in ${brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOrbitTheme(brightness),
          home: Scaffold(
            body: SwitchListTile(
              value: true,
              onChanged: (_) {},
              title: const Text('Read receipts'),
              subtitle: const Text('Help text'),
            ),
          ),
        ),
      );

      final colour = paintedColour(tester, 'Help text');
      expect(colour, isNotNull);
      expect(
        contrastRatio(colour!, tokensOf(brightness).ground),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
