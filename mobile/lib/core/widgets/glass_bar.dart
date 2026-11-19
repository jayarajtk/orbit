import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:orbit/app/theme.dart';

/// Frosted glass behind a bar: a blur of 20 over the translucent surface
/// colour, with a hairline along the top edge (spec section 7.2).
class GlassBar extends StatelessWidget {
  /// Creates a frosted bar around [child].
  const GlassBar({required this.child, super.key});

  /// The bar content. It must paint no background of its own.
  final Widget child;

  static const _blur = 20.0;
  static const _fillAlpha = 0.72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: _fillAlpha),
            border: Border(top: BorderSide(color: tokens.hairline, width: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
