// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'orbit';

  @override
  String get backTooltip => 'Back';

  @override
  String get continueButton => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get undo => 'Undo';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get welcomeHeadline => 'Meet people nearby.';

  @override
  String get welcomeTagline => 'Fast. Private. No ads — ever.';

  @override
  String get welcomePrivacyPromise =>
      'Your exact location is never stored — only a rounded area.';

  @override
  String get welcomeGetStarted => 'Get started';

  @override
  String get welcomeAgeNotice => '18+ only';

  @override
  String get signInTitle => 'Sign in to Orbit';

  @override
  String get signInSubtitle => 'Pick any. You can link more later.';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithPhone => 'Continue with phone number';

  @override
  String get signInFailed => 'Sign-in didn\'t complete. Please try again.';

  @override
  String get signInNoPosting =>
      'We never post anything or show Orbit on your other accounts.';

  @override
  String get ageGateTitle => 'When\'s your birthday?';

  @override
  String get ageGateBody =>
      'You must be 18 or older. Your birthday stays private; only your age can be shown, and you can hide it.';

  @override
  String get ageGatePick => 'Choose your birthday';

  @override
  String get ageGateChange => 'Change';

  @override
  String get ageGateUnderage => 'Sorry — Orbit is only for people 18 and over.';

  @override
  String get ageGateHelp => 'Your birthday';

  @override
  String get profileSetupTitle => 'Make your profile';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHint => 'What should people call you?';

  @override
  String get displayNameRequired => 'Enter a display name';

  @override
  String get lookingForLabel => 'Looking for';

  @override
  String get photoLaterNote =>
      'You can add photos from your profile once you\'re in.';

  @override
  String get locationTitle => 'See who\'s nearby';

  @override
  String get locationPointWhileUsing => 'Only while you\'re using the app';

  @override
  String get locationPointRounded =>
      'Rounded to your area — never your exact spot';

  @override
  String get locationPointHide => 'Hide your distance any time in Settings';

  @override
  String get locationAllow => 'Allow while using';

  @override
  String get locationNotNow => 'Not now';

  @override
  String get lookingForChat => 'Chat';

  @override
  String get lookingForDates => 'Dates';

  @override
  String get lookingForFriends => 'Friends';

  @override
  String get lookingForNetworking => 'Networking';

  @override
  String get lookingForRightNow => 'Right now';

  @override
  String get relationshipSingle => 'Single';

  @override
  String get relationshipDating => 'Dating';

  @override
  String get relationshipPartnered => 'Partnered';

  @override
  String get relationshipOpen => 'Open relationship';

  @override
  String get tabNearby => 'Nearby';

  @override
  String get tabInbox => 'Inbox';

  @override
  String get tabMe => 'Me';

  @override
  String get onlineFilter => 'Online';

  @override
  String get filtersTooltip => 'Filters';

  @override
  String get freshFaces => 'Fresh faces';

  @override
  String get distanceUnder1Km => '<1 km';

  @override
  String distanceKm(int km) {
    return '$km km';
  }

  @override
  String get distanceHidden => 'Distance hidden';

  @override
  String get distanceTenPlus => '10+ km';

  @override
  String nameAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String heightCm(int cm) {
    return '$cm cm';
  }

  @override
  String get onlineNow => 'Online';

  @override
  String get locationNeeded => 'Share your location to see who\'s nearby.';

  @override
  String get shareLocation => 'Share location';

  @override
  String get locationDenied =>
      'Location is off for Orbit. Turn it on in Settings to see who\'s nearby.';

  @override
  String get nearbyEmpty => 'No one nearby yet — try widening your filters.';

  @override
  String get loadFailed => 'Couldn\'t load profiles.';

  @override
  String get retry => 'Retry';

  @override
  String get actionFailed =>
      'Couldn\'t reach Orbit. Check your connection and try again.';

  @override
  String get profileUnavailable => 'This profile isn\'t available.';

  @override
  String get waveButton => 'Wave';

  @override
  String get messageButton => 'Message';

  @override
  String waveAgainIn(String time) {
    return 'Wave again in $time';
  }

  @override
  String waveLimitReached(String time) {
    return 'You\'ve waved twice today. Try again in $time.';
  }

  @override
  String waveSent(String name) {
    return 'You waved at $name';
  }

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get moreActions => 'More: block or report';

  @override
  String photoOf(int current, int total) {
    return 'Photo $current of $total';
  }

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersReset => 'Reset';

  @override
  String get filtersAge => 'Age';

  @override
  String filtersAgeRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get filtersOnlineNow => 'Online now';

  @override
  String get filtersHasPhoto => 'Has photo';

  @override
  String get filtersMaxDistance => 'Maximum distance';

  @override
  String get filtersAnyDistance => 'Any';

  @override
  String get filtersPlusLocked => 'Distance and more filters';

  @override
  String get filtersShowResults => 'Show results';

  @override
  String get orbitPlus => 'Orbit+';

  @override
  String blockName(String name) {
    return 'Block $name';
  }

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'You won\'t see each other anywhere in Orbit. They won\'t be told.';

  @override
  String get blockAction => 'Block';

  @override
  String blockedSnack(String name) {
    return '$name is blocked';
  }

  @override
  String get reportTitle => 'Report — choose a reason';

  @override
  String reportModeratorNote(String name) {
    return 'Reports go to a human moderator. $name won\'t be told.';
  }

  @override
  String get reportFake => 'Fake profile or spam';

  @override
  String get reportHarassment => 'Harassment';

  @override
  String get reportUnderage => 'May be under 18';

  @override
  String get reportPhotos => 'Inappropriate photos';

  @override
  String get reportThreat => 'Threat or danger';

  @override
  String reportAlsoBlock(String name) {
    return 'Also block $name';
  }

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSent => 'Thanks. A moderator will review your report.';

  @override
  String get inboxAll => 'All';

  @override
  String get inboxUnread => 'Unread';

  @override
  String get inboxFavorites => 'Favorites';

  @override
  String get inboxEmpty => 'Say hi to someone nearby.';

  @override
  String get inboxUnreadEmpty => 'You\'re all caught up.';

  @override
  String get inboxFavoritesEmpty => 'No chats with favorites yet.';

  @override
  String conversationDeleted(String name) {
    return 'Chat with $name deleted';
  }

  @override
  String previewYou(String text) {
    return 'You: $text';
  }

  @override
  String get previewWaveIn => 'Waved at you';

  @override
  String get previewWaveOut => 'You waved';

  @override
  String get previewLocation => 'Shared a live location';

  @override
  String get previewAlbum => 'Shared an album';

  @override
  String get previewUnsent => 'Message unsent';

  @override
  String get mutedLabel => 'Muted';

  @override
  String get unknownMember => 'Orbit member';

  @override
  String get messageHint => 'Message…';

  @override
  String get messageLabel => 'Message';

  @override
  String get sendTooltip => 'Send';

  @override
  String get albumTooltip => 'Share an album';

  @override
  String get locationTooltip => 'Share live location';

  @override
  String get quickPhrasesTooltip => 'Quick phrases';

  @override
  String typing(String name) {
    return '$name is typing…';
  }

  @override
  String get tickSent => 'Sent';

  @override
  String get tickDelivered => 'Delivered';

  @override
  String get tickRead => 'Read';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get typingStatus => 'typing…';

  @override
  String get statusSending => 'Sending…';

  @override
  String get statusFailed => 'Not sent · Tap to retry';

  @override
  String waveIn(String name) {
    return '$name waved at you';
  }

  @override
  String get waveOut => 'You waved';

  @override
  String waveInCount(String name, int count) {
    return '$name waved ×$count';
  }

  @override
  String waveOutCount(int count) {
    return 'You waved ×$count';
  }

  @override
  String locationCard(int minutes) {
    return 'Live location · $minutes min';
  }

  @override
  String albumCardOut(String album) {
    return 'You shared “$album”';
  }

  @override
  String albumCardIn(String name, String album) {
    return '$name shared “$album”';
  }

  @override
  String get unsentMessage => 'This message was unsent';

  @override
  String get unsendAction => 'Unsend';

  @override
  String get unsendExpired => 'Messages can only be unsent within 10 minutes.';

  @override
  String get shareLocationTitle => 'Share live location for';

  @override
  String minutesOption(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get hourOption => '1 hour';

  @override
  String get chatViewProfile => 'View profile';

  @override
  String get chatMute => 'Mute';

  @override
  String get chatUnmute => 'Unmute';

  @override
  String get chatBlockReport => 'Block or report';

  @override
  String get chatMenu => 'Chat options';

  @override
  String get phraseHi => 'Hey! How\'s your day going?';

  @override
  String get phraseCoffee => 'Fancy a coffee sometime?';

  @override
  String get phraseWhat => 'What brings you to Orbit?';

  @override
  String get phraseLater => 'Can\'t chat right now — talk later?';

  @override
  String shareAlbumTitle(String name) {
    return 'Share an album with $name';
  }

  @override
  String get shareAlbumEmpty =>
      'You don\'t have any albums yet. Create one to share it.';

  @override
  String get createAlbum => 'Create album';

  @override
  String albumPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get albumPrivate => 'Private';

  @override
  String get accessLasts => 'Access lasts';

  @override
  String get access24h => '24 hours';

  @override
  String get access7d => '7 days';

  @override
  String get accessUntilRevoked => 'Until I revoke';

  @override
  String get viewOnce => 'View-once photos';

  @override
  String get screenshotNote =>
      'Screenshots are blocked on Android and flagged to you on iOS.';

  @override
  String sharedWith(String name) {
    return 'Shared with $name';
  }

  @override
  String get revoke => 'Revoke';

  @override
  String get shareAlbumButton => 'Share album';

  @override
  String albumShared(String name) {
    return 'Album shared with $name';
  }

  @override
  String get myAlbumsTitle => 'My albums';

  @override
  String get albumNotShared => 'Not shared with anyone';

  @override
  String albumSharedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shared with $count people',
      one: 'Shared with 1 person',
    );
    return '$_temp0';
  }

  @override
  String get meTitle => 'Me';

  @override
  String profileComplete(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get menuEditProfile => 'Edit profile';

  @override
  String get menuAlbums => 'My albums';

  @override
  String get menuFavorites => 'Favorites';

  @override
  String get menuPlus => 'Orbit+';

  @override
  String get menuSafety => 'Safety centre';

  @override
  String get menuSettings => 'Settings & privacy';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get favoritesEmpty => 'Tap the star on a profile to add a favorite.';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get aboutLabel => 'About me';

  @override
  String get aboutHint => 'A line or two about you';

  @override
  String get pronounsLabel => 'Pronouns';

  @override
  String get heightLabel => 'Height (cm)';

  @override
  String get heightInvalid => 'Enter a height between 120 and 230 cm';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagsHint => 'Comma-separated, e.g. hiking, music';

  @override
  String get showOnProfile => 'Show on profile';

  @override
  String get showAge => 'Show my age';

  @override
  String get showDistance => 'Show my distance';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get settingsTitle => 'Settings & privacy';

  @override
  String get sectionPrivacy => 'Privacy';

  @override
  String get sectionSecurity => 'Security';

  @override
  String get sectionData => 'Your data';

  @override
  String get settingReadReceipts => 'Read receipts';

  @override
  String get settingReadReceiptsSubtitle =>
      'When off, you also won\'t see when others read yours';

  @override
  String get settingPreviews => 'Message text in notifications';

  @override
  String get settingIncognito => 'Incognito';

  @override
  String get settingIncognitoSubtitle => 'Browse without appearing in grids';

  @override
  String get settingDiscreetIcon => 'Discreet app icon';

  @override
  String get settingDiscreetIconSubtitle =>
      'A neutral icon and name on your home screen';

  @override
  String get settingShake => 'Shake to hide';

  @override
  String get settingAppLock => 'App lock (Face ID / fingerprint)';

  @override
  String get settingBlocked => 'Blocked users';

  @override
  String get settingExport => 'Export my data';

  @override
  String get exportStarted =>
      'We\'re preparing your data. You\'ll get a download link within 30 days.';

  @override
  String get settingDelete => 'Delete account';

  @override
  String get deleteConfirmTitle => 'Delete your account?';

  @override
  String get deleteConfirmBody =>
      'Your account is hidden now and permanently deleted after 14 days. Sign back in within 14 days to cancel.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteRequested =>
      'Account deletion requested. Sign in within 14 days to cancel.';

  @override
  String get signOut => 'Sign out';

  @override
  String get blockedEmpty => 'You haven\'t blocked anyone.';

  @override
  String get unblock => 'Unblock';

  @override
  String unblocked(String name) {
    return '$name is unblocked';
  }

  @override
  String get safetyTitle => 'Safety centre';

  @override
  String get topicMeeting => 'Meeting someone new';

  @override
  String get topicMeetingSub =>
      'Tips, and share live location with a trusted friend';

  @override
  String get topicMeetingBody =>
      'Meet somewhere public the first time, and get there on your own.\n\nTell a friend where you\'re going. You can share your live location from any chat for up to an hour.\n\nKeep the conversation in Orbit until you trust someone. Be wary of anyone who rushes you or asks for money.\n\nTrust your gut. It\'s always okay to leave.';

  @override
  String get topicTravel => 'Travel safety';

  @override
  String get topicTravelSub => 'Safer defaults where being queer is risky';

  @override
  String get topicTravelBody =>
      'In some countries, same-sex relationships are criminalised. When you travel there, Orbit hides your distance by default and shows a safety notice.\n\nConsider turning on the discreet app icon and app lock before you go.\n\nBe cautious with anyone who asks to meet very quickly or pushes to move the chat elsewhere.';

  @override
  String get topicHealth => 'Sexual health';

  @override
  String get topicHealthSub => 'Testing reminders and local services';

  @override
  String get topicHealthBody =>
      'Regular testing is part of looking after yourself and your partners. Many people test every three months.\n\nAsk a local clinic about PrEP, PEP and vaccinations.\n\nHealth details on your profile are always optional and private by default.';

  @override
  String get topicModeration => 'Blocking & reporting';

  @override
  String get topicModerationSub => 'How moderation works and what happens next';

  @override
  String get topicModerationBody =>
      'Blocking is instant and two-way: neither of you will see the other anywhere in Orbit. The other person is never told.\n\nReports go to a human moderator. Reports about minors and threats are reviewed first.\n\nWe may warn, suspend or ban accounts. Safety tools are free for everyone.';

  @override
  String get getHelp => 'Get help now';

  @override
  String get getHelpTitle => 'If you\'re in danger';

  @override
  String get getHelpBody =>
      'Call your local emergency number now. When you\'re safe, block and report the person so our team can act.';

  @override
  String get plusIntro => 'Orbit is always ad-free. Orbit+ adds:';

  @override
  String get perkMoreProfiles => 'More profiles in your grid';

  @override
  String get perkFilters => 'Distance and advanced filters';

  @override
  String get perkIncognito => 'Incognito browsing';

  @override
  String get perkViewedMe => 'See who viewed you';

  @override
  String get perkFavorites => 'Unlimited favorites';

  @override
  String get plusSafetyFree => 'Safety tools are free for everyone, always.';

  @override
  String get planMonthly => '1 month';

  @override
  String get planYearly => '12 months';

  @override
  String get planBestValue => 'Best value';

  @override
  String get planPriceTbd => 'Price shown at checkout';

  @override
  String get plusSubscribe => 'Subscribe';

  @override
  String get plusDemoNote => 'Demo build: no payment is taken.';

  @override
  String get plusActive => 'You have Orbit+';

  @override
  String get plusCancel => 'Cancel Orbit+ (demo)';

  @override
  String get plusWelcome => 'Welcome to Orbit+';

  @override
  String get photosTitle => 'Photos';

  @override
  String get photosHint =>
      'Up to 6 public photos. Explicit photos belong in a private album.';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoAdd => 'Add photo';

  @override
  String get openMyPhotos => 'Open my photos';

  @override
  String get addStatusTooltip => 'Add a status';

  @override
  String get statusAdd => 'New status';

  @override
  String get statusPosting => 'Posting your status';

  @override
  String get statusMine => 'My status';

  @override
  String get statusCaptionHint => 'Add a caption';

  @override
  String get statusPost => 'Post';

  @override
  String get statusLimitReached =>
      'You can have 10 statuses at once. Delete one to post another.';

  @override
  String get statusRingNew => 'has a new status';

  @override
  String get statusRingSeen => 'has a status';

  @override
  String statusViewOf(String name) {
    return 'View $name\'s status';
  }

  @override
  String statusAgo(String unit, int count) {
    String _temp0 = intl.Intl.selectLogic(
      unit,
      {
        'now': 'Just now',
        'minutes': '${count}m ago',
        'other': '${count}h ago',
      },
    );
    return '$_temp0';
  }

  @override
  String statusSegment(int current, int total) {
    return 'Status $current of $total';
  }

  @override
  String get statusYours => 'Your status';

  @override
  String get statusViewedBy => 'Viewed by';

  @override
  String statusViews(int count) {
    return '👁 $count';
  }

  @override
  String get statusNoViewers => 'No one has viewed this status yet.';

  @override
  String get statusDelete => 'Delete status';

  @override
  String get statusDeleteConfirm =>
      'Delete this status? It disappears for everyone and can\'t be brought back.';

  @override
  String get statusReport => 'Report status';

  @override
  String get photoMain => 'Main';

  @override
  String get photoMakeMain => 'Make main photo';

  @override
  String get photoReplace => 'Replace photo';

  @override
  String get photoDelete => 'Delete photo';

  @override
  String get photoDeleteConfirm => 'Delete this photo?';

  @override
  String get photoDeleteLastWarning =>
      'This is your only photo. Without one, your profile won\'t show a picture.';

  @override
  String photoTileMain(int current, int total) {
    return 'Photo $current of $total, main photo';
  }

  @override
  String get photoReorderHint =>
      'Tap to open. Press and hold, then drag to reorder.';

  @override
  String get uploadFailed => 'That file couldn\'t be used. Try another one.';

  @override
  String get cameraOption => 'Take a photo';

  @override
  String get viewOnceOption => 'View-once photo';

  @override
  String get attachTooltip => 'Attach';

  @override
  String get photosOption => 'Photos (up to 10)';

  @override
  String photoTileLabel(int current, int total) {
    return 'Photo $current of $total';
  }

  @override
  String get voiceTooltip => 'Record a voice note';

  @override
  String get voiceStopTooltip => 'Stop and send';

  @override
  String get voiceCancelTooltip => 'Discard recording';

  @override
  String get recording => 'Recording…';

  @override
  String get microphoneDenied =>
      'Microphone access is off. Turn it on in Settings to send voice notes.';

  @override
  String get photoMessage => 'Photo';

  @override
  String get videoMessage => 'Video';

  @override
  String get voiceMessage => 'Voice note';

  @override
  String voiceDuration(int seconds) {
    return 'Voice note, $seconds seconds';
  }

  @override
  String get viewOnceClosed => 'View-once photo · Tap to open';

  @override
  String get viewOnceSent => 'View-once photo';

  @override
  String get viewOnceOpened => 'Opened';

  @override
  String get mediaUnavailable => 'Not available';

  @override
  String get uploading => 'Uploading…';

  @override
  String get playTooltip => 'Play';

  @override
  String get pauseTooltip => 'Pause';

  @override
  String get closeTooltip => 'Close';

  @override
  String get newAlbum => 'New album';

  @override
  String get albumNameLabel => 'Album name';

  @override
  String get create => 'Create';

  @override
  String get albumEmpty => 'No photos yet';

  @override
  String get sharedWithYou => 'Shared with you';

  @override
  String get openAlbum => 'Open album';

  @override
  String get albumGone => 'This album isn\'t available anymore.';

  @override
  String get restrictedTitle => 'Account unavailable';

  @override
  String get suspendedHeading => 'Your account is suspended';

  @override
  String get bannedHeading => 'Your account is banned';

  @override
  String suspendedUntil(String date) {
    return 'You can use Orbit again after $date.';
  }

  @override
  String restrictedBecause(String policy) {
    return 'Reason: $policy.';
  }

  @override
  String get messageFromSafetyTeam => 'Message from the Orbit safety team';

  @override
  String get appealHeading => 'Appeal';

  @override
  String get appealIntro =>
      'If you think this is a mistake, tell us why. You can appeal once, and a person on the safety team will review it.';

  @override
  String get appealLabel => 'Why should we look again?';

  @override
  String get sendAppeal => 'Send appeal';

  @override
  String get appealPending =>
      'Your appeal is with the safety team. We\'ll update this screen when it\'s been reviewed.';

  @override
  String get appealUpheld =>
      'Your appeal was reviewed, and the decision stands.';

  @override
  String get appealReversed =>
      'Your appeal was accepted. Tap Check again to continue.';

  @override
  String get checkAgain => 'Check again';

  @override
  String get stillRestricted => 'Your account is still unavailable.';

  @override
  String get warningTitle => 'A warning from Orbit';

  @override
  String warningBecause(String policy) {
    return 'Something you did went against our guidelines: $policy.';
  }

  @override
  String get warningFooter =>
      'Repeated problems can lead to a suspension or ban.';

  @override
  String get warningAcknowledge => 'I understand';

  @override
  String get policyFakeProfile => 'a fake or misleading profile';

  @override
  String get policyHarassment => 'harassment';

  @override
  String get policyUnderage => 'being under 18';

  @override
  String get policyExplicitPhoto => 'an explicit public photo';

  @override
  String get policyThreat => 'threats or violence';

  @override
  String get policySpam => 'spam or scams';

  @override
  String get policyOther => 'breaking our community guidelines';
}
