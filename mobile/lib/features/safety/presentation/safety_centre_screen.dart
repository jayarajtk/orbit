import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Topics in the safety centre.
enum SafetyTopic {
  /// Meeting someone new.
  meeting,

  /// Travel safety.
  travel,

  /// Sexual health.
  health,

  /// Blocking and reporting.
  moderation,
}

extension on SafetyTopic {
  (IconData, String, String, String) content(AppLocalizations l10n) =>
      switch (this) {
        SafetyTopic.meeting => (
          Icons.explore_outlined,
          l10n.topicMeeting,
          l10n.topicMeetingSub,
          l10n.topicMeetingBody,
        ),
        SafetyTopic.travel => (
          Icons.public,
          l10n.topicTravel,
          l10n.topicTravelSub,
          l10n.topicTravelBody,
        ),
        SafetyTopic.health => (
          Icons.health_and_safety_outlined,
          l10n.topicHealth,
          l10n.topicHealthSub,
          l10n.topicHealthBody,
        ),
        SafetyTopic.moderation => (
          Icons.shield_outlined,
          l10n.topicModeration,
          l10n.topicModerationSub,
          l10n.topicModerationBody,
        ),
      };
}

/// W16: safety tips and help. Free for everyone.
class SafetyCentreScreen extends StatelessWidget {
  /// Creates the safety centre.
  const SafetyCentreScreen({super.key});

  Future<void> _getHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.getHelpTitle),
        content: Text(l10n.getHelpBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final topic in SafetyTopic.values)
            Builder(
              builder: (context) {
                final (icon, title, subtitle, _) = topic.content(l10n);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: scheme.outline,
                      child: Icon(icon, color: scheme.primary),
                    ),
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.safetyTopic(topic)),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _getHelp(context),
            icon: const Icon(Icons.sos_outlined),
            label: Text(l10n.getHelp),
          ),
        ],
      ),
    );
  }
}

/// One safety centre topic.
class SafetyTopicScreen extends StatelessWidget {
  /// Creates the topic page.
  const SafetyTopicScreen({required this.topic, super.key});

  /// Which topic to show.
  final SafetyTopic topic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (_, title, _, body) = topic.content(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
