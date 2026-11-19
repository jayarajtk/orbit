import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'orbit'**
  String get appName;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Meet people nearby.'**
  String get welcomeHeadline;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Fast. Private. No ads — ever.'**
  String get welcomeTagline;

  /// No description provided for @welcomePrivacyPromise.
  ///
  /// In en, this message translates to:
  /// **'Your exact location is never stored — only a rounded area.'**
  String get welcomePrivacyPromise;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeAgeNotice.
  ///
  /// In en, this message translates to:
  /// **'18+ only'**
  String get welcomeAgeNotice;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Orbit'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick any. You can link more later.'**
  String get signInSubtitle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInWithApple;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone number'**
  String get signInWithPhone;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t complete. Please try again.'**
  String get signInFailed;

  /// No description provided for @signInNoPosting.
  ///
  /// In en, this message translates to:
  /// **'We never post anything or show Orbit on your other accounts.'**
  String get signInNoPosting;

  /// No description provided for @ageGateTitle.
  ///
  /// In en, this message translates to:
  /// **'When\'s your birthday?'**
  String get ageGateTitle;

  /// No description provided for @ageGateBody.
  ///
  /// In en, this message translates to:
  /// **'You must be 18 or older. Your birthday stays private; only your age can be shown, and you can hide it.'**
  String get ageGateBody;

  /// No description provided for @ageGatePick.
  ///
  /// In en, this message translates to:
  /// **'Choose your birthday'**
  String get ageGatePick;

  /// No description provided for @ageGateChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get ageGateChange;

  /// No description provided for @ageGateUnderage.
  ///
  /// In en, this message translates to:
  /// **'Sorry — Orbit is only for people 18 and over.'**
  String get ageGateUnderage;

  /// No description provided for @ageGateHelp.
  ///
  /// In en, this message translates to:
  /// **'Your birthday'**
  String get ageGateHelp;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Make your profile'**
  String get profileSetupTitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'What should people call you?'**
  String get displayNameHint;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name'**
  String get displayNameRequired;

  /// No description provided for @lookingForLabel.
  ///
  /// In en, this message translates to:
  /// **'Looking for'**
  String get lookingForLabel;

  /// No description provided for @photoLaterNote.
  ///
  /// In en, this message translates to:
  /// **'You can add photos from your profile once you\'re in.'**
  String get photoLaterNote;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'See who\'s nearby'**
  String get locationTitle;

  /// No description provided for @locationPointWhileUsing.
  ///
  /// In en, this message translates to:
  /// **'Only while you\'re using the app'**
  String get locationPointWhileUsing;

  /// No description provided for @locationPointRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded to your area — never your exact spot'**
  String get locationPointRounded;

  /// No description provided for @locationPointHide.
  ///
  /// In en, this message translates to:
  /// **'Hide your distance any time in Settings'**
  String get locationPointHide;

  /// No description provided for @locationAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow while using'**
  String get locationAllow;

  /// No description provided for @locationNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get locationNotNow;

  /// No description provided for @lookingForChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get lookingForChat;

  /// No description provided for @lookingForDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get lookingForDates;

  /// No description provided for @lookingForFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get lookingForFriends;

  /// No description provided for @lookingForNetworking.
  ///
  /// In en, this message translates to:
  /// **'Networking'**
  String get lookingForNetworking;

  /// No description provided for @lookingForRightNow.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get lookingForRightNow;

  /// No description provided for @relationshipSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get relationshipSingle;

  /// No description provided for @relationshipDating.
  ///
  /// In en, this message translates to:
  /// **'Dating'**
  String get relationshipDating;

  /// No description provided for @relationshipPartnered.
  ///
  /// In en, this message translates to:
  /// **'Partnered'**
  String get relationshipPartnered;

  /// No description provided for @relationshipOpen.
  ///
  /// In en, this message translates to:
  /// **'Open relationship'**
  String get relationshipOpen;

  /// No description provided for @tabNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get tabNearby;

  /// No description provided for @tabInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get tabInbox;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @onlineFilter.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineFilter;

  /// No description provided for @filtersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTooltip;

  /// No description provided for @freshFaces.
  ///
  /// In en, this message translates to:
  /// **'Fresh faces'**
  String get freshFaces;

  /// No description provided for @distanceUnder1Km.
  ///
  /// In en, this message translates to:
  /// **'<1 km'**
  String get distanceUnder1Km;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(int km);

  /// No description provided for @distanceHidden.
  ///
  /// In en, this message translates to:
  /// **'Distance hidden'**
  String get distanceHidden;

  /// No description provided for @distanceTenPlus.
  ///
  /// In en, this message translates to:
  /// **'10+ km'**
  String get distanceTenPlus;

  /// No description provided for @nameAge.
  ///
  /// In en, this message translates to:
  /// **'{name}, {age}'**
  String nameAge(String name, int age);

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'{cm} cm'**
  String heightCm(int cm);

  /// No description provided for @onlineNow.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineNow;

  /// No description provided for @locationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Share your location to see who\'s nearby.'**
  String get locationNeeded;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get shareLocation;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is off for Orbit. Turn it on in Settings to see who\'s nearby.'**
  String get locationDenied;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one nearby yet — try widening your filters.'**
  String get nearbyEmpty;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load profiles.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Orbit. Check your connection and try again.'**
  String get actionFailed;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This profile isn\'t available.'**
  String get profileUnavailable;

  /// No description provided for @waveButton.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get waveButton;

  /// No description provided for @messageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageButton;

  /// No description provided for @waveAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Wave again in {time}'**
  String waveAgainIn(String time);

  /// No description provided for @waveLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve waved twice today. Try again in {time}.'**
  String waveLimitReached(String time);

  /// No description provided for @waveSent.
  ///
  /// In en, this message translates to:
  /// **'You waved at {name}'**
  String waveSent(String name);

  /// No description provided for @favoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More: block or report'**
  String get moreActions;

  /// No description provided for @photoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo {current} of {total}'**
  String photoOf(int current, int total);

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @filtersReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filtersReset;

  /// No description provided for @filtersAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get filtersAge;

  /// No description provided for @filtersAgeRange.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String filtersAgeRange(int min, int max);

  /// No description provided for @filtersOnlineNow.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get filtersOnlineNow;

  /// No description provided for @filtersHasPhoto.
  ///
  /// In en, this message translates to:
  /// **'Has photo'**
  String get filtersHasPhoto;

  /// No description provided for @filtersMaxDistance.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance'**
  String get filtersMaxDistance;

  /// No description provided for @filtersAnyDistance.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filtersAnyDistance;

  /// No description provided for @filtersPlusLocked.
  ///
  /// In en, this message translates to:
  /// **'Distance and more filters'**
  String get filtersPlusLocked;

  /// No description provided for @filtersShowResults.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get filtersShowResults;

  /// No description provided for @orbitPlus.
  ///
  /// In en, this message translates to:
  /// **'Orbit+'**
  String get orbitPlus;

  /// No description provided for @blockName.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockName(String name);

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see each other anywhere in Orbit. They won\'t be told.'**
  String get blockConfirmBody;

  /// No description provided for @blockAction.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockAction;

  /// No description provided for @blockedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked'**
  String blockedSnack(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report — choose a reason'**
  String get reportTitle;

  /// No description provided for @reportModeratorNote.
  ///
  /// In en, this message translates to:
  /// **'Reports go to a human moderator. {name} won\'t be told.'**
  String reportModeratorNote(String name);

  /// No description provided for @reportFake.
  ///
  /// In en, this message translates to:
  /// **'Fake profile or spam'**
  String get reportFake;

  /// No description provided for @reportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get reportHarassment;

  /// No description provided for @reportUnderage.
  ///
  /// In en, this message translates to:
  /// **'May be under 18'**
  String get reportUnderage;

  /// No description provided for @reportPhotos.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate photos'**
  String get reportPhotos;

  /// No description provided for @reportThreat.
  ///
  /// In en, this message translates to:
  /// **'Threat or danger'**
  String get reportThreat;

  /// No description provided for @reportAlsoBlock.
  ///
  /// In en, this message translates to:
  /// **'Also block {name}'**
  String reportAlsoBlock(String name);

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. A moderator will review your report.'**
  String get reportSent;

  /// No description provided for @inboxAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inboxAll;

  /// No description provided for @inboxUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxUnread;

  /// No description provided for @inboxFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get inboxFavorites;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Say hi to someone nearby.'**
  String get inboxEmpty;

  /// No description provided for @inboxUnreadEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get inboxUnreadEmpty;

  /// No description provided for @inboxFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chats with favorites yet.'**
  String get inboxFavoritesEmpty;

  /// No description provided for @conversationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Chat with {name} deleted'**
  String conversationDeleted(String name);

  /// No description provided for @previewYou.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String previewYou(String text);

  /// No description provided for @previewWaveIn.
  ///
  /// In en, this message translates to:
  /// **'Waved at you'**
  String get previewWaveIn;

  /// No description provided for @previewWaveOut.
  ///
  /// In en, this message translates to:
  /// **'You waved'**
  String get previewWaveOut;

  /// No description provided for @previewLocation.
  ///
  /// In en, this message translates to:
  /// **'Shared a live location'**
  String get previewLocation;

  /// No description provided for @previewAlbum.
  ///
  /// In en, this message translates to:
  /// **'Shared an album'**
  String get previewAlbum;

  /// No description provided for @previewUnsent.
  ///
  /// In en, this message translates to:
  /// **'Message unsent'**
  String get previewUnsent;

  /// No description provided for @mutedLabel.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get mutedLabel;

  /// No description provided for @unknownMember.
  ///
  /// In en, this message translates to:
  /// **'Orbit member'**
  String get unknownMember;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get messageHint;

  /// No description provided for @messageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageLabel;

  /// No description provided for @sendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTooltip;

  /// No description provided for @albumTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share an album'**
  String get albumTooltip;

  /// No description provided for @locationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share live location'**
  String get locationTooltip;

  /// No description provided for @quickPhrasesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quick phrases'**
  String get quickPhrasesTooltip;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String typing(String name);

  /// No description provided for @tickSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get tickSent;

  /// No description provided for @tickDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get tickDelivered;

  /// No description provided for @tickRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get tickRead;

  /// No description provided for @dayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// No description provided for @typingStatus.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typingStatus;

  /// No description provided for @statusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get statusSending;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent · Tap to retry'**
  String get statusFailed;

  /// No description provided for @waveIn.
  ///
  /// In en, this message translates to:
  /// **'{name} waved at you'**
  String waveIn(String name);

  /// No description provided for @waveOut.
  ///
  /// In en, this message translates to:
  /// **'You waved'**
  String get waveOut;

  /// No description provided for @waveInCount.
  ///
  /// In en, this message translates to:
  /// **'{name} waved ×{count}'**
  String waveInCount(String name, int count);

  /// No description provided for @waveOutCount.
  ///
  /// In en, this message translates to:
  /// **'You waved ×{count}'**
  String waveOutCount(int count);

  /// No description provided for @locationCard.
  ///
  /// In en, this message translates to:
  /// **'Live location · {minutes} min'**
  String locationCard(int minutes);

  /// No description provided for @albumCardOut.
  ///
  /// In en, this message translates to:
  /// **'You shared “{album}”'**
  String albumCardOut(String album);

  /// No description provided for @albumCardIn.
  ///
  /// In en, this message translates to:
  /// **'{name} shared “{album}”'**
  String albumCardIn(String name, String album);

  /// No description provided for @unsentMessage.
  ///
  /// In en, this message translates to:
  /// **'This message was unsent'**
  String get unsentMessage;

  /// No description provided for @unsendAction.
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get unsendAction;

  /// No description provided for @unsendPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Unsend 1 photo} other{Unsend {count} photos}}'**
  String unsendPhotos(int count);

  /// No description provided for @unsendSomePhotos.
  ///
  /// In en, this message translates to:
  /// **'Unsend {count} of {total} photos ({skipped, plural, =1{1 is} other{{skipped} are}} past 10 minutes)'**
  String unsendSomePhotos(int count, int total, int skipped);

  /// No description provided for @unsendExpired.
  ///
  /// In en, this message translates to:
  /// **'Messages can only be unsent within 10 minutes.'**
  String get unsendExpired;

  /// No description provided for @shareLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Share live location for'**
  String get shareLocationTitle;

  /// No description provided for @minutesOption.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesOption(int minutes);

  /// No description provided for @hourOption.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get hourOption;

  /// No description provided for @chatViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get chatViewProfile;

  /// No description provided for @chatMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatMute;

  /// No description provided for @chatUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatUnmute;

  /// No description provided for @chatBlockReport.
  ///
  /// In en, this message translates to:
  /// **'Block or report'**
  String get chatBlockReport;

  /// No description provided for @chatMenu.
  ///
  /// In en, this message translates to:
  /// **'Chat options'**
  String get chatMenu;

  /// No description provided for @phraseHi.
  ///
  /// In en, this message translates to:
  /// **'Hey! How\'s your day going?'**
  String get phraseHi;

  /// No description provided for @phraseCoffee.
  ///
  /// In en, this message translates to:
  /// **'Fancy a coffee sometime?'**
  String get phraseCoffee;

  /// No description provided for @phraseWhat.
  ///
  /// In en, this message translates to:
  /// **'What brings you to Orbit?'**
  String get phraseWhat;

  /// No description provided for @phraseLater.
  ///
  /// In en, this message translates to:
  /// **'Can\'t chat right now — talk later?'**
  String get phraseLater;

  /// No description provided for @shareAlbumTitle.
  ///
  /// In en, this message translates to:
  /// **'Share an album with {name}'**
  String shareAlbumTitle(String name);

  /// No description provided for @shareAlbumEmpty.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any albums yet. Create one to share it.'**
  String get shareAlbumEmpty;

  /// No description provided for @createAlbum.
  ///
  /// In en, this message translates to:
  /// **'Create album'**
  String get createAlbum;

  /// No description provided for @albumPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String albumPhotos(int count);

  /// No description provided for @albumPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get albumPrivate;

  /// No description provided for @accessLasts.
  ///
  /// In en, this message translates to:
  /// **'Access lasts'**
  String get accessLasts;

  /// No description provided for @access24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get access24h;

  /// No description provided for @access7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get access7d;

  /// No description provided for @accessUntilRevoked.
  ///
  /// In en, this message translates to:
  /// **'Until I revoke'**
  String get accessUntilRevoked;

  /// No description provided for @viewOnce.
  ///
  /// In en, this message translates to:
  /// **'View-once photos'**
  String get viewOnce;

  /// No description provided for @screenshotNote.
  ///
  /// In en, this message translates to:
  /// **'Screenshots are blocked on Android and flagged to you on iOS.'**
  String get screenshotNote;

  /// No description provided for @sharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with {name}'**
  String sharedWith(String name);

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @shareAlbumButton.
  ///
  /// In en, this message translates to:
  /// **'Share album'**
  String get shareAlbumButton;

  /// No description provided for @albumShared.
  ///
  /// In en, this message translates to:
  /// **'Album shared with {name}'**
  String albumShared(String name);

  /// No description provided for @myAlbumsTitle.
  ///
  /// In en, this message translates to:
  /// **'My albums'**
  String get myAlbumsTitle;

  /// No description provided for @albumNotShared.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone'**
  String get albumNotShared;

  /// No description provided for @albumSharedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Shared with 1 person} other{Shared with {count} people}}'**
  String albumSharedCount(int count);

  /// No description provided for @meTitle.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get meTitle;

  /// No description provided for @profileComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile {percent}% complete'**
  String profileComplete(int percent);

  /// No description provided for @menuEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get menuEditProfile;

  /// No description provided for @menuAlbums.
  ///
  /// In en, this message translates to:
  /// **'My albums'**
  String get menuAlbums;

  /// No description provided for @menuFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get menuFavorites;

  /// No description provided for @menuPlus.
  ///
  /// In en, this message translates to:
  /// **'Orbit+'**
  String get menuPlus;

  /// No description provided for @menuSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety centre'**
  String get menuSafety;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings & privacy'**
  String get menuSettings;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on a profile to add a favorite.'**
  String get favoritesEmpty;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @aboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get aboutLabel;

  /// No description provided for @aboutHint.
  ///
  /// In en, this message translates to:
  /// **'A line or two about you'**
  String get aboutHint;

  /// No description provided for @pronounsLabel.
  ///
  /// In en, this message translates to:
  /// **'Pronouns'**
  String get pronounsLabel;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightLabel;

  /// No description provided for @heightInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a height between 120 and 230 cm'**
  String get heightInvalid;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. hiking, music'**
  String get tagsHint;

  /// No description provided for @showOnProfile.
  ///
  /// In en, this message translates to:
  /// **'Show on profile'**
  String get showOnProfile;

  /// No description provided for @showAge.
  ///
  /// In en, this message translates to:
  /// **'Show my age'**
  String get showAge;

  /// No description provided for @showDistance.
  ///
  /// In en, this message translates to:
  /// **'Show my distance'**
  String get showDistance;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings & privacy'**
  String get settingsTitle;

  /// No description provided for @sectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get sectionPrivacy;

  /// No description provided for @sectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get sectionSecurity;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get sectionData;

  /// No description provided for @settingReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get settingReadReceipts;

  /// No description provided for @settingReadReceiptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, you also won\'t see when others read yours'**
  String get settingReadReceiptsSubtitle;

  /// No description provided for @settingPreviews.
  ///
  /// In en, this message translates to:
  /// **'Message text in notifications'**
  String get settingPreviews;

  /// No description provided for @settingIncognito.
  ///
  /// In en, this message translates to:
  /// **'Incognito'**
  String get settingIncognito;

  /// No description provided for @settingIncognitoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse without appearing in grids'**
  String get settingIncognitoSubtitle;

  /// No description provided for @settingDiscreetIcon.
  ///
  /// In en, this message translates to:
  /// **'Discreet app icon'**
  String get settingDiscreetIcon;

  /// No description provided for @settingDiscreetIconSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A neutral icon and name on your home screen'**
  String get settingDiscreetIconSubtitle;

  /// No description provided for @settingShake.
  ///
  /// In en, this message translates to:
  /// **'Shake to hide'**
  String get settingShake;

  /// No description provided for @settingAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock (Face ID / fingerprint)'**
  String get settingAppLock;

  /// No description provided for @settingBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get settingBlocked;

  /// No description provided for @settingExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingExport;

  /// No description provided for @exportStarted.
  ///
  /// In en, this message translates to:
  /// **'We\'re preparing your data. You\'ll get a download link within 30 days.'**
  String get exportStarted;

  /// No description provided for @settingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingDelete;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is hidden now and permanently deleted after 14 days. Sign back in within 14 days to cancel.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deleteRequested.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested. Sign in within 14 days to cancel.'**
  String get deleteRequested;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @blockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone.'**
  String get blockedEmpty;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @unblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is unblocked'**
  String unblocked(String name);

  /// No description provided for @safetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety centre'**
  String get safetyTitle;

  /// No description provided for @topicMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting someone new'**
  String get topicMeeting;

  /// No description provided for @topicMeetingSub.
  ///
  /// In en, this message translates to:
  /// **'Tips, and share live location with a trusted friend'**
  String get topicMeetingSub;

  /// No description provided for @topicMeetingBody.
  ///
  /// In en, this message translates to:
  /// **'Meet somewhere public the first time, and get there on your own.\n\nTell a friend where you\'re going. You can share your live location from any chat for up to an hour.\n\nKeep the conversation in Orbit until you trust someone. Be wary of anyone who rushes you or asks for money.\n\nTrust your gut. It\'s always okay to leave.'**
  String get topicMeetingBody;

  /// No description provided for @topicTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel safety'**
  String get topicTravel;

  /// No description provided for @topicTravelSub.
  ///
  /// In en, this message translates to:
  /// **'Safer defaults where being queer is risky'**
  String get topicTravelSub;

  /// No description provided for @topicTravelBody.
  ///
  /// In en, this message translates to:
  /// **'In some countries, same-sex relationships are criminalised. When you travel there, Orbit hides your distance by default and shows a safety notice.\n\nConsider turning on the discreet app icon and app lock before you go.\n\nBe cautious with anyone who asks to meet very quickly or pushes to move the chat elsewhere.'**
  String get topicTravelBody;

  /// No description provided for @topicHealth.
  ///
  /// In en, this message translates to:
  /// **'Sexual health'**
  String get topicHealth;

  /// No description provided for @topicHealthSub.
  ///
  /// In en, this message translates to:
  /// **'Testing reminders and local services'**
  String get topicHealthSub;

  /// No description provided for @topicHealthBody.
  ///
  /// In en, this message translates to:
  /// **'Regular testing is part of looking after yourself and your partners. Many people test every three months.\n\nAsk a local clinic about PrEP, PEP and vaccinations.\n\nHealth details on your profile are always optional and private by default.'**
  String get topicHealthBody;

  /// No description provided for @topicModeration.
  ///
  /// In en, this message translates to:
  /// **'Blocking & reporting'**
  String get topicModeration;

  /// No description provided for @topicModerationSub.
  ///
  /// In en, this message translates to:
  /// **'How moderation works and what happens next'**
  String get topicModerationSub;

  /// No description provided for @topicModerationBody.
  ///
  /// In en, this message translates to:
  /// **'Blocking is instant and two-way: neither of you will see the other anywhere in Orbit. The other person is never told.\n\nReports go to a human moderator. Reports about minors and threats are reviewed first.\n\nWe may warn, suspend or ban accounts. Safety tools are free for everyone.'**
  String get topicModerationBody;

  /// No description provided for @getHelp.
  ///
  /// In en, this message translates to:
  /// **'Get help now'**
  String get getHelp;

  /// No description provided for @getHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'If you\'re in danger'**
  String get getHelpTitle;

  /// No description provided for @getHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Call your local emergency number now. When you\'re safe, block and report the person so our team can act.'**
  String get getHelpBody;

  /// No description provided for @plusIntro.
  ///
  /// In en, this message translates to:
  /// **'Orbit is always ad-free. Orbit+ adds:'**
  String get plusIntro;

  /// No description provided for @perkMoreProfiles.
  ///
  /// In en, this message translates to:
  /// **'More profiles in your grid'**
  String get perkMoreProfiles;

  /// No description provided for @perkFilters.
  ///
  /// In en, this message translates to:
  /// **'Distance and advanced filters'**
  String get perkFilters;

  /// No description provided for @perkIncognito.
  ///
  /// In en, this message translates to:
  /// **'Incognito browsing'**
  String get perkIncognito;

  /// No description provided for @perkViewedMe.
  ///
  /// In en, this message translates to:
  /// **'See who viewed you'**
  String get perkViewedMe;

  /// No description provided for @perkFavorites.
  ///
  /// In en, this message translates to:
  /// **'Unlimited favorites'**
  String get perkFavorites;

  /// No description provided for @plusSafetyFree.
  ///
  /// In en, this message translates to:
  /// **'Safety tools are free for everyone, always.'**
  String get plusSafetyFree;

  /// No description provided for @planMonthly.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get planMonthly;

  /// No description provided for @planYearly.
  ///
  /// In en, this message translates to:
  /// **'12 months'**
  String get planYearly;

  /// No description provided for @planBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get planBestValue;

  /// No description provided for @planPriceTbd.
  ///
  /// In en, this message translates to:
  /// **'Price shown at checkout'**
  String get planPriceTbd;

  /// No description provided for @plusSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get plusSubscribe;

  /// No description provided for @plusDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Demo build: no payment is taken.'**
  String get plusDemoNote;

  /// No description provided for @plusActive.
  ///
  /// In en, this message translates to:
  /// **'You have Orbit+'**
  String get plusActive;

  /// No description provided for @plusCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Orbit+ (demo)'**
  String get plusCancel;

  /// No description provided for @plusWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Orbit+'**
  String get plusWelcome;

  /// No description provided for @photosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosTitle;

  /// No description provided for @photosHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 6 public photos. Explicit photos belong in a private album.'**
  String get photosHint;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photoAdd;

  /// No description provided for @openMyPhotos.
  ///
  /// In en, this message translates to:
  /// **'Open my photos'**
  String get openMyPhotos;

  /// No description provided for @addStatusTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a status'**
  String get addStatusTooltip;

  /// No description provided for @statusAdd.
  ///
  /// In en, this message translates to:
  /// **'New status'**
  String get statusAdd;

  /// No description provided for @statusPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting your status'**
  String get statusPosting;

  /// No description provided for @statusMine.
  ///
  /// In en, this message translates to:
  /// **'My status'**
  String get statusMine;

  /// No description provided for @statusCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get statusCaptionHint;

  /// No description provided for @statusPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get statusPost;

  /// No description provided for @statusLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can have 10 statuses at once. Delete one to post another.'**
  String get statusLimitReached;

  /// No description provided for @statusRingNew.
  ///
  /// In en, this message translates to:
  /// **'has a new status'**
  String get statusRingNew;

  /// No description provided for @statusRingSeen.
  ///
  /// In en, this message translates to:
  /// **'has a status'**
  String get statusRingSeen;

  /// No description provided for @statusViewOf.
  ///
  /// In en, this message translates to:
  /// **'View {name}\'s status'**
  String statusViewOf(String name);

  /// No description provided for @statusAgo.
  ///
  /// In en, this message translates to:
  /// **'{unit, select, now{Just now} minutes{{count}m ago} other{{count}h ago}}'**
  String statusAgo(String unit, int count);

  /// No description provided for @statusSegment.
  ///
  /// In en, this message translates to:
  /// **'Status {current} of {total}'**
  String statusSegment(int current, int total);

  /// No description provided for @statusYours.
  ///
  /// In en, this message translates to:
  /// **'Your status'**
  String get statusYours;

  /// No description provided for @statusViewedBy.
  ///
  /// In en, this message translates to:
  /// **'Viewed by'**
  String get statusViewedBy;

  /// No description provided for @statusViews.
  ///
  /// In en, this message translates to:
  /// **'👁 {count}'**
  String statusViews(int count);

  /// No description provided for @statusNoViewers.
  ///
  /// In en, this message translates to:
  /// **'No one has viewed this status yet.'**
  String get statusNoViewers;

  /// No description provided for @statusDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete status'**
  String get statusDelete;

  /// No description provided for @statusDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this status? It disappears for everyone and can\'t be brought back.'**
  String get statusDeleteConfirm;

  /// No description provided for @statusReport.
  ///
  /// In en, this message translates to:
  /// **'Report status'**
  String get statusReport;

  /// No description provided for @photoMain.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get photoMain;

  /// No description provided for @photoMakeMain.
  ///
  /// In en, this message translates to:
  /// **'Make main photo'**
  String get photoMakeMain;

  /// No description provided for @photoReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get photoReplace;

  /// No description provided for @photoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get photoDelete;

  /// No description provided for @photoDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get photoDeleteConfirm;

  /// No description provided for @photoDeleteLastWarning.
  ///
  /// In en, this message translates to:
  /// **'This is your only photo. Without one, your profile won\'t show a picture.'**
  String get photoDeleteLastWarning;

  /// No description provided for @photoTileMain.
  ///
  /// In en, this message translates to:
  /// **'Photo {current} of {total}, main photo'**
  String photoTileMain(int current, int total);

  /// No description provided for @photoReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to open. Press and hold, then drag to reorder.'**
  String get photoReorderHint;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'That file couldn\'t be used. Try another one.'**
  String get uploadFailed;

  /// No description provided for @cameraOption.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get cameraOption;

  /// No description provided for @viewOnceOption.
  ///
  /// In en, this message translates to:
  /// **'View-once photo'**
  String get viewOnceOption;

  /// No description provided for @videoOption.
  ///
  /// In en, this message translates to:
  /// **'Video (up to 60 seconds)'**
  String get videoOption;

  /// No description provided for @attachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachTooltip;

  /// No description provided for @photosOption.
  ///
  /// In en, this message translates to:
  /// **'Photos (up to 10)'**
  String get photosOption;

  /// No description provided for @photoTileLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo {current} of {total}'**
  String photoTileLabel(int current, int total);

  /// No description provided for @voiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voiceTooltip;

  /// No description provided for @voiceStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop and send'**
  String get voiceStopTooltip;

  /// No description provided for @voiceCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard recording'**
  String get voiceCancelTooltip;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recording;

  /// No description provided for @microphoneDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Turn it on in Settings to send voice notes.'**
  String get microphoneDenied;

  /// No description provided for @photoMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoMessage;

  /// No description provided for @videoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceMessage;

  /// No description provided for @voiceDuration.
  ///
  /// In en, this message translates to:
  /// **'Voice note, {seconds} seconds'**
  String voiceDuration(int seconds);

  /// No description provided for @viewOnceClosed.
  ///
  /// In en, this message translates to:
  /// **'View-once photo · Tap to open'**
  String get viewOnceClosed;

  /// No description provided for @viewOnceSent.
  ///
  /// In en, this message translates to:
  /// **'View-once photo'**
  String get viewOnceSent;

  /// No description provided for @viewOnceOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get viewOnceOpened;

  /// No description provided for @mediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get mediaUnavailable;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @playTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playTooltip;

  /// No description provided for @pauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseTooltip;

  /// No description provided for @closeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeTooltip;

  /// No description provided for @newAlbum.
  ///
  /// In en, this message translates to:
  /// **'New album'**
  String get newAlbum;

  /// No description provided for @albumNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Album name'**
  String get albumNameLabel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @albumEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get albumEmpty;

  /// No description provided for @sharedWithYou.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get sharedWithYou;

  /// No description provided for @openAlbum.
  ///
  /// In en, this message translates to:
  /// **'Open album'**
  String get openAlbum;

  /// No description provided for @albumGone.
  ///
  /// In en, this message translates to:
  /// **'This album isn\'t available anymore.'**
  String get albumGone;

  /// No description provided for @restrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account unavailable'**
  String get restrictedTitle;

  /// No description provided for @suspendedHeading.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended'**
  String get suspendedHeading;

  /// No description provided for @bannedHeading.
  ///
  /// In en, this message translates to:
  /// **'Your account is banned'**
  String get bannedHeading;

  /// No description provided for @suspendedUntil.
  ///
  /// In en, this message translates to:
  /// **'You can use Orbit again after {date}.'**
  String suspendedUntil(String date);

  /// No description provided for @restrictedBecause.
  ///
  /// In en, this message translates to:
  /// **'Reason: {policy}.'**
  String restrictedBecause(String policy);

  /// No description provided for @messageFromSafetyTeam.
  ///
  /// In en, this message translates to:
  /// **'Message from the Orbit safety team'**
  String get messageFromSafetyTeam;

  /// No description provided for @appealHeading.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get appealHeading;

  /// No description provided for @appealIntro.
  ///
  /// In en, this message translates to:
  /// **'If you think this is a mistake, tell us why. You can appeal once, and a person on the safety team will review it.'**
  String get appealIntro;

  /// No description provided for @appealLabel.
  ///
  /// In en, this message translates to:
  /// **'Why should we look again?'**
  String get appealLabel;

  /// No description provided for @sendAppeal.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get sendAppeal;

  /// No description provided for @appealPending.
  ///
  /// In en, this message translates to:
  /// **'Your appeal is with the safety team. We\'ll update this screen when it\'s been reviewed.'**
  String get appealPending;

  /// No description provided for @appealUpheld.
  ///
  /// In en, this message translates to:
  /// **'Your appeal was reviewed, and the decision stands.'**
  String get appealUpheld;

  /// No description provided for @appealReversed.
  ///
  /// In en, this message translates to:
  /// **'Your appeal was accepted. Tap Check again to continue.'**
  String get appealReversed;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @stillRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your account is still unavailable.'**
  String get stillRestricted;

  /// No description provided for @warningTitle.
  ///
  /// In en, this message translates to:
  /// **'A warning from Orbit'**
  String get warningTitle;

  /// No description provided for @warningBecause.
  ///
  /// In en, this message translates to:
  /// **'Something you did went against our guidelines: {policy}.'**
  String warningBecause(String policy);

  /// No description provided for @warningFooter.
  ///
  /// In en, this message translates to:
  /// **'Repeated problems can lead to a suspension or ban.'**
  String get warningFooter;

  /// No description provided for @warningAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get warningAcknowledge;

  /// No description provided for @policyFakeProfile.
  ///
  /// In en, this message translates to:
  /// **'a fake or misleading profile'**
  String get policyFakeProfile;

  /// No description provided for @policyHarassment.
  ///
  /// In en, this message translates to:
  /// **'harassment'**
  String get policyHarassment;

  /// No description provided for @policyUnderage.
  ///
  /// In en, this message translates to:
  /// **'being under 18'**
  String get policyUnderage;

  /// No description provided for @policyExplicitPhoto.
  ///
  /// In en, this message translates to:
  /// **'an explicit public photo'**
  String get policyExplicitPhoto;

  /// No description provided for @policyThreat.
  ///
  /// In en, this message translates to:
  /// **'threats or violence'**
  String get policyThreat;

  /// No description provided for @policySpam.
  ///
  /// In en, this message translates to:
  /// **'spam or scams'**
  String get policySpam;

  /// No description provided for @policyOther.
  ///
  /// In en, this message translates to:
  /// **'breaking our community guidelines'**
  String get policyOther;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
