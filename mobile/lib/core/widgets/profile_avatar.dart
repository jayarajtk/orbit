import 'package:flutter/material.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/widgets/media_image.dart';

/// A member's photo when [photoUrl] is set; otherwise (and while it loads or
/// if it fails) their initial on a two-stop gradient picked from their id.
class ProfileAvatar extends StatelessWidget {
  /// Creates an avatar for [name] keyed by [seed].
  const ProfileAvatar({
    required this.name,
    required this.seed,
    this.size = 48,
    this.square = false,
    this.photoUrl,
    this.mediaId,
    this.ownerId,
    this.variant = MediaVariant.thumb,
    super.key,
  });

  /// Display name; its first letter is shown.
  final String name;

  /// Stable value (the profile id) that picks the colour.
  final String seed;

  /// Diameter, or edge length when [square].
  final double size;

  /// Square with rounded corners instead of a circle; fills its parent
  /// when [size] is [double.infinity].
  final bool square;

  /// Image to show; short-lived, so callers pass the latest link.
  final String? photoUrl;

  /// Media id of [photoUrl]; the cache key. Without it the image is not
  /// cached and downloads again on every view.
  final String? mediaId;

  /// Member whose cached image is evicted when they are blocked.
  final String? ownerId;

  /// Which rendition [photoUrl] points to; part of the cache key.
  final MediaVariant variant;

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder(context);
    final url = photoUrl;
    final id = mediaId;
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
          child: id == null
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) =>
                          frame == null && !wasSynchronouslyLoaded
                          ? placeholder
                          : child,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                )
              : MediaImage(
                  mediaId: id,
                  url: url,
                  variant: variant,
                  ownerId: ownerId,
                  placeholder: placeholder,
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final tokens = context.tokens;
    final gradients = tokens.avatarGradients;
    final (start, end) = gradients[seed.hashCode.abs() % gradients.length];
    final glyphSize = size.isFinite ? size * 0.42 : 48.0;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end],
          ),
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(12) : null,
        ),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(
            color: tokens.onAvatar,
            fontSize: glyphSize,
            fontWeight: FontWeight.w700,
          ),
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
        color: context.tokens.online,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}
