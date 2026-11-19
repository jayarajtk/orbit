import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// Colour tokens for both brightnesses (spec section 7.1). Widgets read them
/// with `context.tokens`, or use the [ColorScheme] built from them.
@immutable
class OrbitTokens extends ThemeExtension<OrbitTokens> {
  /// Creates a token set.
  const OrbitTokens({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.online,
    required this.ringStart,
    required this.ringEnd,
    required this.avatarGradients,
    required this.onAvatar,
    required this.readTick,
  });

  /// The dark set, used when the phone is in dark mode.
  static final dark = OrbitTokens(
    ground: const Color(0xFF000000),
    surface: const Color(0xFF1C1C1E),
    surfaceRaised: const Color(0xFF2C2C2E),
    hairline: const Color(0xFF38383A).withValues(alpha: 0.6),
    text: const Color(0xFFFFFFFF),
    textMuted: const Color(0xFF98989F),
    accent: const Color(0xFFFF6A55),
    online: const Color(0xFF30D158),
    ringStart: const Color(0xFFFF6A55),
    ringEnd: _ringEnd,
    avatarGradients: _avatarGradients,
    onAvatar: _onAvatar,
    readTick: const Color(0xFFFF9A8A),
  );

  /// The light set, used when the phone is in light mode.
  static final light = OrbitTokens(
    ground: const Color(0xFFF5F5F7),
    surface: const Color(0xFFFFFFFF),
    surfaceRaised: const Color(0xFFE9E9EB),
    hairline: const Color(0xFFC6C6C8).withValues(alpha: 0.6),
    text: const Color(0xFF000000),
    textMuted: const Color(0xFF6C6C70),
    accent: const Color(0xFFE8513D),
    // Deviates from spec 7.1 (#28A745, 2.88:1 on ground): WCAG 3:1 outranks it.
    online: const Color(0xFF248A3D),
    ringStart: const Color(0xFFE8513D),
    ringEnd: _ringEnd,
    avatarGradients: _avatarGradients,
    onAvatar: _onAvatar,
    readTick: const Color(0xFFA8301F),
  );

  static const _ringEnd = Color(0xFFFF9F0A);

  // White initials on every stop are at least 4.5:1 (WCAG AA), so the same
  // pairs serve both brightnesses.
  static const _onAvatar = Color(0xFFFFFFFF);
  static const _avatarGradients = <(Color, Color)>[
    (Color(0xFF5B4FCF), Color(0xFF3A67A8)),
    (Color(0xFFA63E62), Color(0xFF7446A0)),
    (Color(0xFF2B7366), Color(0xFF3A67A8)),
    (Color(0xFF7E5219), Color(0xFFA63E62)),
    (Color(0xFF3A67A8), Color(0xFF5B4FCF)),
    (Color(0xFF7446A0), Color(0xFFA63E62)),
  ];

  /// Page background.
  final Color ground;

  /// Cards, inputs and sheets.
  final Color surface;

  /// Elevated fills on top of [surface].
  final Color surfaceRaised;

  /// Dividers and borders, already translucent.
  final Color hairline;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color textMuted;

  /// The one brand colour, for primary actions and selection.
  final Color accent;

  /// Online indicator.
  final Color online;

  /// Start of the unseen status ring gradient.
  final Color ringStart;

  /// End of the unseen status ring gradient.
  final Color ringEnd;

  /// Two-stop gradients for the initial placeholder avatars.
  final List<(Color, Color)> avatarGradients;

  /// Text colour on [avatarGradients].
  final Color onAvatar;

  /// Colour of the read ticks on [ownBubble]: a shade of [accent] chosen for
  /// contrast against that fill, not the brand accent itself.
  final Color readTick;

  /// Fill of the member's own chat bubbles: a wash of [accent] over
  /// [surface], clearly apart from incoming bubbles and the page.
  Color get ownBubble =>
      Color.alphaBlend(accent.withValues(alpha: 0.2), surface);

  /// Time text colour on a bubble filled with [bubble]: [text] at reduced
  /// strength, which clears AA on both bubble fills.
  Color onBubbleMuted(Color bubble) =>
      Color.alphaBlend(text.withValues(alpha: 0.7), bubble);

  /// Sent and delivered tick colour on [bubble]: fainter than the time text
  /// so it stays distinct from [readTick], and still 3:1 against the fill.
  Color tickMuted(Color bubble) =>
      Color.alphaBlend(text.withValues(alpha: 0.45), bubble);

