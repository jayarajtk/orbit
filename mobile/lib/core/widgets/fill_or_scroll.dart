import 'package:flutter/material.dart';

/// Lays [child] out at least as tall as the viewport, so `Expanded` and
/// `Spacer` push actions to the bottom on normal screens, and scrolls when
/// the content is taller (short screens, landscape, large text).
///
/// Use for short, form-like screens only; long lists should use a builder.
class FillOrScroll extends StatelessWidget {
  /// Wraps [child], typically a `Column`, with [padding] inside the scroll.
  const FillOrScroll({required this.child, this.padding, super.key});

  /// The content to fill or scroll.
  final Widget child;

  /// Space around [child], inside the scrollable area.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - _verticalPadding(context),
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }

  double _verticalPadding(BuildContext context) =>
      padding?.resolve(Directionality.of(context)).vertical ?? 0;
}
