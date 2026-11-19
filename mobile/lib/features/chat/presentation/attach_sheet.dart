import 'package:flutter/material.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// What the member picked in the [AttachSheet].
enum AttachChoice {
  /// Several photos from the library, up to ten.
  photos,

  /// A new photo from the camera.
  camera,

  /// A photo the other member can open once.
  viewOnce,

  /// One of the member's private albums.
  album,

  /// A timed live-location share.
  location,

  /// A ready-made short message.
  quickPhrase,
}

/// Shows the [AttachSheet] and returns the choice, or null if dismissed.
/// Photo options are disabled when [mediaEnabled] is false (no server).
Future<AttachChoice?> showAttachSheet(
  BuildContext context, {
  required bool mediaEnabled,
}) => showModalBottomSheet<AttachChoice>(
  context: context,
  showDragHandle: true,
  builder: (context) => AttachSheet(mediaEnabled: mediaEnabled),
);

/// The compact list of things the "+" button can add to a chat.
class AttachSheet extends StatelessWidget {
  /// Creates the sheet.
  const AttachSheet({required this.mediaEnabled, super.key});

  /// Whether photos can be uploaded; false in demo mode, which has no server.
  final bool mediaEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      (AttachChoice.photos, Icons.photo_library_outlined, l10n.photosOption),
      (AttachChoice.camera, Icons.photo_camera_outlined, l10n.cameraOption),
      (AttachChoice.viewOnce, Icons.filter_1_outlined, l10n.viewOnceOption),
      (AttachChoice.album, Icons.collections_outlined, l10n.albumTooltip),
      (AttachChoice.location, Icons.place_outlined, l10n.locationTooltip),
      (AttachChoice.quickPhrase, Icons.bolt_outlined, l10n.quickPhrasesTooltip),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (choice, icon, label) in options)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              enabled: mediaEnabled || !_needsServer(choice),
              onTap: () => Navigator.of(context).pop(choice),
            ),
        ],
      ),
    );
  }

  static bool _needsServer(AttachChoice choice) =>
      choice == AttachChoice.photos ||
      choice == AttachChoice.camera ||
      choice == AttachChoice.viewOnce;
}
