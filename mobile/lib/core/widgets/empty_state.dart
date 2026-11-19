import 'package:flutter/material.dart';

/// Centered icon and message for a screen that has nothing to show yet.
class EmptyState extends StatelessWidget {
  /// Creates an empty state with an [icon] and a [message].
  const EmptyState({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  /// Decorative icon above the message.
  final IconData icon;

  /// What the user can do next.
  final String message;

  /// Optional button under the message, such as "Create album".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
