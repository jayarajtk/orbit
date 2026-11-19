import 'dart:io';
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

OrbitTokens tokensOf(Brightness brightness) =>
    buildOrbitTheme(brightness).extension<OrbitTokens>()!;

/// Every colour role of [scheme], by name, as its diagnostics list them.
Map<String, Color> schemeRoles(ColorScheme scheme) => {
  for (final property in scheme.toDiagnosticsNode().getProperties())
    if (property.value case final Color colour) property.name!: colour,
};

/// The scheme's content-on-fill pairs that carry text, at the AA minimum.
Map<String, (Color, Color, double)> schemePairs(ColorScheme s) => {
  'onPrimaryContainer on primaryContainer': (
    s.onPrimaryContainer,
    s.primaryContainer,
    4.5,
  ),
  'onSecondary on secondary': (s.onSecondary, s.secondary, 4.5),
  'onSecondaryContainer on secondaryContainer': (
    s.onSecondaryContainer,
    s.secondaryContainer,
    4.5,
  ),
  'onTertiary on tertiary': (s.onTertiary, s.tertiary, 4.5),
  'onTertiaryContainer on tertiaryContainer': (
    s.onTertiaryContainer,
    s.tertiaryContainer,
    4.5,
  ),
  'onError on error': (s.onError, s.error, 4.5),
  'onErrorContainer on errorContainer': (
    s.onErrorContainer,
    s.errorContainer,
    4.5,
  ),
  'error on surface': (s.error, s.surface, 4.5),
  'onInverseSurface on inverseSurface': (
    s.onInverseSurface,
    s.inverseSurface,
    4.5,
  ),
  'inversePrimary on inverseSurface': (
    s.inversePrimary,
    s.inverseSurface,
    4.5,
  ),
};

void main() {
  group('tokens match the spec in both modes', () {
    test('dark', () {
      final t = tokensOf(Brightness.dark);
      expect(t.ground, const Color(0xFF000000));
      expect(t.surface, const Color(0xFF1C1C1E));
      expect(t.surfaceRaised, const Color(0xFF2C2C2E));
      expect(t.hairline, const Color(0xFF38383A).withValues(alpha: 0.6));
      expect(t.text, const Color(0xFFFFFFFF));
      expect(t.textMuted, const Color(0xFF98989F));
      expect(t.accent, const Color(0xFFFF6A55));
      expect(t.online, const Color(0xFF30D158));
      expect(t.ringStart, t.accent);
      expect(t.ringEnd, const Color(0xFFFF9F0A));
    });

    test('light', () {
      final t = tokensOf(Brightness.light);
      expect(t.ground, const Color(0xFFF5F5F7));
      expect(t.surface, const Color(0xFFFFFFFF));
      expect(t.surfaceRaised, const Color(0xFFE9E9EB));
      expect(t.hairline, const Color(0xFFC6C6C8).withValues(alpha: 0.6));
      expect(t.text, const Color(0xFF000000));
      expect(t.textMuted, const Color(0xFF6C6C70));
      expect(t.accent, const Color(0xFFE8513D));
      expect(t.online, const Color(0xFF248A3D));
      expect(t.ringStart, t.accent);
      expect(t.ringEnd, const Color(0xFFFF9F0A));
    });

    test('colour scheme maps to the tokens', () {
      for (final b in Brightness.values) {
        final theme = buildOrbitTheme(b);
        final t = theme.extension<OrbitTokens>()!;
        final s = theme.colorScheme;
        expect(s.brightness, b);
        expect(s.primary, t.accent);
        expect(s.surface, t.ground);
        expect(s.surfaceContainer, t.surface);
        expect(s.surfaceContainerHighest, t.surfaceRaised);
        expect(s.onSurface, t.text);
        expect(s.onSurfaceVariant, t.textMuted);
        expect(s.outline, t.hairline);
      }
    });
  });

  group('no colour scheme role keeps a Material default', () {
    // Every colour the stock schemes use, bar plain black and white: a role
    // left at one of these was never mapped from the tokens (the purple
    // "Add photos" button was primaryContainer at #6200EE).
    final defaults = {
      for (final stock in [const ColorScheme.light(), const ColorScheme.dark()])
        ...schemeRoles(stock).values,
    }..removeAll(const [Color(0xFF000000), Color(0xFFFFFFFF)]);

    for (final brightness in Brightness.values) {
      test(brightness.name, () {
        final roles = schemeRoles(buildOrbitTheme(brightness).colorScheme);
        final leftovers = {
          for (final MapEntry(key: role, value: colour) in roles.entries)
            if (defaults.contains(colour)) role: colour,
        };
        expect(leftovers, isEmpty);
      });
    }
  });

  for (final brightness in Brightness.values) {
    group('text pairs meet WCAG AA in ${brightness.name} mode', () {
      final theme = buildOrbitTheme(brightness);
      final t = theme.extension<OrbitTokens>()!;
      final pairs = <String, (Color, Color, double)>{
        'text on ground': (t.text, t.ground, 4.5),
        'text on surface': (t.text, t.surface, 4.5),
        'muted text on surface': (t.textMuted, t.surface, 4.5),
        'muted text on ground': (t.textMuted, t.ground, 4.5),
        'accent on ground': (t.accent, t.ground, 3.0),
        'online on ground': (t.online, t.ground, 3.0),
        'label on accent': (theme.colorScheme.onPrimary, t.accent, 4.5),
        ...schemePairs(theme.colorScheme),
      };
      for (final MapEntry(key: name, value: (fg, bg, min)) in pairs.entries) {
        test(name, () {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min));
        });
      }

      group('chat bubble pairs', () {
        final own = t.ownBubble;
        final incoming = t.surface;

        test('own bubbles stand apart from incoming ones and the page', () {
          expect(contrastRatio(own, incoming), greaterThanOrEqualTo(1.25));
          expect(contrastRatio(own, t.ground), greaterThanOrEqualTo(1.15));
        });

        test('time text on own and incoming bubbles', () {
          expect(
            contrastRatio(t.onBubbleMuted(own), own),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrastRatio(t.onBubbleMuted(incoming), incoming),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('sent and delivered ticks on own bubbles', () {
          expect(
            contrastRatio(t.tickMuted(own), own),
            greaterThanOrEqualTo(3.0),
          );
        });

        test('read ticks have margin and differ from sent ticks', () {
          expect(contrastRatio(t.readTick, own), greaterThanOrEqualTo(3.3));
          expect(
            contrastRatio(t.readTick, t.tickMuted(own)),
            greaterThanOrEqualTo(1.5),
          );
        });
      });

      test('initial text on every avatar gradient stop', () {
        for (final (start, end) in t.avatarGradients) {
          expect(contrastRatio(t.onAvatar, start), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(t.onAvatar, end), greaterThanOrEqualTo(4.5));
        }
      });
    });
  }

  for (final platform in Brightness.values) {
    testWidgets('app follows the platform brightness (${platform.name})', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOrbitTheme(Brightness.light),
          darkTheme: buildOrbitTheme(Brightness.dark),
          home: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(Theme.of(inner).brightness, platform);
      expect(inner.tokens.ground, tokensOf(platform).ground);
    });
  }

  test('no hard-coded colours outside theme', () {
    final literal = RegExp(r'Color\(0x|Colors\.(white|black)');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('app/theme.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i]) &&
            !lines[i].contains('// photo-overlay')) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