  @override
  OrbitTokens copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? hairline,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? online,
    Color? ringStart,
    Color? ringEnd,
    List<(Color, Color)>? avatarGradients,
    Color? onAvatar,
    Color? readTick,
  }) {
    return OrbitTokens(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      hairline: hairline ?? this.hairline,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      online: online ?? this.online,
      ringStart: ringStart ?? this.ringStart,
      ringEnd: ringEnd ?? this.ringEnd,
      avatarGradients: avatarGradients ?? this.avatarGradients,
      onAvatar: onAvatar ?? this.onAvatar,
      readTick: readTick ?? this.readTick,
    );
  }

  @override
  OrbitTokens lerp(OrbitTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OrbitTokens(
      ground: mix(ground, other.ground),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      hairline: mix(hairline, other.hairline),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      online: mix(online, other.online),
      ringStart: mix(ringStart, other.ringStart),
      ringEnd: mix(ringEnd, other.ringEnd),
      avatarGradients: t < 0.5 ? avatarGradients : other.avatarGradients,
      onAvatar: mix(onAvatar, other.onAvatar),
      readTick: mix(readTick, other.readTick),
    );
  }
}

/// Access to the [OrbitTokens] of the current theme.
extension OrbitTokensContext on BuildContext {
  /// The tokens of the surrounding [Theme]. A plain [ThemeData] without the
  /// extension (a stock `MaterialApp`) gets the set for its brightness.
  OrbitTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<OrbitTokens>() ??
        (theme.brightness == Brightness.dark
            ? OrbitTokens.dark
            : OrbitTokens.light);
  }
}

/// Builds the Orbit theme for the phone's [brightness].
ThemeData buildOrbitTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark ? OrbitTokens.dark : OrbitTokens.light;
  // Black text on the accent: white on #E8513D is 3.7:1, below AA, and white
  // on the dark accent is lower still. Black gives 5.7:1 and 7.4:1.
  const onAccent = Color(0xFF000000);
  // The spec has no error token: Apple's accessible system reds, which keep
  // AA as text on the page and under their label colour.
  final danger = isDark ? const Color(0xFFFF6961) : const Color(0xFFD70015);
  final onDanger = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  // Snack bars and other inverse surfaces use the other mode's surface. The
  // light accent is too pale on white for AA, so the dark mode inverse
  // accent is its darker read-tick shade.
  final inverse = isDark ? OrbitTokens.light : OrbitTokens.dark;
  final inverseAccent = isDark ? inverse.readTick : inverse.accent;
  // Every role is set, so none falls back to the Material 2 purple and teal
  // that `ColorScheme.light()` and `.dark()` start from. One brand colour:
  // the primary, secondary and tertiary families all use the accent, and
  // the containers that carry no emphasis use the raised surface.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: onAccent,
    primaryContainer: tokens.accent,
    onPrimaryContainer: onAccent,
    primaryFixed: tokens.accent,
    primaryFixedDim: tokens.accent,
    onPrimaryFixed: onAccent,
    onPrimaryFixedVariant: onAccent,
    secondary: tokens.accent,
    onSecondary: onAccent,
    secondaryContainer: tokens.surfaceRaised,
    onSecondaryContainer: tokens.text,
    secondaryFixed: tokens.surfaceRaised,
    secondaryFixedDim: tokens.surfaceRaised,
    onSecondaryFixed: tokens.text,
    onSecondaryFixedVariant: tokens.textMuted,
    tertiary: tokens.accent,
    onTertiary: onAccent,
    tertiaryContainer: tokens.accent,
    onTertiaryContainer: onAccent,
    tertiaryFixed: tokens.accent,
    tertiaryFixedDim: tokens.accent,
    onTertiaryFixed: onAccent,
    onTertiaryFixedVariant: onAccent,
    error: danger,
    onError: onDanger,
    errorContainer: danger,
    onErrorContainer: onDanger,
    surface: tokens.ground,
    onSurface: tokens.text,
    surfaceDim: tokens.ground,
    surfaceBright: tokens.surface,
    surfaceContainerLowest: tokens.surface,
    surfaceContainerLow: tokens.surface,
    surfaceContainer: tokens.surface,
    surfaceContainerHigh: tokens.surface,
    surfaceContainerHighest: tokens.surfaceRaised,
    onSurfaceVariant: tokens.textMuted,
    outline: tokens.hairline,
    outlineVariant: tokens.hairline,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: inverse.surface,
    onInverseSurface: inverse.text,
    inversePrimary: inverseAccent,
    // Depth comes from surface contrast (spec 7.2), never a tint.
    surfaceTint: const Color(0x00000000),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outline),
  );
  const minTapSize = Size(double.infinity, 52);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return ThemeData(
    colorScheme: scheme,
    extensions: [tokens],
    scaffoldBackgroundColor: scheme.surface,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTapSize,
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTapSize,
        shape: buttonShape,
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide.none,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 17),
      bodyMedium: TextStyle(fontSize: 17),
      bodySmall: TextStyle(fontSize: 15),
    ),
    listTileTheme: const ListTileThemeData(
      subtitleTextStyle: TextStyle(fontSize: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // The frosted `GlassBar` supplies the fill, so the bar is clear.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.textMuted,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      // A transparent bar makes Flutter guess light icons whatever the page
      // colour is; the icons follow the theme instead. Screens drawn over a
      // photo or black set `SystemUiOverlayStyle.light` themselves.
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      side: BorderSide(color: scheme.outline),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainer),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
