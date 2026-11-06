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
