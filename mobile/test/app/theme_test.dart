import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final scheme = buildOrbitTheme().colorScheme;

  group('theme colour pairs meet WCAG AA (4.5:1) for body text', () {
    final pairs = <String, (Color, Color)>{
      'text on background': (scheme.onSurface, scheme.surface),
      'muted text on background': (scheme.onSurfaceVariant, scheme.surface),
      'muted text on card': (scheme.onSurfaceVariant, scheme.surfaceContainer),
      'button label on coral': (scheme.onPrimary, scheme.primary),
    };

    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
