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
/// import 'i18n/app_localizations.dart';
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

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'CryptoPilot'**
  String get productName;

  /// No description provided for @productTagline.
  ///
  /// In en, this message translates to:
  /// **'Crypto Trading Support System'**
  String get productTagline;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @msg01.
  ///
  /// In en, this message translates to:
  /// **'The {field} field is required.'**
  String msg01(String field);

  /// No description provided for @msg02.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get msg02;

  /// No description provided for @msg03.
  ///
  /// In en, this message translates to:
  /// **'Password must be 8-64 characters and include uppercase, lowercase letters and a digit.'**
  String get msg03;

  /// No description provided for @msg07.
  ///
  /// In en, this message translates to:
  /// **'This link is invalid or has expired.'**
  String get msg07;

  /// No description provided for @msg08.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password. Please check again.'**
  String get msg08;

  /// No description provided for @msg09.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again after {minutes} minutes.'**
  String msg09(String minutes);

  /// No description provided for @msg10.
  ///
  /// In en, this message translates to:
  /// **'Your account has been {status}. Please contact support.'**
  String msg10(String status);

  /// No description provided for @msg11.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email before logging in. Resend verification email?'**
  String get msg11;

  /// No description provided for @msg12.
  ///
  /// In en, this message translates to:
  /// **'If the email is registered, a reset link has been sent.'**
  String get msg12;

  /// No description provided for @msg13.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. Please log in again.'**
  String get msg13;

  /// No description provided for @msg14.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully.'**
  String get msg14;

  /// No description provided for @msg15.
  ///
  /// In en, this message translates to:
  /// **'{field} must be between {min} and {max}.'**
  String msg15(String field, String min, String max);

  /// No description provided for @msg41.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get msg41;

  /// No description provided for @msg42.
  ///
  /// In en, this message translates to:
  /// **'Information on CryptoPilot is for reference and education only and is not investment advice.'**
  String get msg42;

  /// No description provided for @msg43.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again. (Ref: {code})'**
  String msg43(String code);

  /// No description provided for @msg44.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get msg44;

  /// No description provided for @msg50.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again in {seconds} seconds.'**
  String msg50(String seconds);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorUnknownReference.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get errorUnknownReference;

  /// No description provided for @statusLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get statusLocked;

  /// No description provided for @statusBanned.
  ///
  /// In en, this message translates to:
  /// **'banned'**
  String get statusBanned;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmailLabel;

  /// No description provided for @authEmailField.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get authEmailField;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordField.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get authPasswordField;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPasswordLabel;

  /// No description provided for @authNewPasswordField.
  ///
  /// In en, this message translates to:
  /// **'new password'**
  String get authNewPasswordField;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPasswordField.
  ///
  /// In en, this message translates to:
  /// **'confirm password'**
  String get authConfirmPasswordField;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in for 30 days'**
  String get authRememberMe;

  /// No description provided for @authForgotLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotLink;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Sign in to continue to your workspace.'**
  String get authLoginSubtitle;

  /// No description provided for @authLoginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginSubmit;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New to CryptoPilot?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create a free account'**
  String get authCreateAccountLink;

  /// No description provided for @authCreateAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Accounts are created on the CryptoPilot website.'**
  String get authCreateAccountHint;

  /// No description provided for @authResendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get authResendVerification;

  /// No description provided for @authResendSent.
  ///
  /// In en, this message translates to:
  /// **'If the address is registered and unverified, a new link is on its way.'**
  String get authResendSent;

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authResendIn(int seconds);

  /// No description provided for @authRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Password requirements'**
  String get authRulesTitle;

  /// No description provided for @authRuleLength.
  ///
  /// In en, this message translates to:
  /// **'8–64 characters'**
  String get authRuleLength;

  /// No description provided for @authRuleLowercase.
  ///
  /// In en, this message translates to:
  /// **'A lowercase letter'**
  String get authRuleLowercase;

  /// No description provided for @authRuleUppercase.
  ///
  /// In en, this message translates to:
  /// **'An uppercase letter'**
  String get authRuleUppercase;

  /// No description provided for @authRuleDigit.
  ///
  /// In en, this message translates to:
  /// **'A digit'**
  String get authRuleDigit;

  /// No description provided for @authPasswordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get authPasswordsDiffer;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get authForgotTitle;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email of your account and we will send you a reset link.'**
  String get authForgotSubtitle;

  /// No description provided for @authForgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authForgotSubmit;

  /// No description provided for @authForgotSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authForgotSentTitle;

  /// No description provided for @authForgotSentBody.
  ///
  /// In en, this message translates to:
  /// **'Open the link in the email to choose a new password. It is valid for 30 minutes.'**
  String get authForgotSentBody;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get authResetSubtitle;

  /// No description provided for @authResetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get authResetSubmit;

  /// No description provided for @authRequestNewLink.
  ///
  /// In en, this message translates to:
  /// **'Request a new link'**
  String get authRequestNewLink;

  /// No description provided for @authSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get authSessionExpiredTitle;

  /// No description provided for @splashUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach CryptoPilot'**
  String get splashUnavailableTitle;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'The administration console is on the web'**
  String get adminTitle;

  /// No description provided for @adminBody.
  ///
  /// In en, this message translates to:
  /// **'This app is for Traders. Open the console in your browser to manage CryptoPilot.'**
  String get adminBody;

  /// No description provided for @adminOpenConsole.
  ///
  /// In en, this message translates to:
  /// **'Open the web console'**
  String get adminOpenConsole;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get navMarkets;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @navPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get navPlans;

  /// No description provided for @navJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get navJournal;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @tabComingTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming in the next build'**
  String get tabComingTitle;

  /// No description provided for @tabComingBody.
  ///
  /// In en, this message translates to:
  /// **'This tab is being built. Use the CryptoPilot website meanwhile.'**
  String get tabComingBody;

  /// No description provided for @openOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Open on the web'**
  String get openOnWeb;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'In-app notifications are always on.'**
  String get accountNotificationsHint;

  /// No description provided for @accountNotifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountNotifyEmail;

  /// No description provided for @accountNotifyPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get accountNotifyPush;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accountOnWeb.
  ///
  /// In en, this message translates to:
  /// **'On the website'**
  String get accountOnWeb;

  /// No description provided for @accountProfileLink.
  ///
  /// In en, this message translates to:
  /// **'Profile and security'**
  String get accountProfileLink;

  /// No description provided for @accountSubscriptionLink.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get accountSubscriptionLink;

  /// No description provided for @accountAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get accountAbout;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of CryptoPilot on this device?'**
  String get accountSignOutConfirm;

  /// No description provided for @marketLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get marketLive;

  /// No description provided for @marketDelayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get marketDelayed;

  /// No description provided for @marketWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get marketWatchlist;

  /// No description provided for @marketSpot.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get marketSpot;

  /// No description provided for @marketFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get marketFutures;

  /// No description provided for @marketSearch.
  ///
  /// In en, this message translates to:
  /// **'Search pair or coin'**
  String get marketSearch;

  /// No description provided for @marketSortVolume.
  ///
  /// In en, this message translates to:
  /// **'Pair / Vol'**
  String get marketSortVolume;

  /// No description provided for @marketSortPrice.
  ///
  /// In en, this message translates to:
  /// **'Last price'**
  String get marketSortPrice;

  /// No description provided for @marketSortChange.
  ///
  /// In en, this message translates to:
  /// **'24h chg'**
  String get marketSortChange;

  /// No description provided for @marketPerpetual.
  ///
  /// In en, this message translates to:
  /// **'Perp'**
  String get marketPerpetual;

  /// No description provided for @marketVolumeShort.
  ///
  /// In en, this message translates to:
  /// **'Vol {value}'**
  String marketVolumeShort(String value);

  /// No description provided for @marketFundingShort.
  ///
  /// In en, this message translates to:
  /// **'Funding {rate}'**
  String marketFundingShort(String rate);

  /// No description provided for @marketHigh24h.
  ///
  /// In en, this message translates to:
  /// **'24h high'**
  String get marketHigh24h;

  /// No description provided for @marketLow24h.
  ///
  /// In en, this message translates to:
  /// **'24h low'**
  String get marketLow24h;

  /// No description provided for @marketVolume24h.
  ///
  /// In en, this message translates to:
  /// **'24h volume ({asset})'**
  String marketVolume24h(String asset);

  /// No description provided for @marketTurnover24h.
  ///
  /// In en, this message translates to:
  /// **'24h turnover ({asset})'**
  String marketTurnover24h(String asset);

  /// No description provided for @marketBestBid.
  ///
  /// In en, this message translates to:
  /// **'Best bid'**
  String get marketBestBid;

  /// No description provided for @marketBestAsk.
  ///
  /// In en, this message translates to:
  /// **'Best ask'**
  String get marketBestAsk;

  /// No description provided for @marketMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Mark price'**
  String get marketMarkPrice;

  /// No description provided for @marketIndexPrice.
  ///
  /// In en, this message translates to:
  /// **'Index price'**
  String get marketIndexPrice;

  /// No description provided for @marketFundingRate.
  ///
  /// In en, this message translates to:
  /// **'Funding rate'**
  String get marketFundingRate;

  /// No description provided for @marketNextFunding.
  ///
  /// In en, this message translates to:
  /// **'Next funding in'**
  String get marketNextFunding;

  /// No description provided for @marketAnalysisNext.
  ///
  /// In en, this message translates to:
  /// **'Charts, indicators and the setup score arrive in the next build.'**
  String get marketAnalysisNext;

  /// No description provided for @msg25.
  ///
  /// In en, this message translates to:
  /// **'{pair} added to watchlist.'**
  String msg25(String pair);

  /// No description provided for @msg26.
  ///
  /// In en, this message translates to:
  /// **'Removing {pair} will also delete {n} alerts. Continue?'**
  String msg26(String pair, String n);

  /// No description provided for @msg27.
  ///
  /// In en, this message translates to:
  /// **'You have reached the limit of {max} {items} of the {plan} plan. Upgrade to increase the limit?'**
  String msg27(String max, String items, String plan);

  /// No description provided for @msg29.
  ///
  /// In en, this message translates to:
  /// **'This feature is available on the {plan} plan or higher. View plans?'**
  String msg29(String plan);

  /// No description provided for @msg45.
  ///
  /// In en, this message translates to:
  /// **'{pair} is already in your watchlist.'**
  String msg45(String pair);

  /// No description provided for @watchCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {limit} pairs'**
  String watchCount(int count, int limit);

  /// No description provided for @watchCountNoLimit.
  ///
  /// In en, this message translates to:
  /// **'{count} pairs'**
  String watchCountNoLimit(int count);

  /// No description provided for @watchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No pairs watched yet'**
  String get watchEmptyTitle;

  /// No description provided for @watchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add pairs to follow their price, setup score and alerts.'**
  String get watchEmptyBody;

  /// No description provided for @watchAddPair.
  ///
  /// In en, this message translates to:
  /// **'Add pair'**
  String get watchAddPair;

  /// No description provided for @watchAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get watchAdded;

  /// No description provided for @watchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get watchAdd;

  /// No description provided for @watchUnlabelled.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get watchUnlabelled;

  /// No description provided for @watchScore.
  ///
  /// In en, this message translates to:
  /// **'Score {score}'**
  String watchScore(String score);

  /// No description provided for @watchScoreInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Score: insufficient data'**
  String get watchScoreInsufficient;

  /// No description provided for @watchAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No alerts} =1{1 alert} other{{count} alerts}}'**
  String watchAlerts(int count);

  /// No description provided for @watchUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Not available now'**
  String get watchUnlisted;

  /// No description provided for @watchEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit label and note'**
  String get watchEdit;

  /// No description provided for @watchRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get watchRemove;

  /// No description provided for @watchLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get watchLabel;

  /// No description provided for @watchNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get watchNote;

  /// No description provided for @watchSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get watchSave;

  /// No description provided for @watchSearchPairs.
  ///
  /// In en, this message translates to:
  /// **'Search pair or coin'**
  String get watchSearchPairs;

  /// No description provided for @upgradeOnWeb.
  ///
  /// In en, this message translates to:
  /// **'View plans on the web'**
  String get upgradeOnWeb;

  /// No description provided for @watchAddToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to watchlist'**
  String get watchAddToWatchlist;

  /// No description provided for @watchWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get watchWatching;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsNew.
  ///
  /// In en, this message translates to:
  /// **'New alert'**
  String get alertsNew;

  /// No description provided for @alertCreate.
  ///
  /// In en, this message translates to:
  /// **'Create alert'**
  String get alertCreate;

  /// No description provided for @alertEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit alert'**
  String get alertEdit;

  /// No description provided for @alertsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get alertsAll;

  /// No description provided for @alertStatusACTIVE.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get alertStatusACTIVE;

  /// No description provided for @alertStatusPAUSED.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get alertStatusPAUSED;

  /// No description provided for @alertStatusTRIGGERED.
  ///
  /// In en, this message translates to:
  /// **'Triggered'**
  String get alertStatusTRIGGERED;

  /// No description provided for @alertStatusEXPIRED.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get alertStatusEXPIRED;

  /// No description provided for @alertTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get alertTypeAll;

  /// No description provided for @alertTypePRICE.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get alertTypePRICE;

  /// No description provided for @alertTypeINDICATOR.
  ///
  /// In en, this message translates to:
  /// **'Indicator'**
  String get alertTypeINDICATOR;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet.'**
  String get alertsEmpty;

  /// No description provided for @alertsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create one from a pair in Markets, or here.'**
  String get alertsEmptyBody;

  /// No description provided for @alertsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No alerts match these filters.'**
  String get alertsEmptyFiltered;

  /// No description provided for @alertTriggerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Never triggered} =1{Triggered once} other{Triggered {count}×}}'**
  String alertTriggerCount(int count);

  /// No description provided for @alertLastTriggered.
  ///
  /// In en, this message translates to:
  /// **'last {time}'**
  String alertLastTriggered(String time);

  /// No description provided for @alertExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String alertExpires(String date);

  /// No description provided for @alertNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get alertNoExpiry;

  /// No description provided for @alertPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get alertPause;

  /// No description provided for @alertResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get alertResume;

  /// No description provided for @alertDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get alertDelete;

  /// No description provided for @alertDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete alert'**
  String get alertDeleteTitle;

  /// No description provided for @alertDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {condition} alert on {pair}? This cannot be undone.'**
  String alertDeleteConfirm(String condition, String pair);

  /// No description provided for @alertDeleted.
  ///
  /// In en, this message translates to:
  /// **'Alert deleted.'**
  String get alertDeleted;

  /// No description provided for @alertPaused.
  ///
  /// In en, this message translates to:
  /// **'Alert paused.'**
  String get alertPaused;

  /// No description provided for @alertResumed.
  ///
  /// In en, this message translates to:
  /// **'Alert resumed.'**
  String get alertResumed;

  /// No description provided for @alertResumeExpired.
  ///
  /// In en, this message translates to:
  /// **'This alert has expired. Edit it to set a new expiry.'**
  String get alertResumeExpired;

  /// No description provided for @alertIndicatorRSI_14.
  ///
  /// In en, this message translates to:
  /// **'RSI (14)'**
  String get alertIndicatorRSI_14;

  /// No description provided for @alertIndicatorMACD_CROSS.
  ///
  /// In en, this message translates to:
  /// **'MACD cross'**
  String get alertIndicatorMACD_CROSS;

  /// No description provided for @alertIndicatorEMA_CROSS.
  ///
  /// In en, this message translates to:
  /// **'EMA 20 / EMA 50 cross'**
  String get alertIndicatorEMA_CROSS;

  /// No description provided for @alertIndicatorFUNDING_RATE.
  ///
  /// In en, this message translates to:
  /// **'Funding rate'**
  String get alertIndicatorFUNDING_RATE;

  /// No description provided for @alertIndicatorOPEN_INTEREST_CHANGE.
  ///
  /// In en, this message translates to:
  /// **'Open interest change (1h)'**
  String get alertIndicatorOPEN_INTEREST_CHANGE;

  /// No description provided for @alertConditionCROSS_ABOVE.
  ///
  /// In en, this message translates to:
  /// **'Crosses above'**
  String get alertConditionCROSS_ABOVE;

  /// No description provided for @alertConditionCROSS_BELOW.
  ///
  /// In en, this message translates to:
  /// **'Crosses below'**
  String get alertConditionCROSS_BELOW;

  /// No description provided for @alertConditionGREATER_THAN.
  ///
  /// In en, this message translates to:
  /// **'Greater than'**
  String get alertConditionGREATER_THAN;

  /// No description provided for @alertConditionLESS_THAN.
  ///
  /// In en, this message translates to:
  /// **'Less than'**
  String get alertConditionLESS_THAN;

  /// No description provided for @alertCrossMACD_ABOVE.
  ///
  /// In en, this message translates to:
  /// **'MACD crosses above signal'**
  String get alertCrossMACD_ABOVE;

  /// No description provided for @alertCrossMACD_BELOW.
  ///
  /// In en, this message translates to:
  /// **'MACD crosses below signal'**
  String get alertCrossMACD_BELOW;

  /// No description provided for @alertCrossEMA_ABOVE.
  ///
  /// In en, this message translates to:
  /// **'EMA 20 crosses above EMA 50'**
  String get alertCrossEMA_ABOVE;

  /// No description provided for @alertCrossEMA_BELOW.
  ///
  /// In en, this message translates to:
  /// **'EMA 20 crosses below EMA 50'**
  String get alertCrossEMA_BELOW;

  /// No description provided for @alertModeONCE.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get alertModeONCE;

  /// No description provided for @alertModeONCE_PER_BAR.
  ///
  /// In en, this message translates to:
  /// **'Once per bar'**
  String get alertModeONCE_PER_BAR;

  /// No description provided for @alertModeEVERY_TIME.
  ///
  /// In en, this message translates to:
  /// **'Every time'**
  String get alertModeEVERY_TIME;

  /// No description provided for @alertModeHint.
  ///
  /// In en, this message translates to:
  /// **'Once stops after the first trigger; once per bar triggers at most once per candle (1h for price); every time waits for the cooldown.'**
  String get alertModeHint;

  /// No description provided for @alertPairField.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get alertPairField;

  /// No description provided for @alertPairSearch.
  ///
  /// In en, this message translates to:
  /// **'Search pair or coin'**
  String get alertPairSearch;

  /// No description provided for @alertAddsToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'This pair is added to your watchlist with the alert.'**
  String get alertAddsToWatchlist;

  /// No description provided for @alertMarketField.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get alertMarketField;

  /// No description provided for @alertTypeField.
  ///
  /// In en, this message translates to:
  /// **'Alert type'**
  String get alertTypeField;

  /// No description provided for @alertIndicatorField.
  ///
  /// In en, this message translates to:
  /// **'Indicator'**
  String get alertIndicatorField;

  /// No description provided for @alertTimeframeField.
  ///
  /// In en, this message translates to:
  /// **'Timeframe'**
  String get alertTimeframeField;

  /// No description provided for @alertConditionField.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get alertConditionField;

  /// No description provided for @alertPriceField.
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get alertPriceField;

  /// No description provided for @alertPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Rounded to the pair’s tick size.'**
  String get alertPriceHint;

  /// No description provided for @alertRsiField.
  ///
  /// In en, this message translates to:
  /// **'RSI level'**
  String get alertRsiField;

  /// No description provided for @alertPercentField.
  ///
  /// In en, this message translates to:
  /// **'Change over 1 hour (%)'**
  String get alertPercentField;

  /// No description provided for @alertFundingField.
  ///
  /// In en, this message translates to:
  /// **'Funding rate (%)'**
  String get alertFundingField;

  /// No description provided for @alertLastPrice.
  ///
  /// In en, this message translates to:
  /// **'Last {price}'**
  String alertLastPrice(String price);

  /// No description provided for @alertMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Mark {price}'**
  String alertMarkPrice(String price);

  /// No description provided for @alertTriggerField.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get alertTriggerField;

  /// No description provided for @alertCooldownField.
  ///
  /// In en, this message translates to:
  /// **'Cooldown (minutes)'**
  String get alertCooldownField;

  /// No description provided for @alertChannelsField.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get alertChannelsField;

  /// No description provided for @alertInApp.
  ///
  /// In en, this message translates to:
  /// **'In-app (always on)'**
  String get alertInApp;

  /// No description provided for @alertEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get alertEmail;

  /// No description provided for @alertPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get alertPush;

  /// No description provided for @alertExpiryField.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get alertExpiryField;

  /// No description provided for @alertExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String alertExpiryDays(int days);

  /// No description provided for @alertExpiryKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get alertExpiryKeep;

  /// No description provided for @alertSave.
  ///
  /// In en, this message translates to:
  /// **'Save alert'**
  String get alertSave;

  /// No description provided for @alertNotListed.
  ///
  /// In en, this message translates to:
  /// **'This pair is not listed on the selected market.'**
  String get alertNotListed;

  /// No description provided for @alertFuturesOnly.
  ///
  /// In en, this message translates to:
  /// **'Funding rate and open interest alerts are on Futures only.'**
  String get alertFuturesOnly;

  /// No description provided for @alertErrPositive.
  ///
  /// In en, this message translates to:
  /// **'{field} must be greater than 0.'**
  String alertErrPositive(String field);

  /// No description provided for @alertErrCooldown.
  ///
  /// In en, this message translates to:
  /// **'{field} must be at least 1 minute.'**
  String alertErrCooldown(String field);

  /// No description provided for @alertErrExpiry.
  ///
  /// In en, this message translates to:
  /// **'The expiry must be in the future and within 90 days.'**
  String get alertErrExpiry;

  /// No description provided for @alertErrNumber.
  ///
  /// In en, this message translates to:
  /// **'{field} must be a number.'**
  String alertErrNumber(String field);

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsAll;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAll;

  /// No description provided for @notificationsAllRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read.'**
  String get notificationsAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsEmptyUnread.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get notificationsEmptyUnread;

  /// No description provided for @notificationsView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get notificationsView;

  /// No description provided for @notificationsUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread notification} other{{count} unread notifications}}'**
  String notificationsUnreadCount(int count);

  /// No description provided for @notificationAgeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get notificationAgeNow;

  /// No description provided for @notificationAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String notificationAgeMinutes(int n);

  /// No description provided for @notificationAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String notificationAgeHours(int n);

  /// No description provided for @notificationAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String notificationAgeDays(int n);

  /// No description provided for @homeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search pairs'**
  String get homeSearch;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get homeWatchlist;

  /// No description provided for @homeWatchlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pairs watched yet.'**
  String get homeWatchlistEmpty;

  /// No description provided for @homePlans.
  ///
  /// In en, this message translates to:
  /// **'Plans and positions'**
  String get homePlans;

  /// No description provided for @homePlansActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homePlansActive;

  /// No description provided for @homePlansActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String homePlansActiveCount(int count);

  /// No description provided for @homePlansExecuted.
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get homePlansExecuted;

  /// No description provided for @homeOpenPositions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No open positions} =1{1 open position} other{{count} open positions}}'**
  String homeOpenPositions(int count);

  /// No description provided for @homeOpenPositionsMore.
  ///
  /// In en, this message translates to:
  /// **'{count}+ open positions'**
  String homeOpenPositionsMore(int count);

  /// No description provided for @homePlansEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active plans.'**
  String get homePlansEmptyActive;

  /// No description provided for @homePlansEmptyExecuted.
  ///
  /// In en, this message translates to:
  /// **'No executed plans.'**
  String get homePlansEmptyExecuted;

  /// No description provided for @homeCreatePlanWeb.
  ///
  /// In en, this message translates to:
  /// **'Create a plan on the web'**
  String get homeCreatePlanWeb;

  /// No description provided for @homePlanLevels.
  ///
  /// In en, this message translates to:
  /// **'Entry {entry} · SL {stop} · TP {target}'**
  String homePlanLevels(String entry, String stop, String target);

  /// No description provided for @homeDirectionLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get homeDirectionLong;

  /// No description provided for @homeDirectionShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get homeDirectionShort;

  /// No description provided for @homePositionOpen.
  ///
  /// In en, this message translates to:
  /// **'Position open'**
  String get homePositionOpen;

  /// No description provided for @homePositionClosed.
  ///
  /// In en, this message translates to:
  /// **'Position closed'**
  String get homePositionClosed;

  /// No description provided for @planStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get planStatusDraft;

  /// No description provided for @planStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planStatusActive;

  /// No description provided for @planStatusExecuted.
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get planStatusExecuted;

  /// No description provided for @planStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get planStatusCancelled;

  /// No description provided for @planStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get planStatusExpired;

  /// No description provided for @planStatusInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Invalidated'**
  String get planStatusInvalidated;

  /// No description provided for @homePerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get homePerformance;

  /// No description provided for @homePerformanceTrades.
  ///
  /// In en, this message translates to:
  /// **'Trades'**
  String get homePerformanceTrades;

  /// No description provided for @homePerformanceWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get homePerformanceWinRate;

  /// No description provided for @homePerformanceNetPnl.
  ///
  /// In en, this message translates to:
  /// **'Net P/L (USDT)'**
  String get homePerformanceNetPnl;

  /// No description provided for @homePerformanceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No closed trades yet.'**
  String get homePerformanceEmpty;

  /// No description provided for @homePerformanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Performance is not available yet.'**
  String get homePerformanceUnavailable;

  /// No description provided for @homeNews.
  ///
  /// In en, this message translates to:
  /// **'Latest news'**
  String get homeNews;

  /// No description provided for @homeNewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No news in the last 7 days.'**
  String get homeNewsEmpty;

  /// No description provided for @newsBullish.
  ///
  /// In en, this message translates to:
  /// **'Bullish'**
  String get newsBullish;

  /// No description provided for @newsNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get newsNeutral;

  /// No description provided for @newsBearish.
  ///
  /// In en, this message translates to:
  /// **'Bearish'**
  String get newsBearish;
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
