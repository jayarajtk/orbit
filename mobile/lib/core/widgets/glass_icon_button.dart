import 'dart:ui';

import 'package:flutter/material.dart';

/// A round icon button on a blurred dark backing, readable over any photo.
class GlassIconButton extends StatelessWidget {
  /// Creates a glass icon button.
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.selectedIcon,
    super.key,
  });

  /// The icon shown when [selected] is false, or when no [selectedIcon] is set.
  final IconData icon;

  /// The tooltip, also used as the accessibility label.
  final String tooltip;

  /// Called when the button is tapped; the button is disabled when null.
  final VoidCallback? onPressed;

  /// Whether the button shows its on state.
  final bool selected;

  /// The icon shown when [selected] is true.
  final IconData? selectedIcon;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.35), // photo-overlay
            child: SizedBox.square(
              dimension: _size,
              child: IconButton(
                tooltip: tooltip,
                isSelected: selected,
                icon: Icon(icon),
                selectedIcon: selectedIcon == null ? null : Icon(selectedIcon),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white, // photo-overlay
                  padding: EdgeInsets.zero,
                ),
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
