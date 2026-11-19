import 'dart:async';

import 'package:flutter/material.dart';

/// A placeholder block with a soft light sweep, shown while content loads.
/// The sweep is skipped when the platform asks for reduced motion.
class Skeleton extends StatefulWidget {
  /// Creates a block that fills its parent, with rounded corners of
  /// [radius].
  const Skeleton({this.radius = 12, super.key});

  /// Corner radius.
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      unawaited(_sweep.repeat());
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surfaceContainerHigh;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
              transform: _SweepTransform(_sweep.value),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides a gradient across its box as [progress] goes from 0 to 1.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}
