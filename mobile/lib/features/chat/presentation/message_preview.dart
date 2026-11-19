import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// One-line inbox preview for [message].
String messagePreview(AppLocalizations l10n, Message message) {
  if (message.unsent) return l10n.previewUnsent;
  final body = switch (message.kind) {
    MessageKind.text => message.text,
    MessageKind.wave =>
      message.fromMe ? l10n.previewWaveOut : l10n.previewWaveIn,
    MessageKind.location => l10n.previewLocation,
    MessageKind.album => l10n.previewAlbum,
    MessageKind.photo =>
      message.viewOnce ? l10n.viewOnceSent : l10n.photoMessage,
    MessageKind.video => l10n.videoMessage,
    MessageKind.voice => l10n.voiceMessage,
  };
  final isText = message.kind == MessageKind.text;
  return message.fromMe && isText ? l10n.previewYou(body) : body;
}

/// Short timestamp: time today, weekday this week, otherwise the date.
///
/// Both arguments may be UTC; they are compared and formatted in local time.
String shortTimestamp(BuildContext context, DateTime time, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final localTime = time.toLocal();
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  if (!localTime.isBefore(today)) {
    return DateFormat.jm(locale).format(localTime);
  }
  if (today.difference(localTime).inDays < 6) {
    return DateFormat.E(locale).format(localTime);
  }
  return DateFormat.MMMd(locale).format(localTime);
}

/// Time of day for a message, in the member's local time.
String messageTime(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.jm(locale).format(time.toLocal());
}
