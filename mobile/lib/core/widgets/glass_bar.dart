import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:orbit/app/theme.dart';

/// Which edge of a [FrostedBackground] carries the hairline.
enum FrostedEdge {
  /// The hairline runs along the top, for bars at the bottom of the screen.
  top,

  /// The hairline runs along the bottom, for bars at the top of the screen.
  bottom,
}

/// The frosted look shared by every bar: a blur of 20 over the translucent
/// surface colour, with a hairline along one edge (spec section 7.2).
class FrostedBackground extends StatelessWidget {
  /// Creates the frosted fill, with [child] drawn on top of it.
  const FrostedBackground({required this.edge, this.child, super.key});

  /// Where the hairline sits.
  final FrostedEdge edge;

  /// Content drawn over the glass.
  final Widget? child;

  static const _blur = 20.0;
  static const _fillAlpha = 0.72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final line = BorderSide(color: tokens.hairline, width: 0.5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: _fillAlpha),
            border: switch (edge) {
              FrostedEdge.top => Border(top: line),
              FrostedEdge.bottom => Border(bottom: line),
            },
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Frosted glass behind a bottom bar.
class GlassBar extends StatelessWidget {
  /// Creates a frosted bar around [child].
  const GlassBar({required this.child, super.key});

  /// The bar content. It must paint no background of its own.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FrostedBackground(edge: FrostedEdge.top, child: child);
}

/// A pinned, frosted top bar whose title is large (34 pt bold) at rest and
/// collapses to 17 pt semibold as the page scrolls.
class LargeTitleSliverAppBar extends StatelessWidget {
  /// Creates the bar for [title].
  const LargeTitleSliverAppBar({required this.title, this.actions, super.key});

  /// The bar's title text.
  final String title;

  /// Buttons at the trailing edge.
  final List<Widget>? actions;

  static const _expandedHeight = 112.0;
  static const double _largeScale = 34 / 17;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      actions: actions,
      flexibleSpace: FrostedBackground(
        edge: FrostedEdge.bottom,
        child: FlexibleSpaceBar(
          // iOS centres FlexibleSpaceBar titles by default; large titles lead.
          centerTitle: false,
          expandedTitleScale: _largeScale,
          titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
          title: _LargeTitle(title: title, color: tokens.text),
        ),
      ),
    );
  }
}

/// The bar's title: the 17 pt title style, scaled to 34 pt by the bar while
/// expanded. Scaling can't change the weight, so it is bold while the bar is
/// mostly expanded and semibold once it is mostly collapsed.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final range = settings == null
        ? 0.0
        : settings.maxExtent - settings.minExtent;
    final expanded = settings == null || range <= 0
        ? 1.0
        : (settings.currentExtent - settings.minExtent) / range;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: color,
        fontWeight: expanded >= 0.5 ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}
