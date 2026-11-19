import 'package:flutter/material.dart';

/// A member's photo when [photoUrl] is set; otherwise (and while it loads or
/// if it fails) their initial on a colour picked from their id, or a person
/// icon when they have no photo.
class ProfileAvatar extends StatelessWidget {
  /// Creates an avatar for [name] keyed by [seed].
  const ProfileAvatar({
    required this.name,
    required this.seed,
    this.hasPhoto = true,
    this.size = 48,
    this.square = false,
    this.photoUrl,
    super.key,
  });

  // White text on each of these is at least 4.5:1 (WCAG AA).
  static const _palette = [
    Color(0xFF5B4FCF),
    Color(0xFFA63E62),
    Color(0xFF2B7366),
    Color(0xFF7E5219),
    Color(0xFF3A67A8),
    Color(0xFF7446A0),
  ];

  /// Display name; its first letter is shown.
  final String name;

  /// Stable value (the profile id) that picks the colour.
  final String seed;

  /// Whether to show the initial; otherwise a neutral icon.
  final bool hasPhoto;

  /// Diameter, or edge length when [square].
  final double size;

  /// Square with rounded corners instead of a circle; fills its parent
  /// when [size] is [double.infinity].
  final bool square;

  /// Image to show; short-lived, so callers pass the latest link.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder(context);
    final url = photoUrl;
    if (url == null) return placeholder;
    final radius = square
        ? BorderRadius.circular(12)
        : BorderRadius.circular(size.isFinite ? size / 2 : 0);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                frame == null && !wasSynchronouslyLoaded ? placeholder : child,
            errorBuilder: (context, error, stackTrace) => placeholder,
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = hasPhoto
        ? _palette[seed.hashCode.abs() % _palette.length]
        : scheme.surfaceContainerHighest;
    final glyphSize = size.isFinite ? size * 0.42 : 44.0;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(12) : null,
        ),
        child: hasPhoto
            ? Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: glyphSize,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Icon(
                Icons.person_outline,
                size: glyphSize,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

/// Small green dot meaning "online now".
class OnlineDot extends StatelessWidget {
  /// Creates the dot.
  const OnlineDot({this.size = 10, super.key});

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}
