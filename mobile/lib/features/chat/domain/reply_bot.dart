/// Canned replies so dummy members answer during development. Deterministic:
/// the same input and turn always give the same reply, which keeps tests
/// stable. Removed when chat talks to the real server.
abstract final class ReplyBot {
  static const _answers = [
    'Good question! Honestly, a bit of everything. You?',
    "Ha, I was just wondering the same. What's your take?",
    'Depends on the day 😄 What about you?',
  ];

  static const _chatter = [
    'Hey! Nice to hear from you 🙂',
    'Ha, love that.',
    'Same here. What are you up to this weekend?',
    "That sounds fun — I'm in.",
    'Haha, okay you win this round.',
    'Tell me more!',
  ];

  /// The reply to [text] on the dummy member's [turn] (0-based).
  static String replyTo(String text, int turn) {
    final pool = text.trim().endsWith('?') ? _answers : _chatter;
    return pool[turn % pool.length];
  }

  /// The reply to a wave.
  static const waveBack = 'Hey, thanks for the wave! 👋';

  /// The reply to an album share.
  static const albumThanks = 'Thanks for sharing — great pics!';

  /// The reply to a live-location share.
  static const locationThanks = 'Got it, see you soon!';
}
