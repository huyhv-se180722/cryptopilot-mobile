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

  /// No description provided for @msg32.
  ///
  /// In en, this message translates to:
  /// **'File type or size is not supported (maximum {size}).'**
  String msg32(String size);

  /// No description provided for @msg33.
  ///
  /// In en, this message translates to:
  /// **'Your post has been published.'**
  String get msg33;

  /// No description provided for @msg34.
  ///
  /// In en, this message translates to:
  /// **'Thank you, your report has been submitted.'**
  String get msg34;

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

  /// No description provided for @accountDemoTrading.
  ///
  /// In en, this message translates to:
  /// **'Demo trading'**
  String get accountDemoTrading;

  /// No description provided for @accountLearnShare.
  ///
  /// In en, this message translates to:
  /// **'Learn and share'**
  String get accountLearnShare;

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

  /// No description provided for @accountLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get accountLicences;

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

  /// No description provided for @marketCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get marketCoins;

  /// No description provided for @coinsHeadCoin.
  ///
  /// In en, this message translates to:
  /// **'Coin / Market cap'**
  String get coinsHeadCoin;

  /// No description provided for @coinsHead7d.
  ///
  /// In en, this message translates to:
  /// **'7d'**
  String get coinsHead7d;

  /// No description provided for @coinsHeadPrice.
  ///
  /// In en, this message translates to:
  /// **'Price / 24h'**
  String get coinsHeadPrice;

  /// No description provided for @coinsTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get coinsTop;

  /// No description provided for @coinsGainers.
  ///
  /// In en, this message translates to:
  /// **'Gainers'**
  String get coinsGainers;

  /// No description provided for @coinsLosers.
  ///
  /// In en, this message translates to:
  /// **'Losers'**
  String get coinsLosers;

  /// No description provided for @coinsCap.
  ///
  /// In en, this message translates to:
  /// **'Mkt cap {cap}'**
  String coinsCap(String cap);

  /// No description provided for @coins7d.
  ///
  /// In en, this message translates to:
  /// **'7d {change}'**
  String coins7d(String change);

  /// No description provided for @coinsChart.
  ///
  /// In en, this message translates to:
  /// **'{symbol} over the last 7 days'**
  String coinsChart(String symbol);

  /// No description provided for @coinsSource.
  ///
  /// In en, this message translates to:
  /// **'Prices: live tickers · Market cap and supply: CoinPaprika'**
  String get coinsSource;

  /// No description provided for @marketSearch.
  ///
  /// In en, this message translates to:
  /// **'Search pair or coin'**
  String get marketSearch;

  /// No description provided for @overviewMarketCap.
  ///
  /// In en, this message translates to:
  /// **'Market Cap'**
  String get overviewMarketCap;

  /// No description provided for @overviewVolume.
  ///
  /// In en, this message translates to:
  /// **'24h volume'**
  String get overviewVolume;

  /// No description provided for @overviewDominance.
  ///
  /// In en, this message translates to:
  /// **'BTC Dominance'**
  String get overviewDominance;

  /// No description provided for @overviewFearGreed.
  ///
  /// In en, this message translates to:
  /// **'Fear & Greed'**
  String get overviewFearGreed;

  /// No description provided for @overviewAltcoinSeason.
  ///
  /// In en, this message translates to:
  /// **'Altcoin Season'**
  String get overviewAltcoinSeason;

  /// No description provided for @overviewOpenInterest.
  ///
  /// In en, this message translates to:
  /// **'Open Interest'**
  String get overviewOpenInterest;

  /// No description provided for @overviewSeasonBitcoin.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get overviewSeasonBitcoin;

  /// No description provided for @overviewSeasonAltcoin.
  ///
  /// In en, this message translates to:
  /// **'Altcoin'**
  String get overviewSeasonAltcoin;

  /// No description provided for @overviewSeasonHint.
  ///
  /// In en, this message translates to:
  /// **'{count} listed altcoins against Bitcoin over {days} days; 75 or more is an altcoin season'**
  String overviewSeasonHint(int count, int days);

  /// No description provided for @overviewOpenInterestHint.
  ///
  /// In en, this message translates to:
  /// **'Listed Futures pairs together'**
  String get overviewOpenInterestHint;

  /// No description provided for @overviewSourcePaprika.
  ///
  /// In en, this message translates to:
  /// **'Market cap and volume: CoinPaprika'**
  String get overviewSourcePaprika;

  /// No description provided for @overviewSourceFearGreed.
  ///
  /// In en, this message translates to:
  /// **'Fear & Greed: alternative.me'**
  String get overviewSourceFearGreed;

  /// No description provided for @overviewFgExtremeFear.
  ///
  /// In en, this message translates to:
  /// **'Extreme fear'**
  String get overviewFgExtremeFear;

  /// No description provided for @overviewFgFear.
  ///
  /// In en, this message translates to:
  /// **'Fear'**
  String get overviewFgFear;

  /// No description provided for @overviewFgNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get overviewFgNeutral;

  /// No description provided for @overviewFgGreed.
  ///
  /// In en, this message translates to:
  /// **'Greed'**
  String get overviewFgGreed;

  /// No description provided for @overviewFgExtremeGreed.
  ///
  /// In en, this message translates to:
  /// **'Extreme greed'**
  String get overviewFgExtremeGreed;

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

  /// No description provided for @analysisPairGone.
  ///
  /// In en, this message translates to:
  /// **'This pair is no longer available.'**
  String get analysisPairGone;

  /// No description provided for @analysisDayRange.
  ///
  /// In en, this message translates to:
  /// **'H {high} · L {low} · Vol {volume}'**
  String analysisDayRange(String high, String low, String volume);

  /// No description provided for @chartTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Times in {zone}'**
  String chartTimeZone(String zone);

  /// No description provided for @analysisIndicators.
  ///
  /// In en, this message translates to:
  /// **'Indicators'**
  String get analysisIndicators;

  /// No description provided for @analysisOverlays.
  ///
  /// In en, this message translates to:
  /// **'Overlays'**
  String get analysisOverlays;

  /// No description provided for @analysisPanels.
  ///
  /// In en, this message translates to:
  /// **'Panels'**
  String get analysisPanels;

  /// No description provided for @indicatorSma20.
  ///
  /// In en, this message translates to:
  /// **'SMA 20'**
  String get indicatorSma20;

  /// No description provided for @indicatorEma20.
  ///
  /// In en, this message translates to:
  /// **'EMA 20'**
  String get indicatorEma20;

  /// No description provided for @indicatorEma50.
  ///
  /// In en, this message translates to:
  /// **'EMA 50'**
  String get indicatorEma50;

  /// No description provided for @indicatorEma200.
  ///
  /// In en, this message translates to:
  /// **'EMA 200'**
  String get indicatorEma200;

  /// No description provided for @indicatorBollinger.
  ///
  /// In en, this message translates to:
  /// **'Bollinger Bands (20, 2)'**
  String get indicatorBollinger;

  /// No description provided for @indicatorVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume with Volume SMA 20'**
  String get indicatorVolume;

  /// No description provided for @indicatorRsi.
  ///
  /// In en, this message translates to:
  /// **'RSI 14'**
  String get indicatorRsi;

  /// No description provided for @indicatorMacd.
  ///
  /// In en, this message translates to:
  /// **'MACD (12, 26, 9)'**
  String get indicatorMacd;

  /// No description provided for @analysisSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get analysisSupport;

  /// No description provided for @analysisResistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance'**
  String get analysisResistance;

  /// No description provided for @analysisInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient data'**
  String get analysisInsufficient;

  /// No description provided for @analysisInsufficientNotice.
  ///
  /// In en, this message translates to:
  /// **'Fewer than 200 closed candles: some indicators and the setup score cannot be computed yet.'**
  String get analysisInsufficientNotice;

  /// No description provided for @analysisScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup score'**
  String get analysisScoreTitle;

  /// No description provided for @analysisScoreOutOf.
  ///
  /// In en, this message translates to:
  /// **'/ 100'**
  String get analysisScoreOutOf;

  /// No description provided for @analysisScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Setup score {score} out of 100'**
  String analysisScoreLabel(String score);

  /// No description provided for @analysisPresetLine.
  ///
  /// In en, this message translates to:
  /// **'{preset} {version} · {timeframe}'**
  String analysisPresetLine(String preset, String version, String timeframe);

  /// No description provided for @presetScalping.
  ///
  /// In en, this message translates to:
  /// **'Scalping'**
  String get presetScalping;

  /// No description provided for @presetDayTrading.
  ///
  /// In en, this message translates to:
  /// **'Day trading'**
  String get presetDayTrading;

  /// No description provided for @presetSwing.
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get presetSwing;

  /// No description provided for @analysisScoreCapped.
  ///
  /// In en, this message translates to:
  /// **'Score capped: little room to the next level.'**
  String get analysisScoreCapped;

  /// No description provided for @analysisComponents.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get analysisComponents;

  /// No description provided for @componentTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get componentTrend;

  /// No description provided for @componentMomentum.
  ///
  /// In en, this message translates to:
  /// **'Momentum'**
  String get componentMomentum;

  /// No description provided for @componentVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get componentVolume;

  /// No description provided for @componentLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get componentLevel;

  /// No description provided for @componentDerivatives.
  ///
  /// In en, this message translates to:
  /// **'Derivatives'**
  String get componentDerivatives;

  /// No description provided for @analysisStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Market statistics'**
  String get analysisStatsTitle;

  /// No description provided for @statLastPrice.
  ///
  /// In en, this message translates to:
  /// **'Last price'**
  String get statLastPrice;

  /// No description provided for @statSpread.
  ///
  /// In en, this message translates to:
  /// **'Spread'**
  String get statSpread;

  /// No description provided for @statChange24h.
  ///
  /// In en, this message translates to:
  /// **'24h change'**
  String get statChange24h;

  /// No description provided for @analysisNewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest {coin} news'**
  String analysisNewsTitle(String coin);

  /// No description provided for @analysisNewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No {coin} news in the last 7 days.'**
  String analysisNewsEmpty(String coin);

  /// No description provided for @analysisCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get analysisCreatePlan;

  /// No description provided for @analysisCreatePlanHint.
  ///
  /// In en, this message translates to:
  /// **'Create trading plan on the web'**
  String get analysisCreatePlanHint;

  /// No description provided for @analysisScoredSide.
  ///
  /// In en, this message translates to:
  /// **'Scored side'**
  String get analysisScoredSide;

  /// No description provided for @analysisDominantSide.
  ///
  /// In en, this message translates to:
  /// **'Dominant side'**
  String get analysisDominantSide;

  /// No description provided for @sideLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get sideLong;

  /// No description provided for @sideShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get sideShort;

  /// No description provided for @sideNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get sideNeutral;

  /// No description provided for @analysisSidesNote.
  ///
  /// In en, this message translates to:
  /// **'Sides describe the score. They are not a trade recommendation.'**
  String get analysisSidesNote;

  /// No description provided for @metricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Futures data'**
  String get metricsTitle;

  /// No description provided for @metricOpenInterest.
  ///
  /// In en, this message translates to:
  /// **'Open interest'**
  String get metricOpenInterest;

  /// No description provided for @metricLongShort.
  ///
  /// In en, this message translates to:
  /// **'Long/short ratio'**
  String get metricLongShort;

  /// No description provided for @metricRange.
  ///
  /// In en, this message translates to:
  /// **'{days}D'**
  String metricRange(int days);

  /// No description provided for @metricOiContracts.
  ///
  /// In en, this message translates to:
  /// **'Open interest ({asset})'**
  String metricOiContracts(String asset);

  /// No description provided for @metricOiValue.
  ///
  /// In en, this message translates to:
  /// **'Open interest value ({asset})'**
  String metricOiValue(String asset);

  /// No description provided for @metricLsRatio.
  ///
  /// In en, this message translates to:
  /// **'Long/short account ratio'**
  String get metricLsRatio;

  /// No description provided for @metricLongAccounts.
  ///
  /// In en, this message translates to:
  /// **'Long accounts'**
  String get metricLongAccounts;

  /// No description provided for @metricShortAccounts.
  ///
  /// In en, this message translates to:
  /// **'Short accounts'**
  String get metricShortAccounts;

  /// No description provided for @metricsChartLabel.
  ///
  /// In en, this message translates to:
  /// **'{symbol} {metric}, last {days, plural, =1{day} other{{days} days}}'**
  String metricsChartLabel(String symbol, String metric, int days);

  /// No description provided for @metricsPartial.
  ///
  /// In en, this message translates to:
  /// **'Data is stored from {from} only, a shorter period than the one selected.'**
  String metricsPartial(String from);

  /// No description provided for @metricsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data stored for this period yet.'**
  String get metricsEmpty;

  /// No description provided for @metricsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Every 5 minutes · latest {time}'**
  String metricsUpdated(String time);

  /// No description provided for @alertShort.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alertShort;

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

  /// No description provided for @msg30.
  ///
  /// In en, this message translates to:
  /// **'You have used today\'s {quota} questions. Quota resets at 00:00.'**
  String msg30(String quota);

  /// No description provided for @msg31.
  ///
  /// In en, this message translates to:
  /// **'The AI Assistant is temporarily unavailable. Please try again.'**
  String get msg31;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiTitle;

  /// No description provided for @aiAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get aiAskAi;

  /// No description provided for @aiNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiNewConversation;

  /// No description provided for @aiUntitled.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiUntitled;

  /// No description provided for @aiFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get aiFilterAll;

  /// No description provided for @aiTopicMarket.
  ///
  /// In en, this message translates to:
  /// **'Market analysis'**
  String get aiTopicMarket;

  /// No description provided for @aiTopicMine.
  ///
  /// In en, this message translates to:
  /// **'My plan & performance'**
  String get aiTopicMine;

  /// No description provided for @aiTopicGeneral.
  ///
  /// In en, this message translates to:
  /// **'General question'**
  String get aiTopicGeneral;

  /// No description provided for @aiTopicMarketHint.
  ///
  /// In en, this message translates to:
  /// **'The assistant reads the current price, indicators and setup score of the coin you pick.'**
  String get aiTopicMarketHint;

  /// No description provided for @aiTopicMineHint.
  ///
  /// In en, this message translates to:
  /// **'The assistant reads your plan (with the state of its coin) and your trading statistics.'**
  String get aiTopicMineHint;

  /// No description provided for @aiTopicGeneralHint.
  ///
  /// In en, this message translates to:
  /// **'General question — the assistant reads no market data.'**
  String get aiTopicGeneralHint;

  /// No description provided for @aiChooseMode.
  ///
  /// In en, this message translates to:
  /// **'What shall we look at?'**
  String get aiChooseMode;

  /// No description provided for @aiNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get aiNoConversations;

  /// No description provided for @aiNoConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Start one and ask your first question.'**
  String get aiNoConversationsHint;

  /// No description provided for @aiGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get aiGroupToday;

  /// No description provided for @aiGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get aiGroupYesterday;

  /// No description provided for @aiGroupWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get aiGroupWeek;

  /// No description provided for @aiGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get aiGroupOlder;

  /// No description provided for @aiRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get aiRename;

  /// No description provided for @aiRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get aiRenameTitle;

  /// No description provided for @aiRenameLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get aiRenameLabel;

  /// No description provided for @aiSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get aiSave;

  /// No description provided for @aiDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get aiDelete;

  /// No description provided for @aiDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get aiDeleteTitle;

  /// No description provided for @aiDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears from your list. Questions already asked today still count toward your quota.'**
  String get aiDeleteBody;

  /// No description provided for @aiDeleted.
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted.'**
  String get aiDeleted;

  /// No description provided for @aiEmptyChat.
  ///
  /// In en, this message translates to:
  /// **'Ask a question to start.'**
  String get aiEmptyChat;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'The assistant is writing…'**
  String get aiThinking;

  /// No description provided for @aiTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get aiTryAgain;

  /// No description provided for @aiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiSend;

  /// No description provided for @aiCounter.
  ///
  /// In en, this message translates to:
  /// **'{count}/1000'**
  String aiCounter(int count);

  /// No description provided for @aiQuota.
  ///
  /// In en, this message translates to:
  /// **'{remaining}/{limit} today'**
  String aiQuota(int remaining, int limit);

  /// No description provided for @aiQuotaUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get aiQuotaUnlimited;

  /// No description provided for @aiUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'The AI assistant is on PRO and PREMIUM'**
  String get aiUpgradeTitle;

  /// No description provided for @aiUpgradeBody.
  ///
  /// In en, this message translates to:
  /// **'Your conversations stay readable. Upgrade to ask new questions.'**
  String get aiUpgradeBody;

  /// No description provided for @aiPickPair.
  ///
  /// In en, this message translates to:
  /// **'Pick a coin'**
  String get aiPickPair;

  /// No description provided for @aiSearchPairs.
  ///
  /// In en, this message translates to:
  /// **'Search pairs'**
  String get aiSearchPairs;

  /// No description provided for @aiTimeframe.
  ///
  /// In en, this message translates to:
  /// **'Timeframe'**
  String get aiTimeframe;

  /// No description provided for @aiPairChip.
  ///
  /// In en, this message translates to:
  /// **'{symbol} · {market} · {timeframe}'**
  String aiPairChip(String symbol, String market, String timeframe);

  /// No description provided for @aiPlan.
  ///
  /// In en, this message translates to:
  /// **'One of my plans'**
  String get aiPlan;

  /// No description provided for @aiNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No plan'**
  String get aiNoPlan;

  /// No description provided for @aiNoPlans.
  ///
  /// In en, this message translates to:
  /// **'You have no plan to ask about yet.'**
  String get aiNoPlans;

  /// No description provided for @aiPlanChip.
  ///
  /// In en, this message translates to:
  /// **'Plan {symbol} {direction}'**
  String aiPlanChip(String symbol, String direction);

  /// No description provided for @aiLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get aiLong;

  /// No description provided for @aiShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get aiShort;

  /// No description provided for @aiPerformance.
  ///
  /// In en, this message translates to:
  /// **'My trading performance'**
  String get aiPerformance;

  /// No description provided for @aiPerformanceLocked.
  ///
  /// In en, this message translates to:
  /// **'Trading performance: PREMIUM only'**
  String get aiPerformanceLocked;

  /// No description provided for @aiPairNeedsChoice.
  ///
  /// In en, this message translates to:
  /// **'Pick a coin for the assistant to analyse.'**
  String get aiPairNeedsChoice;

  /// No description provided for @aiMineNeedsChoice.
  ///
  /// In en, this message translates to:
  /// **'Pick a plan or tick the performance to ask.'**
  String get aiMineNeedsChoice;

  /// No description provided for @aiPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your email, name and capital are never sent.'**
  String get aiPrivacy;

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// No description provided for @communityTabLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get communityTabLatest;

  /// No description provided for @communityTabTrending.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get communityTabTrending;

  /// No description provided for @communityTabMostLiked.
  ///
  /// In en, this message translates to:
  /// **'Most liked'**
  String get communityTabMostLiked;

  /// No description provided for @communityTabSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get communityTabSaved;

  /// No description provided for @communityTabMine.
  ///
  /// In en, this message translates to:
  /// **'My posts'**
  String get communityTabMine;

  /// No description provided for @communityTabFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get communityTabFollowing;

  /// No description provided for @communityEmptyFollowing.
  ///
  /// In en, this message translates to:
  /// **'Posts of the members you follow appear here.'**
  String get communityEmptyFollowing;

  /// No description provided for @communityCoinAll.
  ///
  /// In en, this message translates to:
  /// **'All coins'**
  String get communityCoinAll;

  /// No description provided for @communityCoinPick.
  ///
  /// In en, this message translates to:
  /// **'Coin'**
  String get communityCoinPick;

  /// No description provided for @communityMarketAll.
  ///
  /// In en, this message translates to:
  /// **'All markets'**
  String get communityMarketAll;

  /// No description provided for @communitySearch.
  ///
  /// In en, this message translates to:
  /// **'Search titles and texts'**
  String get communitySearch;

  /// No description provided for @communitySearchShort.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters to search.'**
  String get communitySearchShort;

  /// No description provided for @communityClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get communityClearFilters;

  /// No description provided for @communityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get communityEmpty;

  /// No description provided for @communityEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No posts match these filters.'**
  String get communityEmptyFiltered;

  /// No description provided for @communityEmptySaved.
  ///
  /// In en, this message translates to:
  /// **'Posts you save appear here.'**
  String get communityEmptySaved;

  /// No description provided for @communityEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'You have not posted yet.'**
  String get communityEmptyMine;

  /// No description provided for @communityPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get communityPinned;

  /// No description provided for @communityOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get communityOfficial;

  /// No description provided for @communityEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get communityEdited;

  /// No description provided for @communityLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get communityLike;

  /// No description provided for @communityUnlike.
  ///
  /// In en, this message translates to:
  /// **'Remove like'**
  String get communityUnlike;

  /// No description provided for @communitySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get communitySave;

  /// No description provided for @communityUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get communityUnsave;

  /// No description provided for @communityComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get communityComments;

  /// No description provided for @communityCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'Comments ({n})'**
  String communityCommentsCount(int n);

  /// No description provided for @communityBullish.
  ///
  /// In en, this message translates to:
  /// **'Bullish'**
  String get communityBullish;

  /// No description provided for @communityBearish.
  ///
  /// In en, this message translates to:
  /// **'Bearish'**
  String get communityBearish;

  /// No description provided for @communityVoteBullish.
  ///
  /// In en, this message translates to:
  /// **'Vote bullish'**
  String get communityVoteBullish;

  /// No description provided for @communityVoteBearish.
  ///
  /// In en, this message translates to:
  /// **'Vote bearish'**
  String get communityVoteBearish;

  /// No description provided for @communityVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get communityVideo;

  /// No description provided for @communityWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch the video'**
  String get communityWatchVideo;

  /// No description provided for @communityOpenImage.
  ///
  /// In en, this message translates to:
  /// **'Open the image'**
  String get communityOpenImage;

  /// No description provided for @communityUnknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get communityUnknownAuthor;

  /// No description provided for @communityMenu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get communityMenu;

  /// No description provided for @communityReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get communityReport;

  /// No description provided for @communityDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get communityDelete;

  /// No description provided for @communityDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get communityDeleteTitle;

  /// No description provided for @communityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get communityDeleted;

  /// No description provided for @communityCommentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get communityCommentPlaceholder;

  /// No description provided for @communityReplyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get communityReplyPlaceholder;

  /// No description provided for @communitySend.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get communitySend;

  /// No description provided for @communitySendReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get communitySendReply;

  /// No description provided for @communityReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get communityReply;

  /// No description provided for @communityReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String communityReplyingTo(String name);

  /// No description provided for @communityCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get communityCancelReply;

  /// No description provided for @communityCommentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get communityCommentDeleted;

  /// No description provided for @communityCommentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get communityCommentDeleteTitle;

  /// No description provided for @communityCommentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'If it has replies, it stays in the thread as \"Comment deleted\".'**
  String get communityCommentDeleteBody;

  /// No description provided for @communityEditComment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get communityEditComment;

  /// No description provided for @communitySaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get communitySaveChanges;

  /// No description provided for @communityCommentTooLong.
  ///
  /// In en, this message translates to:
  /// **'A comment holds at most 2,000 characters.'**
  String get communityCommentTooLong;

  /// No description provided for @communityNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Start the discussion.'**
  String get communityNoComments;

  /// No description provided for @communityReportPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get communityReportPost;

  /// No description provided for @communityReportComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get communityReportComment;

  /// No description provided for @communityReportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get communityReportReason;

  /// No description provided for @communityReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get communityReasonSpam;

  /// No description provided for @communityReasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or fraud'**
  String get communityReasonScam;

  /// No description provided for @communityReasonAbuse.
  ///
  /// In en, this message translates to:
  /// **'Abuse or harassment'**
  String get communityReasonAbuse;

  /// No description provided for @communityReasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading information'**
  String get communityReasonMisleading;

  /// No description provided for @communityReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get communityReasonOther;

  /// No description provided for @communityReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get communityReportDetails;

  /// No description provided for @communityReportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Required for Other, up to 500 characters'**
  String get communityReportDetailsHint;

  /// No description provided for @communityReportDetailsRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem when you choose Other.'**
  String get communityReportDetailsRequired;

  /// No description provided for @communityReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get communityReportSubmit;

  /// No description provided for @communityAlreadyReportedPost.
  ///
  /// In en, this message translates to:
  /// **'You have already reported this post.'**
  String get communityAlreadyReportedPost;

  /// No description provided for @communityAlreadyReportedComment.
  ///
  /// In en, this message translates to:
  /// **'You have already reported this comment.'**
  String get communityAlreadyReportedComment;

  /// No description provided for @communityLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get communityLoadMore;

  /// No description provided for @composerNew.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get composerNew;

  /// No description provided for @composerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get composerEdit;

  /// No description provided for @composerPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get composerPublish;

  /// No description provided for @composerTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get composerTitle;

  /// No description provided for @composerTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Give your post a title (5 to 150 characters)'**
  String get composerTitleHint;

  /// No description provided for @composerContent.
  ///
  /// In en, this message translates to:
  /// **'What do you want to share?'**
  String get composerContent;

  /// No description provided for @composerCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins (up to 5)'**
  String get composerCoins;

  /// No description provided for @composerAddCoin.
  ///
  /// In en, this message translates to:
  /// **'Add a coin'**
  String get composerAddCoin;

  /// No description provided for @composerRemoveCoin.
  ///
  /// In en, this message translates to:
  /// **'Remove {coin}'**
  String composerRemoveCoin(String coin);

  /// No description provided for @composerMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get composerMarket;

  /// No description provided for @composerNoMarket.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get composerNoMarket;

  /// No description provided for @composerStance.
  ///
  /// In en, this message translates to:
  /// **'Your stance'**
  String get composerStance;

  /// No description provided for @composerNoStance.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get composerNoStance;

  /// No description provided for @composerMediaHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 4 images (JPG, PNG, WEBP) or 1 video (MP4, WEBM).'**
  String get composerMediaHint;

  /// No description provided for @composerAddImages.
  ///
  /// In en, this message translates to:
  /// **'Add images'**
  String get composerAddImages;

  /// No description provided for @composerAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add video'**
  String get composerAddVideo;

  /// No description provided for @composerUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String composerUploading(int percent);

  /// No description provided for @composerRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get composerRemove;

  /// No description provided for @composerFieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check this field.'**
  String get composerFieldInvalid;

  /// No description provided for @composerSaved.
  ///
  /// In en, this message translates to:
  /// **'Your changes are saved.'**
  String get composerSaved;

  /// No description provided for @memberFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get memberFollow;

  /// No description provided for @memberFollowingButton.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get memberFollowingButton;

  /// No description provided for @memberBlock.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String memberBlock(String name);

  /// No description provided for @memberUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get memberUnblock;

  /// No description provided for @memberBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String memberBlockTitle(String name);

  /// No description provided for @memberBlockBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see their posts and comments, and they will not see yours.'**
  String get memberBlockBody;

  /// No description provided for @memberBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked. You no longer see their posts and comments.'**
  String memberBlocked(String name);

  /// No description provided for @memberUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer blocked.'**
  String memberUnblocked(String name);

  /// No description provided for @memberJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String memberJoined(String date);

  /// No description provided for @memberPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get memberPosts;

  /// No description provided for @memberLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes received'**
  String get memberLikes;

  /// No description provided for @memberFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get memberFollowers;

  /// No description provided for @memberFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get memberFollowing;

  /// No description provided for @memberYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get memberYou;

  /// No description provided for @memberInfluence.
  ///
  /// In en, this message translates to:
  /// **'{score} Influence Score'**
  String memberInfluence(String score);

  /// No description provided for @memberDepth.
  ///
  /// In en, this message translates to:
  /// **'{score} Analytical Depth'**
  String memberDepth(String score);

  /// No description provided for @memberCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins they post about'**
  String get memberCoins;

  /// No description provided for @memberTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get memberTabPosts;

  /// No description provided for @memberTabComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get memberTabComments;

  /// No description provided for @memberTabReactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get memberTabReactions;

  /// No description provided for @memberEmptyPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get memberEmptyPosts;

  /// No description provided for @memberEmptyComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get memberEmptyComments;

  /// No description provided for @memberEmptyReactions.
  ///
  /// In en, this message translates to:
  /// **'No reactions yet.'**
  String get memberEmptyReactions;

  /// No description provided for @memberCommentedOn.
  ///
  /// In en, this message translates to:
  /// **'Commented on {title}'**
  String memberCommentedOn(String title);

  /// No description provided for @memberBlockedList.
  ///
  /// In en, this message translates to:
  /// **'Blocked members'**
  String get memberBlockedList;

  /// No description provided for @memberNoPeople.
  ///
  /// In en, this message translates to:
  /// **'No one here yet.'**
  String get memberNoPeople;

  /// No description provided for @memberMore.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get memberMore;

  /// No description provided for @memberMention.
  ///
  /// In en, this message translates to:
  /// **'Mention a member'**
  String get memberMention;

  /// No description provided for @memberMentionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get memberMentionSearch;

  /// No description provided for @memberMentionNone.
  ///
  /// In en, this message translates to:
  /// **'No member matches.'**
  String get memberMentionNone;

  /// No description provided for @communityLikesCount.
  ///
  /// In en, this message translates to:
  /// **'{n} likes'**
  String communityLikesCount(String n);

  /// No description provided for @communityCommentsShort.
  ///
  /// In en, this message translates to:
  /// **'{n} comments'**
  String communityCommentsShort(String n);

  /// No description provided for @aiStyleChip.
  ///
  /// In en, this message translates to:
  /// **'Style: {style} · {risk}'**
  String aiStyleChip(String style, String risk);

  /// No description provided for @aiStyleNotSet.
  ///
  /// In en, this message translates to:
  /// **'Set your trading style'**
  String get aiStyleNotSet;

  /// No description provided for @aiStyleHint.
  ///
  /// In en, this message translates to:
  /// **'The assistant explains things for the way you trade.'**
  String get aiStyleHint;

  /// No description provided for @aiStyleScalping.
  ///
  /// In en, this message translates to:
  /// **'Scalping'**
  String get aiStyleScalping;

  /// No description provided for @aiStyleDay.
  ///
  /// In en, this message translates to:
  /// **'Day trading'**
  String get aiStyleDay;

  /// No description provided for @aiStyleSwing.
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get aiStyleSwing;

  /// No description provided for @aiStylePosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get aiStylePosition;

  /// No description provided for @aiRiskConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative'**
  String get aiRiskConservative;

  /// No description provided for @aiRiskBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get aiRiskBalanced;

  /// No description provided for @aiRiskAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get aiRiskAggressive;

  /// No description provided for @aiPlaceholderGeneral.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about trading…'**
  String get aiPlaceholderGeneral;

  /// No description provided for @aiPlaceholderNoPair.
  ///
  /// In en, this message translates to:
  /// **'Ask about a coin…'**
  String get aiPlaceholderNoPair;

  /// No description provided for @aiPlaceholderPair.
  ///
  /// In en, this message translates to:
  /// **'Ask about {symbol}…'**
  String aiPlaceholderPair(String symbol);

  /// No description provided for @aiPlaceholderMine.
  ///
  /// In en, this message translates to:
  /// **'Ask about your plan or your trading performance…'**
  String get aiPlaceholderMine;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For reference only, not investment advice.'**
  String get aiDisclaimer;

  /// No description provided for @aiSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get aiSources;

  /// No description provided for @aiCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get aiCopy;

  /// No description provided for @aiCopied.
  ///
  /// In en, this message translates to:
  /// **'Answer copied.'**
  String get aiCopied;

  /// No description provided for @aiYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get aiYou;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get aiAssistant;

  /// No description provided for @aiLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get aiLoadOlder;

  /// No description provided for @aiDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get aiDone;

  /// No description provided for @planJournalEntry.
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get planJournalEntry;

  /// No description provided for @planMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Mark price'**
  String get planMarkPrice;

  /// No description provided for @journalPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get journalPair;

  /// No description provided for @planTabPositions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get planTabPositions;

  /// No description provided for @planTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planTabActive;

  /// No description provided for @planTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get planTabHistory;

  /// No description provided for @planTabJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get planTabJournal;

  /// No description provided for @planCreateOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Create a plan on the web'**
  String get planCreateOnWeb;

  /// No description provided for @planDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get planDrafts;

  /// No description provided for @planEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get planEmpty;

  /// No description provided for @planEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Plans are created on the web; they show here once saved.'**
  String get planEmptyHint;

  /// No description provided for @planHistoryExecuted.
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get planHistoryExecuted;

  /// No description provided for @planHistoryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled · Expired'**
  String get planHistoryCancelled;

  /// No description provided for @planPositionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get planPositionOpen;

  /// No description provided for @planPositionClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get planPositionClosed;

  /// No description provided for @planLong.
  ///
  /// In en, this message translates to:
  /// **'LONG'**
  String get planLong;

  /// No description provided for @planShort.
  ///
  /// In en, this message translates to:
  /// **'SHORT'**
  String get planShort;

  /// No description provided for @planEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get planEntry;

  /// No description provided for @planStopLoss.
  ///
  /// In en, this message translates to:
  /// **'SL'**
  String get planStopLoss;

  /// No description provided for @planTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'TP'**
  String get planTakeProfit;

  /// No description provided for @planDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trading plan'**
  String get planDetailTitle;

  /// No description provided for @planEditOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Edit on the web'**
  String get planEditOnWeb;

  /// No description provided for @planSimulatedPosition.
  ///
  /// In en, this message translates to:
  /// **'Simulated position'**
  String get planSimulatedPosition;

  /// No description provided for @planInvalidTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Invalidated: take profit reached before the entry'**
  String get planInvalidTakeProfit;

  /// No description provided for @planInvalidStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Invalidated: stop loss reached before the entry'**
  String get planInvalidStopLoss;

  /// No description provided for @planInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalidated: the invalidation price was reached'**
  String get planInvalidPrice;

  /// No description provided for @planUnrealized.
  ///
  /// In en, this message translates to:
  /// **'Unrealized P/L'**
  String get planUnrealized;

  /// No description provided for @planUnrealizedHint.
  ///
  /// In en, this message translates to:
  /// **'By the current price; fees and funding not included.'**
  String get planUnrealizedHint;

  /// No description provided for @planNetPnl.
  ///
  /// In en, this message translates to:
  /// **'Net P/L'**
  String get planNetPnl;

  /// No description provided for @planProvisional.
  ///
  /// In en, this message translates to:
  /// **'provisional'**
  String get planProvisional;

  /// No description provided for @planEntryFill.
  ///
  /// In en, this message translates to:
  /// **'Entry fill'**
  String get planEntryFill;

  /// No description provided for @planQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get planQuantity;

  /// No description provided for @planCurrentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current price'**
  String get planCurrentPrice;

  /// No description provided for @planLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Liquidation'**
  String get planLiquidation;

  /// No description provided for @planBreakeven.
  ///
  /// In en, this message translates to:
  /// **'Breakeven'**
  String get planBreakeven;

  /// No description provided for @planExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get planExit;

  /// No description provided for @planExitTime.
  ///
  /// In en, this message translates to:
  /// **'Exit time'**
  String get planExitTime;

  /// No description provided for @planRealized.
  ///
  /// In en, this message translates to:
  /// **'Realized P/L'**
  String get planRealized;

  /// No description provided for @planFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get planFees;

  /// No description provided for @planFunding.
  ///
  /// In en, this message translates to:
  /// **'Funding'**
  String get planFunding;

  /// No description provided for @planEntryTime.
  ///
  /// In en, this message translates to:
  /// **'Entry time'**
  String get planEntryTime;

  /// No description provided for @planCloseTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take profit'**
  String get planCloseTakeProfit;

  /// No description provided for @planCloseStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop loss'**
  String get planCloseStopLoss;

  /// No description provided for @planCloseManual.
  ///
  /// In en, this message translates to:
  /// **'Closed manually'**
  String get planCloseManual;

  /// No description provided for @planCloseLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Liquidation'**
  String get planCloseLiquidation;

  /// No description provided for @planSeverityBlocking.
  ///
  /// In en, this message translates to:
  /// **'BLOCKING'**
  String get planSeverityBlocking;

  /// No description provided for @planSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get planSeverityWarning;

  /// No description provided for @planSeverityInfo.
  ///
  /// In en, this message translates to:
  /// **'INFO'**
  String get planSeverityInfo;

  /// No description provided for @planInputs.
  ///
  /// In en, this message translates to:
  /// **'Plan inputs'**
  String get planInputs;

  /// No description provided for @planEntryType.
  ///
  /// In en, this message translates to:
  /// **'Entry type'**
  String get planEntryType;

  /// No description provided for @planCapital.
  ///
  /// In en, this message translates to:
  /// **'Capital (USDT)'**
  String get planCapital;

  /// No description provided for @planRiskPercent.
  ///
  /// In en, this message translates to:
  /// **'Risk per trade'**
  String get planRiskPercent;

  /// No description provided for @planLeverage.
  ///
  /// In en, this message translates to:
  /// **'Leverage'**
  String get planLeverage;

  /// No description provided for @planTimeframe.
  ///
  /// In en, this message translates to:
  /// **'Timeframe'**
  String get planTimeframe;

  /// No description provided for @planExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get planExpires;

  /// No description provided for @planNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get planNote;

  /// No description provided for @planSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Calculation snapshot'**
  String get planSnapshot;

  /// No description provided for @planRiskAmount.
  ///
  /// In en, this message translates to:
  /// **'Risk (USDT)'**
  String get planRiskAmount;

  /// No description provided for @planRewardAmount.
  ///
  /// In en, this message translates to:
  /// **'Reward (USDT)'**
  String get planRewardAmount;

  /// No description provided for @planRiskReward.
  ///
  /// In en, this message translates to:
  /// **'Risk/reward'**
  String get planRiskReward;

  /// No description provided for @planNetRiskReward.
  ///
  /// In en, this message translates to:
  /// **'Risk/reward after fees'**
  String get planNetRiskReward;

  /// No description provided for @planSummaryRr.
  ///
  /// In en, this message translates to:
  /// **'Risk : reward'**
  String get planSummaryRr;

  /// No description provided for @planLossAtSl.
  ///
  /// In en, this message translates to:
  /// **'Loss at stop'**
  String get planLossAtSl;

  /// No description provided for @planNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get planNow;

  /// No description provided for @planGridStop.
  ///
  /// In en, this message translates to:
  /// **'Stop loss'**
  String get planGridStop;

  /// No description provided for @planGridTake.
  ///
  /// In en, this message translates to:
  /// **'Take profit'**
  String get planGridTake;

  /// No description provided for @planGridMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin (USDT)'**
  String get planGridMargin;

  /// No description provided for @planLadderLabel.
  ///
  /// In en, this message translates to:
  /// **'Price ladder: stop loss {stop}, entry {entry}, take profit {target}, last price {now}'**
  String planLadderLabel(String stop, String entry, String target, String now);

  /// No description provided for @planStatusHistory.
  ///
  /// In en, this message translates to:
  /// **'Status history'**
  String get planStatusHistory;

  /// No description provided for @planActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get planActivate;

  /// No description provided for @planCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel plan'**
  String get planCancel;

  /// No description provided for @planKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get planKeep;

  /// No description provided for @planSetLevels.
  ///
  /// In en, this message translates to:
  /// **'Set SL/TP'**
  String get planSetLevels;

  /// No description provided for @planClosePosition.
  ///
  /// In en, this message translates to:
  /// **'Close position'**
  String get planClosePosition;

  /// No description provided for @planConfirmClose.
  ///
  /// In en, this message translates to:
  /// **'Confirm close'**
  String get planConfirmClose;

  /// No description provided for @planClosed.
  ///
  /// In en, this message translates to:
  /// **'Position closed.'**
  String get planClosed;

  /// No description provided for @planExitEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated exit price'**
  String get planExitEstimate;

  /// No description provided for @planPriceResult.
  ///
  /// In en, this message translates to:
  /// **'Price result'**
  String get planPriceResult;

  /// No description provided for @planEntryFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Entry fee'**
  String get planEntryFeeLine;

  /// No description provided for @planExitFee.
  ///
  /// In en, this message translates to:
  /// **'Exit fee (taker)'**
  String get planExitFee;

  /// No description provided for @planNetEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated net P/L'**
  String get planNetEstimate;

  /// No description provided for @planRuleLong.
  ///
  /// In en, this message translates to:
  /// **'stop loss below the last price, take profit above it'**
  String get planRuleLong;

  /// No description provided for @planRuleShort.
  ///
  /// In en, this message translates to:
  /// **'stop loss above the last price, take profit below it'**
  String get planRuleShort;

  /// No description provided for @planSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get planSave;

  /// No description provided for @journalAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get journalAll;

  /// No description provided for @journalAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get journalAllTime;

  /// No description provided for @journalApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get journalApply;

  /// No description provided for @journalReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get journalReset;

  /// No description provided for @journalWin.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get journalWin;

  /// No description provided for @journalLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get journalLoss;

  /// No description provided for @journalBreakeven.
  ///
  /// In en, this message translates to:
  /// **'Breakeven'**
  String get journalBreakeven;

  /// No description provided for @journalTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get journalTo;

  /// No description provided for @journalOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get journalOpen;

  /// No description provided for @journalClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get journalClosed;

  /// No description provided for @journalSimulated.
  ///
  /// In en, this message translates to:
  /// **'Simulated'**
  String get journalSimulated;

  /// No description provided for @journalManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get journalManual;

  /// No description provided for @journalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get journalPeriod;

  /// No description provided for @journalMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get journalMarket;

  /// No description provided for @journalSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get journalSource;

  /// No description provided for @journalResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get journalResult;

  /// No description provided for @journalStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get journalStatus;

  /// No description provided for @journalStrategy.
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get journalStrategy;

  /// No description provided for @journalNoStrategy.
  ///
  /// In en, this message translates to:
  /// **'No strategy'**
  String get journalNoStrategy;

  /// No description provided for @journalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trades in this period.'**
  String get journalEmpty;

  /// No description provided for @journalRecordOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Record on the web'**
  String get journalRecordOnWeb;

  /// No description provided for @journalEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get journalEntryTitle;

  /// No description provided for @journalOpenPlan.
  ///
  /// In en, this message translates to:
  /// **'Open its trading plan'**
  String get journalOpenPlan;

  /// No description provided for @journalReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get journalReview;

  /// No description provided for @journalReviewImageNote.
  ///
  /// In en, this message translates to:
  /// **'This trade has a chart image; its review is edited on the web so the image is kept.'**
  String get journalReviewImageNote;

  /// No description provided for @journalSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup description'**
  String get journalSetup;

  /// No description provided for @journalLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons learned'**
  String get journalLessons;

  /// No description provided for @journalMistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get journalMistakes;

  /// No description provided for @journalImageFailed.
  ///
  /// In en, this message translates to:
  /// **'The chart image could not be loaded.'**
  String get journalImageFailed;

  /// No description provided for @journalImageOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Chart image on the web'**
  String get journalImageOnWeb;

  /// No description provided for @journalImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart image'**
  String get journalImageTitle;

  /// No description provided for @journalImageHint.
  ///
  /// In en, this message translates to:
  /// **'One image: JPG, PNG or WEBP, up to 5 MB.'**
  String get journalImageHint;

  /// No description provided for @journalAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add chart image'**
  String get journalAddImage;

  /// No description provided for @journalReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get journalReplaceImage;

  /// No description provided for @journalRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get journalRemoveImage;

  /// No description provided for @journalUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String journalUploading(int percent);

  /// No description provided for @journalEditOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Edit on the web'**
  String get journalEditOnWeb;

  /// No description provided for @journalDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get journalDelete;

  /// No description provided for @journalDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this trade?'**
  String get journalDeleteTitle;

  /// No description provided for @journalDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This manual trade and its review are removed from your journal and statistics.'**
  String get journalDeleteBody;

  /// No description provided for @journalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Trade deleted.'**
  String get journalDeleted;

  /// No description provided for @journalLastDays.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days'**
  String journalLastDays(int days);

  /// No description provided for @planLevelHistory.
  ///
  /// In en, this message translates to:
  /// **'Level changes ({count})'**
  String planLevelHistory(int count);

  /// No description provided for @planWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings ({count})'**
  String planWarnings(int count);

  /// No description provided for @msg16.
  ///
  /// In en, this message translates to:
  /// **'For {direction} positions: {rule}.'**
  String msg16(String direction, String rule);

  /// No description provided for @msg18.
  ///
  /// In en, this message translates to:
  /// **'This plan has blocking warnings and cannot be activated.'**
  String get msg18;

  /// No description provided for @msg19.
  ///
  /// In en, this message translates to:
  /// **'Trading plan activated.'**
  String get msg19;

  /// No description provided for @msg20.
  ///
  /// In en, this message translates to:
  /// **'Cancel this trading plan? This action cannot be undone.'**
  String get msg20;

  /// No description provided for @msg21.
  ///
  /// In en, this message translates to:
  /// **'Close this position at about {price}? Estimated P/L: {pnl}.'**
  String msg21(String price, String pnl);

  /// No description provided for @msg51.
  ///
  /// In en, this message translates to:
  /// **'The price has moved {deviation}R from your plan. New quantity {quantity}, risk/reward {rr}. Activate anyway?'**
  String msg51(String deviation, String quantity, String rr);

  /// No description provided for @msg52.
  ///
  /// In en, this message translates to:
  /// **'The price has moved {deviation}R from your plan, beyond the allowed {max}R or past the take profit. The plan was not activated.'**
  String msg52(String deviation, String max);

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

  /// No description provided for @watchReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get watchReorder;

  /// No description provided for @watchReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag ≡ to change the order'**
  String get watchReorderHint;

  /// No description provided for @watchReorderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get watchReorderDone;

  /// No description provided for @watchReorderHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get watchReorderHandle;

  /// No description provided for @watchMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get watchMoveUp;

  /// No description provided for @watchMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get watchMoveDown;

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

  /// No description provided for @homeAcademy.
  ///
  /// In en, this message translates to:
  /// **'Academy'**
  String get homeAcademy;

  /// No description provided for @homeAcademyPath.
  ///
  /// In en, this message translates to:
  /// **'Beginner path {done}/{total}'**
  String homeAcademyPath(int done, int total);

  /// No description provided for @homeAcademyStart.
  ///
  /// In en, this message translates to:
  /// **'Learn crypto step by step'**
  String get homeAcademyStart;

  /// No description provided for @accountAcademy.
  ///
  /// In en, this message translates to:
  /// **'Academy'**
  String get accountAcademy;

  /// No description provided for @academyTitle.
  ///
  /// In en, this message translates to:
  /// **'Học viện Crypto'**
  String get academyTitle;

  /// No description provided for @academySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kiến thức crypto giải thích dễ hiểu, từ đồng coin đầu tiên đến quản lý rủi ro.'**
  String get academySubtitle;

  /// No description provided for @academyPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Lộ trình cho người mới'**
  String get academyPathTitle;

  /// No description provided for @academyPathProgress.
  ///
  /// In en, this message translates to:
  /// **'Đã học {done}/{total} bài của lộ trình'**
  String academyPathProgress(int done, int total);

  /// No description provided for @academyReadProgress.
  ///
  /// In en, this message translates to:
  /// **'Bạn đã đọc {done}/{total} bài'**
  String academyReadProgress(int done, int total);

  /// No description provided for @academyLessons.
  ///
  /// In en, this message translates to:
  /// **'Bài học'**
  String get academyLessons;

  /// No description provided for @academyAllTopics.
  ///
  /// In en, this message translates to:
  /// **'Tất cả chủ đề'**
  String get academyAllTopics;

  /// No description provided for @academyAllLevels.
  ///
  /// In en, this message translates to:
  /// **'Mọi trình độ'**
  String get academyAllLevels;

  /// No description provided for @academyLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Cơ bản'**
  String get academyLevelBeginner;

  /// No description provided for @academyLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Trung cấp'**
  String get academyLevelIntermediate;

  /// No description provided for @academyLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Nâng cao'**
  String get academyLevelAdvanced;

  /// No description provided for @academySearch.
  ///
  /// In en, this message translates to:
  /// **'Tìm bài học…'**
  String get academySearch;

  /// No description provided for @academyNoLessons.
  ///
  /// In en, this message translates to:
  /// **'Không có bài học nào khớp với bộ lọc.'**
  String get academyNoLessons;

  /// No description provided for @academyReadingTime.
  ///
  /// In en, this message translates to:
  /// **'{minutes} phút đọc'**
  String academyReadingTime(int minutes);

  /// No description provided for @academyGlossary.
  ///
  /// In en, this message translates to:
  /// **'Thuật ngữ'**
  String get academyGlossary;

  /// No description provided for @academyGlossarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Định nghĩa ngắn gọn các thuật ngữ thường gặp trong crypto.'**
  String get academyGlossarySubtitle;

  /// No description provided for @academyGlossaryTeaser.
  ///
  /// In en, this message translates to:
  /// **'Gặp một từ chưa hiểu?'**
  String get academyGlossaryTeaser;

  /// No description provided for @academyOpenGlossary.
  ///
  /// In en, this message translates to:
  /// **'Mở bảng thuật ngữ'**
  String get academyOpenGlossary;

  /// No description provided for @academySearchTerms.
  ///
  /// In en, this message translates to:
  /// **'Tìm thuật ngữ…'**
  String get academySearchTerms;

  /// No description provided for @academyAllLetters.
  ///
  /// In en, this message translates to:
  /// **'Tất cả'**
  String get academyAllLetters;

  /// No description provided for @academyNoTerms.
  ///
  /// In en, this message translates to:
  /// **'Không có thuật ngữ nào khớp.'**
  String get academyNoTerms;

  /// No description provided for @academyReadLesson.
  ///
  /// In en, this message translates to:
  /// **'Đọc bài học'**
  String get academyReadLesson;

  /// No description provided for @academySummary.
  ///
  /// In en, this message translates to:
  /// **'Tóm tắt nhanh'**
  String get academySummary;

  /// No description provided for @academyTryInApp.
  ///
  /// In en, this message translates to:
  /// **'Thử ngay trong ứng dụng'**
  String get academyTryInApp;

  /// No description provided for @academyPrevious.
  ///
  /// In en, this message translates to:
  /// **'Bài trước'**
  String get academyPrevious;

  /// No description provided for @academyNext.
  ///
  /// In en, this message translates to:
  /// **'Bài tiếp theo'**
  String get academyNext;

  /// No description provided for @academyRelated.
  ///
  /// In en, this message translates to:
  /// **'Bài liên quan'**
  String get academyRelated;

  /// No description provided for @academyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cập nhật {date}'**
  String academyUpdated(String date);

  /// No description provided for @academyPhotoCredit.
  ///
  /// In en, this message translates to:
  /// **'Ảnh: {credit}'**
  String academyPhotoCredit(String credit);

  /// No description provided for @academyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Bài học không tồn tại hoặc chưa được xuất bản.'**
  String get academyNotFound;

  /// No description provided for @academyBack.
  ///
  /// In en, this message translates to:
  /// **'Quay lại Học viện'**
  String get academyBack;

  /// No description provided for @academyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Nội dung chỉ nhằm mục đích giáo dục, không phải lời khuyên đầu tư.'**
  String get academyDisclaimer;

  /// No description provided for @academyMarkLearned.
  ///
  /// In en, this message translates to:
  /// **'Đánh dấu đã học'**
  String get academyMarkLearned;

  /// No description provided for @academyLearned.
  ///
  /// In en, this message translates to:
  /// **'Đã học'**
  String get academyLearned;

  /// No description provided for @academyUnmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Bấm lần nữa để bỏ đánh dấu.'**
  String get academyUnmarkHint;

  /// No description provided for @academyRetry.
  ///
  /// In en, this message translates to:
  /// **'Thử lại'**
  String get academyRetry;

  /// No description provided for @navTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get navTrade;

  /// No description provided for @navAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get navAssets;

  /// No description provided for @paperDemoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo · virtual funds. Orders never reach an exchange.'**
  String get paperDemoBanner;

  /// No description provided for @tradeSpot.
  ///
  /// In en, this message translates to:
  /// **'Spot'**
  String get tradeSpot;

  /// No description provided for @tradeFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures'**
  String get tradeFutures;

  /// No description provided for @tradeChoosePair.
  ///
  /// In en, this message translates to:
  /// **'Choose a pair'**
  String get tradeChoosePair;

  /// No description provided for @tradeBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get tradeBuy;

  /// No description provided for @tradeSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get tradeSell;

  /// No description provided for @tradeBuyAsset.
  ///
  /// In en, this message translates to:
  /// **'Buy {asset}'**
  String tradeBuyAsset(String asset);

  /// No description provided for @tradeSellAsset.
  ///
  /// In en, this message translates to:
  /// **'Sell {asset}'**
  String tradeSellAsset(String asset);

  /// No description provided for @tradeKindLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get tradeKindLimit;

  /// No description provided for @tradeKindMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get tradeKindMarket;

  /// No description provided for @tradeKindStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Stop Limit'**
  String get tradeKindStopLimit;

  /// No description provided for @tradeKindStopMarket.
  ///
  /// In en, this message translates to:
  /// **'Stop Market'**
  String get tradeKindStopMarket;

  /// No description provided for @tradeKindOco.
  ///
  /// In en, this message translates to:
  /// **'OCO'**
  String get tradeKindOco;

  /// No description provided for @tradeKindLimitTpSl.
  ///
  /// In en, this message translates to:
  /// **'Limit TP/SL'**
  String get tradeKindLimitTpSl;

  /// No description provided for @tradeKindPostOnly.
  ///
  /// In en, this message translates to:
  /// **'Post-only'**
  String get tradeKindPostOnly;

  /// No description provided for @tradeKindOto.
  ///
  /// In en, this message translates to:
  /// **'OTO'**
  String get tradeKindOto;

  /// No description provided for @tradeTrailing.
  ///
  /// In en, this message translates to:
  /// **'Trailing % (optional)'**
  String get tradeTrailing;

  /// No description provided for @tradePendingPrice.
  ///
  /// In en, this message translates to:
  /// **'Then the other way at'**
  String get tradePendingPrice;

  /// No description provided for @tradeTifGtc.
  ///
  /// In en, this message translates to:
  /// **'GTC · good till cancelled'**
  String get tradeTifGtc;

  /// No description provided for @tradeTifIoc.
  ///
  /// In en, this message translates to:
  /// **'IOC · fill now, cancel the rest'**
  String get tradeTifIoc;

  /// No description provided for @tradeTifFok.
  ///
  /// In en, this message translates to:
  /// **'FOK · fill all now or cancel'**
  String get tradeTifFok;

  /// No description provided for @tradePrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get tradePrice;

  /// No description provided for @tradeAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get tradeAmount;

  /// No description provided for @tradeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get tradeTotal;

  /// No description provided for @tradeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tradeStop;

  /// No description provided for @tradeTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take profit'**
  String get tradeTakeProfit;

  /// No description provided for @tradeStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop loss'**
  String get tradeStopLoss;

  /// No description provided for @tradeStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Stop limit (optional)'**
  String get tradeStopLimit;

  /// No description provided for @tradeByAmount.
  ///
  /// In en, this message translates to:
  /// **'By amount'**
  String get tradeByAmount;

  /// No description provided for @tradeByTotal.
  ///
  /// In en, this message translates to:
  /// **'By total'**
  String get tradeByTotal;

  /// No description provided for @tradeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Avbl {amount} {asset}'**
  String tradeAvailable(String amount, String asset);

  /// No description provided for @tradeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the demo order'**
  String get tradeConfirmTitle;

  /// No description provided for @tradeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get tradeConfirm;

  /// No description provided for @tradePlaced.
  ///
  /// In en, this message translates to:
  /// **'Demo order placed.'**
  String get tradePlaced;

  /// No description provided for @tradeOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders ({count})'**
  String tradeOpenOrders(int count);

  /// No description provided for @tradeMarketTrades.
  ///
  /// In en, this message translates to:
  /// **'Market trades'**
  String get tradeMarketTrades;

  /// No description provided for @tradeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get tradeCancel;

  /// No description provided for @tradeCancelAll.
  ///
  /// In en, this message translates to:
  /// **'Cancel all'**
  String get tradeCancelAll;

  /// No description provided for @tradeCanceled.
  ///
  /// In en, this message translates to:
  /// **'Order canceled.'**
  String get tradeCanceled;

  /// No description provided for @tradeNoOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders on this pair.'**
  String get tradeNoOpenOrders;

  /// No description provided for @tradeNoTrades.
  ///
  /// In en, this message translates to:
  /// **'No trades yet.'**
  String get tradeNoTrades;

  /// No description provided for @tradeTick.
  ///
  /// In en, this message translates to:
  /// **'Tick {size}'**
  String tradeTick(String size);

  /// No description provided for @tradeBookPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get tradeBookPrice;

  /// No description provided for @tradeBookAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get tradeBookAmount;

  /// No description provided for @accountConfirmOrders.
  ///
  /// In en, this message translates to:
  /// **'Confirm demo orders before they go'**
  String get accountConfirmOrders;

  /// No description provided for @paperErrRequired.
  ///
  /// In en, this message translates to:
  /// **'Required.'**
  String get paperErrRequired;

  /// No description provided for @paperErrPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter a number above 0.'**
  String get paperErrPositive;

  /// No description provided for @paperErrStep.
  ///
  /// In en, this message translates to:
  /// **'Enter a multiple of {limit}.'**
  String paperErrStep(String limit);

  /// No description provided for @paperErrAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Enter at least {limit}.'**
  String paperErrAtLeast(String limit);

  /// No description provided for @paperErrAtMost.
  ///
  /// In en, this message translates to:
  /// **'Enter at most {limit}.'**
  String paperErrAtMost(String limit);

  /// No description provided for @paperErrMinNotional.
  ///
  /// In en, this message translates to:
  /// **'The order value must be at least {limit} {asset}.'**
  String paperErrMinNotional(String limit, String asset);

  /// No description provided for @paperErrMaxNotional.
  ///
  /// In en, this message translates to:
  /// **'The order value must be at most {limit} {asset}.'**
  String paperErrMaxNotional(String limit, String asset);

  /// No description provided for @paperErrPercentBelow.
  ///
  /// In en, this message translates to:
  /// **'Too far below the last price: enter at least {limit}.'**
  String paperErrPercentBelow(String limit);

  /// No description provided for @paperErrPercentAbove.
  ///
  /// In en, this message translates to:
  /// **'Too far above the last price: enter at most {limit}.'**
  String paperErrPercentAbove(String limit);

  /// No description provided for @paperErrStopSide.
  ///
  /// In en, this message translates to:
  /// **'The stop is on the wrong side of the price.'**
  String get paperErrStopSide;

  /// No description provided for @paperErrTakeProfitSide.
  ///
  /// In en, this message translates to:
  /// **'The take profit is on the wrong side of the price.'**
  String get paperErrTakeProfitSide;

  /// No description provided for @paperErrInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough available balance for this order.'**
  String get paperErrInsufficient;

  /// No description provided for @paperErrNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This order is no longer open.'**
  String get paperErrNotOpen;

  /// No description provided for @paperErrWouldTake.
  ///
  /// In en, this message translates to:
  /// **'A maker-only order would trade at once.'**
  String get paperErrWouldTake;

  /// No description provided for @paperErrWouldTrigger.
  ///
  /// In en, this message translates to:
  /// **'The stop is already met at the last price.'**
  String get paperErrWouldTrigger;

  /// No description provided for @paperErrTooManyOrders.
  ///
  /// In en, this message translates to:
  /// **'Too many open orders on this pair (at most {limit}).'**
  String paperErrTooManyOrders(String limit);

  /// No description provided for @paperErrTooManyStops.
  ///
  /// In en, this message translates to:
  /// **'Too many open stops on this pair (at most {limit}).'**
  String paperErrTooManyStops(String limit);

  /// No description provided for @paperErrNotValued.
  ///
  /// In en, this message translates to:
  /// **'This pair cannot be valued in USDT right now.'**
  String get paperErrNotValued;

  /// No description provided for @assetsTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get assetsTotal;

  /// No description provided for @assetsUsdt.
  ///
  /// In en, this message translates to:
  /// **'{amount} USDT'**
  String assetsUsdt(String amount);

  /// No description provided for @assetsHidden.
  ///
  /// In en, this message translates to:
  /// **'••••••'**
  String get assetsHidden;

  /// No description provided for @assetsShowBalances.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get assetsShowBalances;

  /// No description provided for @assetsHideBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get assetsHideBalances;

  /// No description provided for @assetsSpot.
  ///
  /// In en, this message translates to:
  /// **'Spot wallet'**
  String get assetsSpot;

  /// No description provided for @assetsFutures.
  ///
  /// In en, this message translates to:
  /// **'Futures wallet'**
  String get assetsFutures;

  /// No description provided for @assetsHideSmall.
  ///
  /// In en, this message translates to:
  /// **'Hide coins under 1 USDT'**
  String get assetsHideSmall;

  /// No description provided for @assetsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Some coins have no price now and are left out of the total.'**
  String get assetsIncomplete;

  /// No description provided for @assetsFree.
  ///
  /// In en, this message translates to:
  /// **'Available {amount}'**
  String assetsFree(String amount);

  /// No description provided for @assetsLocked.
  ///
  /// In en, this message translates to:
  /// **'In orders {amount}'**
  String assetsLocked(String amount);

  /// No description provided for @assetsNoCoins.
  ///
  /// In en, this message translates to:
  /// **'No coins to show.'**
  String get assetsNoCoins;

  /// No description provided for @assetsTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get assetsTransfer;

  /// No description provided for @assetsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get assetsHistory;

  /// No description provided for @assetsTradeDemo.
  ///
  /// In en, this message translates to:
  /// **'Trade (demo)'**
  String get assetsTradeDemo;

  /// No description provided for @assetsSevenDay.
  ///
  /// In en, this message translates to:
  /// **'7-day change'**
  String get assetsSevenDay;

  /// No description provided for @assetsActionTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get assetsActionTrade;

  /// No description provided for @assetsActionPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL'**
  String get assetsActionPnl;

  /// No description provided for @assetsApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} USDT'**
  String assetsApprox(String amount);

  /// No description provided for @assetsEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get assetsEquity;

  /// No description provided for @assetsEquityDays.
  ///
  /// In en, this message translates to:
  /// **'{days}D'**
  String assetsEquityDays(int days);

  /// No description provided for @assetsEquityChart.
  ///
  /// In en, this message translates to:
  /// **'Demo account equity, last {days} days'**
  String assetsEquityChart(int days);

  /// No description provided for @assetsEquityEmpty.
  ///
  /// In en, this message translates to:
  /// **'The equity history starts after the first day.'**
  String get assetsEquityEmpty;

  /// No description provided for @assetsCoinPnl.
  ///
  /// In en, this message translates to:
  /// **'Avg cost {cost} · PnL {pnl}'**
  String assetsCoinPnl(String cost, String pnl);

  /// No description provided for @assetsSpotUpnl.
  ///
  /// In en, this message translates to:
  /// **'Spot unrealized PnL {amount} USDT'**
  String assetsSpotUpnl(String amount);

  /// No description provided for @assetsPnlIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Some coins have no cost or price yet; the totals leave them out.'**
  String get assetsPnlIncomplete;

  /// No description provided for @assetsFuturesPnl.
  ///
  /// In en, this message translates to:
  /// **'Unrealized PnL'**
  String get assetsFuturesPnl;

  /// No description provided for @assetsFuturesMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin balance'**
  String get assetsFuturesMargin;

  /// No description provided for @assetsFuturesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get assetsFuturesAvailable;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer USDT'**
  String get transferTitle;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From {wallet}'**
  String transferFrom(String wallet);

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To {wallet}'**
  String transferTo(String wallet);

  /// No description provided for @transferSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get transferSwap;

  /// No description provided for @transferAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (USDT)'**
  String get transferAmount;

  /// No description provided for @transferMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get transferMax;

  /// No description provided for @transferSend.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferSend;

  /// No description provided for @transferDone.
  ///
  /// In en, this message translates to:
  /// **'Transferred.'**
  String get transferDone;

  /// No description provided for @transferOver.
  ///
  /// In en, this message translates to:
  /// **'More than the wallet holds.'**
  String get transferOver;

  /// No description provided for @transferTooPrecise.
  ///
  /// In en, this message translates to:
  /// **'At most 8 decimals.'**
  String get transferTooPrecise;

  /// No description provided for @transferOverFutures.
  ///
  /// In en, this message translates to:
  /// **'More than can leave Futures: margin in use and unrealized profit stay.'**
  String get transferOverFutures;

  /// No description provided for @historyOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get historyOrders;

  /// No description provided for @historyFills.
  ///
  /// In en, this message translates to:
  /// **'Fills'**
  String get historyFills;

  /// No description provided for @historyLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get historyLedger;

  /// No description provided for @historyTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get historyTransfers;

  /// No description provided for @futHistPositions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get futHistPositions;

  /// No description provided for @futHistIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get futHistIncome;

  /// No description provided for @futHistConditional.
  ///
  /// In en, this message translates to:
  /// **'Conditional'**
  String get futHistConditional;

  /// No description provided for @futHistLiquidations.
  ///
  /// In en, this message translates to:
  /// **'Liquidations'**
  String get futHistLiquidations;

  /// No description provided for @futHistMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get futHistMargin;

  /// No description provided for @futHistAllPairs.
  ///
  /// In en, this message translates to:
  /// **'All pairs'**
  String get futHistAllPairs;

  /// No description provided for @futHistAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get futHistAdded;

  /// No description provided for @futHistReduced.
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get futHistReduced;

  /// No description provided for @futHistClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed {quantity}'**
  String futHistClosed(String quantity);

  /// No description provided for @historyAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyAll;

  /// No description provided for @historyDay.
  ///
  /// In en, this message translates to:
  /// **'1D'**
  String get historyDay;

  /// No description provided for @historyWeek.
  ///
  /// In en, this message translates to:
  /// **'1W'**
  String get historyWeek;

  /// No description provided for @historyMonth.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get historyMonth;

  /// No description provided for @historyQuarter.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get historyQuarter;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period.'**
  String get historyEmpty;

  /// No description provided for @historyAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get historyAllStatuses;

  /// No description provided for @historyAllTypes.
  ///
  /// In en, this message translates to:
  /// **'Any type'**
  String get historyAllTypes;

  /// No description provided for @homeDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo account'**
  String get homeDemo;

  /// No description provided for @homeDemoToday.
  ///
  /// In en, this message translates to:
  /// **'Today {pnl}'**
  String homeDemoToday(String pnl);

  /// No description provided for @homeDemoStart.
  ///
  /// In en, this message translates to:
  /// **'Practise trading with virtual funds'**
  String get homeDemoStart;

  /// No description provided for @tradeFilled.
  ///
  /// In en, this message translates to:
  /// **'Demo fill: {side} {quantity} {symbol} at {price}'**
  String tradeFilled(String side, String quantity, String symbol, String price);

  /// No description provided for @paperErrInsufficientMargin.
  ///
  /// In en, this message translates to:
  /// **'Not enough available margin for this order.'**
  String get paperErrInsufficientMargin;

  /// No description provided for @paperErrReduceOnly.
  ///
  /// In en, this message translates to:
  /// **'A reduce-only order cannot open or grow a position.'**
  String get paperErrReduceOnly;

  /// No description provided for @paperErrMaxPosition.
  ///
  /// In en, this message translates to:
  /// **'This position is larger than the leverage allows. Lower the leverage or the size.'**
  String get paperErrMaxPosition;

  /// No description provided for @paperErrLeverageMargin.
  ///
  /// In en, this message translates to:
  /// **'The leverage cannot change with the margin this position holds.'**
  String get paperErrLeverageMargin;

  /// No description provided for @paperErrMarginTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'The margin mode cannot change while a position or an order is open.'**
  String get paperErrMarginTypeLocked;

  /// No description provided for @paperErrPositionModeLocked.
  ///
  /// In en, this message translates to:
  /// **'Close every Futures position and cancel every order to change the position mode.'**
  String get paperErrPositionModeLocked;

  /// No description provided for @futModeOneWay.
  ///
  /// In en, this message translates to:
  /// **'One-way'**
  String get futModeOneWay;

  /// No description provided for @futModeHedge.
  ///
  /// In en, this message translates to:
  /// **'Hedge'**
  String get futModeHedge;

  /// No description provided for @futModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Position mode'**
  String get futModeTitle;

  /// No description provided for @futModeOneWayHint.
  ///
  /// In en, this message translates to:
  /// **'One position per pair, Long or Short.'**
  String get futModeOneWayHint;

  /// No description provided for @futModeHedgeHint.
  ///
  /// In en, this message translates to:
  /// **'A Long and a Short position per pair at once.'**
  String get futModeHedgeHint;

  /// No description provided for @futOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get futOpen;

  /// No description provided for @futCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get futCloseTab;

  /// No description provided for @futCloseLong.
  ///
  /// In en, this message translates to:
  /// **'Close Long'**
  String get futCloseLong;

  /// No description provided for @futCloseShort.
  ///
  /// In en, this message translates to:
  /// **'Close Short'**
  String get futCloseShort;

  /// No description provided for @paperErrInLiquidation.
  ///
  /// In en, this message translates to:
  /// **'The account is being liquidated. Try again in a moment.'**
  String get paperErrInLiquidation;

  /// No description provided for @paperErrPositionMargin.
  ///
  /// In en, this message translates to:
  /// **'The margin cannot change by that amount.'**
  String get paperErrPositionMargin;

  /// No description provided for @futBuyLong.
  ///
  /// In en, this message translates to:
  /// **'Buy / Long'**
  String get futBuyLong;

  /// No description provided for @futSellShort.
  ///
  /// In en, this message translates to:
  /// **'Sell / Short'**
  String get futSellShort;

  /// No description provided for @futCross.
  ///
  /// In en, this message translates to:
  /// **'Cross'**
  String get futCross;

  /// No description provided for @futIsolated.
  ///
  /// In en, this message translates to:
  /// **'Isolated'**
  String get futIsolated;

  /// No description provided for @futLeverage.
  ///
  /// In en, this message translates to:
  /// **'{value}x'**
  String futLeverage(int value);

  /// No description provided for @futLeverageTitle.
  ///
  /// In en, this message translates to:
  /// **'Leverage (max {max}x)'**
  String futLeverageTitle(int max);

  /// No description provided for @futMarginTitle.
  ///
  /// In en, this message translates to:
  /// **'Margin mode'**
  String get futMarginTitle;

  /// No description provided for @futSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get futSave;

  /// No description provided for @futKindLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get futKindLimit;

  /// No description provided for @futKindMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get futKindMarket;

  /// No description provided for @futKindStopLimit.
  ///
  /// In en, this message translates to:
  /// **'Stop Limit'**
  String get futKindStopLimit;

  /// No description provided for @futKindStopMarket.
  ///
  /// In en, this message translates to:
  /// **'Stop Market'**
  String get futKindStopMarket;

  /// No description provided for @futKindTakeProfitLimit.
  ///
  /// In en, this message translates to:
  /// **'Take Profit Limit'**
  String get futKindTakeProfitLimit;

  /// No description provided for @futKindTakeProfitMarket.
  ///
  /// In en, this message translates to:
  /// **'Take Profit Market'**
  String get futKindTakeProfitMarket;

  /// No description provided for @futKindTrailingStop.
  ///
  /// In en, this message translates to:
  /// **'Trailing Stop'**
  String get futKindTrailingStop;

  /// No description provided for @futCallback.
  ///
  /// In en, this message translates to:
  /// **'Callback %'**
  String get futCallback;

  /// No description provided for @futActivation.
  ///
  /// In en, this message translates to:
  /// **'Activation price (optional)'**
  String get futActivation;

  /// No description provided for @futErrCallback.
  ///
  /// In en, this message translates to:
  /// **'Enter 0.1 to 20.'**
  String get futErrCallback;

  /// No description provided for @futTifGtx.
  ///
  /// In en, this message translates to:
  /// **'GTX · post-only'**
  String get futTifGtx;

  /// No description provided for @futTifGtd.
  ///
  /// In en, this message translates to:
  /// **'GTD · good till a date'**
  String get futTifGtd;

  /// No description provided for @futGtdHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get futGtdHour;

  /// No description provided for @futGtdDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get futGtdDay;

  /// No description provided for @futGtdWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get futGtdWeek;

  /// No description provided for @futAmend.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get futAmend;

  /// No description provided for @calcOpen.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get calcOpen;

  /// No description provided for @calcTitle.
  ///
  /// In en, this message translates to:
  /// **'{symbol} calculator'**
  String calcTitle(String symbol);

  /// No description provided for @calcPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL'**
  String get calcPnl;

  /// No description provided for @calcTarget.
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get calcTarget;

  /// No description provided for @calcLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Liquidation price'**
  String get calcLiquidation;

  /// No description provided for @calcMaxOpen.
  ///
  /// In en, this message translates to:
  /// **'Max open'**
  String get calcMaxOpen;

  /// No description provided for @calcOpenPrice.
  ///
  /// In en, this message translates to:
  /// **'Open price'**
  String get calcOpenPrice;

  /// No description provided for @calcEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry price'**
  String get calcEntry;

  /// No description provided for @calcExit.
  ///
  /// In en, this message translates to:
  /// **'Exit price'**
  String get calcExit;

  /// No description provided for @calcRoe.
  ///
  /// In en, this message translates to:
  /// **'ROE % (negative for a loss)'**
  String get calcRoe;

  /// No description provided for @calcWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance (USDT)'**
  String get calcWallet;

  /// No description provided for @calcWalletIsolated.
  ///
  /// In en, this message translates to:
  /// **'Isolated margin (USDT, optional)'**
  String get calcWalletIsolated;

  /// No description provided for @calcAddLot.
  ///
  /// In en, this message translates to:
  /// **'Add a part'**
  String get calcAddLot;

  /// No description provided for @calcRemoveLot.
  ///
  /// In en, this message translates to:
  /// **'Remove this part'**
  String get calcRemoveLot;

  /// No description provided for @calcLotsMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one price and quantity.'**
  String get calcLotsMissing;

  /// No description provided for @calcCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calcCalculate;

  /// No description provided for @calcInitialMargin.
  ///
  /// In en, this message translates to:
  /// **'Initial margin'**
  String get calcInitialMargin;

  /// No description provided for @calcPnlResult.
  ///
  /// In en, this message translates to:
  /// **'PnL (USDT)'**
  String get calcPnlResult;

  /// No description provided for @calcRoeResult.
  ///
  /// In en, this message translates to:
  /// **'ROE'**
  String get calcRoeResult;

  /// No description provided for @calcTargetResult.
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get calcTargetResult;

  /// No description provided for @calcLiquidationResult.
  ///
  /// In en, this message translates to:
  /// **'Liquidation price'**
  String get calcLiquidationResult;

  /// No description provided for @calcMaxQuantity.
  ///
  /// In en, this message translates to:
  /// **'Max quantity'**
  String get calcMaxQuantity;

  /// No description provided for @calcMaxNotional.
  ///
  /// In en, this message translates to:
  /// **'Max value (USDT)'**
  String get calcMaxNotional;

  /// No description provided for @calcOpenPriceResult.
  ///
  /// In en, this message translates to:
  /// **'Average open price'**
  String get calcOpenPriceResult;

  /// No description provided for @calcTotalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Total quantity'**
  String get calcTotalQuantity;

  /// No description provided for @futAmendTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit the demo order'**
  String get futAmendTitle;

  /// No description provided for @futTrigger.
  ///
  /// In en, this message translates to:
  /// **'Trigger price'**
  String get futTrigger;

  /// No description provided for @futSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get futSize;

  /// No description provided for @futSizeCoin.
  ///
  /// In en, this message translates to:
  /// **'{asset}'**
  String futSizeCoin(String asset);

  /// No description provided for @futSizeUsdt.
  ///
  /// In en, this message translates to:
  /// **'USDT'**
  String get futSizeUsdt;

  /// No description provided for @futMark.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get futMark;

  /// No description provided for @futLast.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get futLast;

  /// No description provided for @futReduceOnly.
  ///
  /// In en, this message translates to:
  /// **'Reduce-only'**
  String get futReduceOnly;

  /// No description provided for @futTpSl.
  ///
  /// In en, this message translates to:
  /// **'TP/SL'**
  String get futTpSl;

  /// No description provided for @futAvailable.
  ///
  /// In en, this message translates to:
  /// **'Avbl {amount} USDT'**
  String futAvailable(String amount);

  /// No description provided for @futCost.
  ///
  /// In en, this message translates to:
  /// **'Cost {amount} USDT'**
  String futCost(String amount);

  /// No description provided for @futLiq.
  ///
  /// In en, this message translates to:
  /// **'Est. liq. price {price}'**
  String futLiq(String price);

  /// No description provided for @futConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the demo order'**
  String get futConfirmTitle;

  /// No description provided for @futBlocked.
  ///
  /// In en, this message translates to:
  /// **'This order cannot go: fix what is marked.'**
  String get futBlocked;

  /// No description provided for @futPositions.
  ///
  /// In en, this message translates to:
  /// **'Positions ({count})'**
  String futPositions(int count);

  /// No description provided for @futOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders ({count})'**
  String futOrders(int count);

  /// No description provided for @futNoPositions.
  ///
  /// In en, this message translates to:
  /// **'No open positions.'**
  String get futNoPositions;

  /// No description provided for @futNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders.'**
  String get futNoOrders;

  /// No description provided for @futLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get futLong;

  /// No description provided for @futShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get futShort;

  /// No description provided for @futEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry {price}'**
  String futEntry(String price);

  /// No description provided for @futMarkPrice.
  ///
  /// In en, this message translates to:
  /// **'Mark {price}'**
  String futMarkPrice(String price);

  /// No description provided for @futLiqShort.
  ///
  /// In en, this message translates to:
  /// **'Liq. {price}'**
  String futLiqShort(String price);

  /// No description provided for @futPnl.
  ///
  /// In en, this message translates to:
  /// **'PnL {amount}'**
  String futPnl(String amount);

  /// No description provided for @futClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get futClose;

  /// No description provided for @futMarketClose.
  ///
  /// In en, this message translates to:
  /// **'Market close'**
  String get futMarketClose;

  /// No description provided for @futCloseAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get futCloseAll;

  /// No description provided for @futCostMax.
  ///
  /// In en, this message translates to:
  /// **'Cost {cost} · Max {max}'**
  String futCostMax(String cost, String max);

  /// No description provided for @futCostOnly.
  ///
  /// In en, this message translates to:
  /// **'Cost {cost}'**
  String futCostOnly(String cost);

  /// No description provided for @futMaxOnly.
  ///
  /// In en, this message translates to:
  /// **'Max {max}'**
  String futMaxOnly(String max);

  /// No description provided for @futStepUp.
  ///
  /// In en, this message translates to:
  /// **'One step up'**
  String get futStepUp;

  /// No description provided for @futStepDown.
  ///
  /// In en, this message translates to:
  /// **'One step down'**
  String get futStepDown;

  /// No description provided for @futTpSlLine.
  ///
  /// In en, this message translates to:
  /// **'TP {tp} · SL {sl}'**
  String futTpSlLine(String tp, String sl);

  /// No description provided for @futWarnInsufficientMargin.
  ///
  /// In en, this message translates to:
  /// **'Insufficient margin'**
  String get futWarnInsufficientMargin;

  /// No description provided for @futWarnSlBeyondLiquidation.
  ///
  /// In en, this message translates to:
  /// **'Stop loss past liquidation'**
  String get futWarnSlBeyondLiquidation;

  /// No description provided for @futWarnHighLeverage.
  ///
  /// In en, this message translates to:
  /// **'High leverage'**
  String get futWarnHighLeverage;

  /// No description provided for @futWarnOversizedPosition.
  ///
  /// In en, this message translates to:
  /// **'Oversized position'**
  String get futWarnOversizedPosition;

  /// No description provided for @futWarnLowRr.
  ///
  /// In en, this message translates to:
  /// **'Low reward to risk'**
  String get futWarnLowRr;

  /// No description provided for @futWarnHighFundingRate.
  ///
  /// In en, this message translates to:
  /// **'High funding rate'**
  String get futWarnHighFundingRate;

  /// No description provided for @futWarnWideStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Wide stop loss'**
  String get futWarnWideStopLoss;

  /// No description provided for @futCloseAllAsk.
  ///
  /// In en, this message translates to:
  /// **'Close every demo position at market?'**
  String get futCloseAllAsk;

  /// No description provided for @futMarketCloseAsk.
  ///
  /// In en, this message translates to:
  /// **'Close the whole {symbol} demo position at market?'**
  String futMarketCloseAsk(String symbol);

  /// No description provided for @futCardPnl.
  ///
  /// In en, this message translates to:
  /// **'Unrealized PnL (USDT)'**
  String get futCardPnl;

  /// No description provided for @futCardRoi.
  ///
  /// In en, this message translates to:
  /// **'ROI'**
  String get futCardRoi;

  /// No description provided for @futCardSize.
  ///
  /// In en, this message translates to:
  /// **'Size ({asset})'**
  String futCardSize(String asset);

  /// No description provided for @futCardMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin (USDT)'**
  String get futCardMargin;

  /// No description provided for @futCardMarginRatio.
  ///
  /// In en, this message translates to:
  /// **'Margin ratio'**
  String get futCardMarginRatio;

  /// No description provided for @futCardEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry price'**
  String get futCardEntry;

  /// No description provided for @futCardMark.
  ///
  /// In en, this message translates to:
  /// **'Mark price'**
  String get futCardMark;

  /// No description provided for @futCardLiq.
  ///
  /// In en, this message translates to:
  /// **'Liq. price'**
  String get futCardLiq;

  /// No description provided for @futMarginOf.
  ///
  /// In en, this message translates to:
  /// **'Margin {amount}'**
  String futMarginOf(String amount);

  /// No description provided for @futMarginRatio.
  ///
  /// In en, this message translates to:
  /// **'Margin ratio {percent}'**
  String futMarginRatio(String percent);

  /// No description provided for @futCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the position'**
  String get futCloseTitle;

  /// No description provided for @futCloseLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit price (empty: Market)'**
  String get futCloseLimit;

  /// No description provided for @futMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get futMargin;

  /// No description provided for @futMarginAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get futMarginAdd;

  /// No description provided for @futMarginRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get futMarginRemove;

  /// No description provided for @futAmountUsdt.
  ///
  /// In en, this message translates to:
  /// **'Amount (USDT)'**
  String get futAmountUsdt;

  /// No description provided for @futTakeProfit.
  ///
  /// In en, this message translates to:
  /// **'Take profit'**
  String get futTakeProfit;

  /// No description provided for @futStopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop loss'**
  String get futStopLoss;

  /// No description provided for @futDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get futDone;

  /// No description provided for @futMarginCall.
  ///
  /// In en, this message translates to:
  /// **'Margin call on {symbol}: margin ratio {ratio}. Add margin or reduce the position.'**
  String futMarginCall(String symbol, String ratio);

  /// No description provided for @futErrTpSlReduceOnly.
  ///
  /// In en, this message translates to:
  /// **'TP/SL cannot go with reduce-only.'**
  String get futErrTpSlReduceOnly;

  /// No description provided for @drawingOpenChart.
  ///
  /// In en, this message translates to:
  /// **'Draw on the chart'**
  String get drawingOpenChart;

  /// No description provided for @drawingChartTitle.
  ///
  /// In en, this message translates to:
  /// **'{symbol} chart'**
  String drawingChartTitle(String symbol);

  /// No description provided for @drawingTools.
  ///
  /// In en, this message translates to:
  /// **'Drawing tools'**
  String get drawingTools;

  /// No description provided for @drawingGroupLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get drawingGroupLines;

  /// No description provided for @drawingGroupFibonacci.
  ///
  /// In en, this message translates to:
  /// **'Fibonacci'**
  String get drawingGroupFibonacci;

  /// No description provided for @drawingGroupShapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get drawingGroupShapes;

  /// No description provided for @drawingGroupPositions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get drawingGroupPositions;

  /// No description provided for @drawingGroupMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get drawingGroupMeasure;

  /// No description provided for @drawingGroupPatterns.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get drawingGroupPatterns;

  /// No description provided for @drawingGroupElliott.
  ///
  /// In en, this message translates to:
  /// **'Elliott waves'**
  String get drawingGroupElliott;

  /// No description provided for @drawingGroupAnnotation.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get drawingGroupAnnotation;

  /// No description provided for @drawingToolTrendLine.
  ///
  /// In en, this message translates to:
  /// **'Trend line'**
  String get drawingToolTrendLine;

  /// No description provided for @drawingToolRay.
  ///
  /// In en, this message translates to:
  /// **'Ray'**
  String get drawingToolRay;

  /// No description provided for @drawingToolExtendedLine.
  ///
  /// In en, this message translates to:
  /// **'Extended line'**
  String get drawingToolExtendedLine;

  /// No description provided for @drawingToolHorizontalLine.
  ///
  /// In en, this message translates to:
  /// **'Horizontal line'**
  String get drawingToolHorizontalLine;

  /// No description provided for @drawingToolHorizontalRay.
  ///
  /// In en, this message translates to:
  /// **'Horizontal ray'**
  String get drawingToolHorizontalRay;

  /// No description provided for @drawingToolVerticalLine.
  ///
  /// In en, this message translates to:
  /// **'Vertical line'**
  String get drawingToolVerticalLine;

  /// No description provided for @drawingToolParallelChannel.
  ///
  /// In en, this message translates to:
  /// **'Parallel channel'**
  String get drawingToolParallelChannel;

  /// No description provided for @drawingToolArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get drawingToolArrow;

  /// No description provided for @drawingToolFibRetracement.
  ///
  /// In en, this message translates to:
  /// **'Fib retracement'**
  String get drawingToolFibRetracement;

  /// No description provided for @drawingToolFibExtension.
  ///
  /// In en, this message translates to:
  /// **'Fib extension'**
  String get drawingToolFibExtension;

  /// No description provided for @drawingToolRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get drawingToolRectangle;

  /// No description provided for @drawingToolLongPosition.
  ///
  /// In en, this message translates to:
  /// **'Long position'**
  String get drawingToolLongPosition;

  /// No description provided for @drawingToolShortPosition.
  ///
  /// In en, this message translates to:
  /// **'Short position'**
  String get drawingToolShortPosition;

  /// No description provided for @drawingToolPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get drawingToolPriceRange;

  /// No description provided for @drawingToolDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get drawingToolDateRange;

  /// No description provided for @drawingToolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get drawingToolText;

  /// No description provided for @drawingToolXabcd.
  ///
  /// In en, this message translates to:
  /// **'XABCD pattern'**
  String get drawingToolXabcd;

  /// No description provided for @drawingToolCypher.
  ///
  /// In en, this message translates to:
  /// **'Cypher pattern'**
  String get drawingToolCypher;

  /// No description provided for @drawingToolAbcd.
  ///
  /// In en, this message translates to:
  /// **'ABCD pattern'**
  String get drawingToolAbcd;

  /// No description provided for @drawingToolThreeDrives.
  ///
  /// In en, this message translates to:
  /// **'Three drives pattern'**
  String get drawingToolThreeDrives;

  /// No description provided for @drawingToolHeadAndShoulders.
  ///
  /// In en, this message translates to:
  /// **'Head and shoulders'**
  String get drawingToolHeadAndShoulders;

  /// No description provided for @drawingToolTrianglePattern.
  ///
  /// In en, this message translates to:
  /// **'Triangle pattern'**
  String get drawingToolTrianglePattern;

  /// No description provided for @drawingToolElliottImpulse.
  ///
  /// In en, this message translates to:
  /// **'Elliott impulse wave (12345)'**
  String get drawingToolElliottImpulse;

  /// No description provided for @drawingToolElliottCorrection.
  ///
  /// In en, this message translates to:
  /// **'Elliott correction wave (ABC)'**
  String get drawingToolElliottCorrection;

  /// No description provided for @drawingToolElliottTriangle.
  ///
  /// In en, this message translates to:
  /// **'Elliott triangle wave (ABCDE)'**
  String get drawingToolElliottTriangle;

  /// No description provided for @drawingToolElliottDoubleCombo.
  ///
  /// In en, this message translates to:
  /// **'Elliott double combo wave (WXY)'**
  String get drawingToolElliottDoubleCombo;

  /// No description provided for @drawingToolElliottTripleCombo.
  ///
  /// In en, this message translates to:
  /// **'Elliott triple combo wave (WXYXZ)'**
  String get drawingToolElliottTripleCombo;

  /// No description provided for @drawingPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'{tool}: touch where each point goes and lift your finger.'**
  String drawingPlaceHint(String tool);

  /// No description provided for @drawingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get drawingCancel;

  /// No description provided for @drawingUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get drawingUndo;

  /// No description provided for @drawingRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get drawingRedo;

  /// No description provided for @drawingMore.
  ///
  /// In en, this message translates to:
  /// **'Drawing options'**
  String get drawingMore;

  /// No description provided for @drawingMagnet.
  ///
  /// In en, this message translates to:
  /// **'Magnet: snap to open, high, low or close'**
  String get drawingMagnet;

  /// No description provided for @drawingStayInDrawing.
  ///
  /// In en, this message translates to:
  /// **'Stay in drawing mode'**
  String get drawingStayInDrawing;

  /// No description provided for @drawingLockAll.
  ///
  /// In en, this message translates to:
  /// **'Lock all drawings'**
  String get drawingLockAll;

  /// No description provided for @drawingHideAll.
  ///
  /// In en, this message translates to:
  /// **'Hide all drawings'**
  String get drawingHideAll;

  /// No description provided for @drawingShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show {count} hidden drawings'**
  String drawingShowHidden(int count);

  /// No description provided for @drawingRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all drawings'**
  String get drawingRemoveAll;

  /// No description provided for @drawingRemoveAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all drawings?'**
  String get drawingRemoveAllTitle;

  /// No description provided for @drawingRemoveAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every drawing of \"{layout}\" on {symbol} is removed, locked ones included, from both the Spot and the Futures chart. This cannot be undone.'**
  String drawingRemoveAllBody(String layout, String symbol);

  /// No description provided for @drawingRemoveAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get drawingRemoveAllConfirm;

  /// No description provided for @drawingSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected drawing'**
  String get drawingSelected;

  /// No description provided for @drawingColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get drawingColor;

  /// No description provided for @drawingWidth.
  ///
  /// In en, this message translates to:
  /// **'Line width'**
  String get drawingWidth;

  /// No description provided for @drawingWidthOption.
  ///
  /// In en, this message translates to:
  /// **'{width} px'**
  String drawingWidthOption(int width);

  /// No description provided for @drawingLineStyle.
  ///
  /// In en, this message translates to:
  /// **'Line style'**
  String get drawingLineStyle;

  /// No description provided for @drawingLineSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get drawingLineSolid;

  /// No description provided for @drawingLineDashed.
  ///
  /// In en, this message translates to:
  /// **'Dashed'**
  String get drawingLineDashed;

  /// No description provided for @drawingLineDotted.
  ///
  /// In en, this message translates to:
  /// **'Dotted'**
  String get drawingLineDotted;

  /// No description provided for @drawingSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawingSettings;

  /// No description provided for @drawingLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get drawingLock;

  /// No description provided for @drawingUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get drawingUnlock;

  /// No description provided for @drawingHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get drawingHide;

  /// No description provided for @drawingRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get drawingRemove;

  /// No description provided for @drawingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'{tool} settings'**
  String drawingSettingsTitle(String tool);

  /// No description provided for @drawingFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get drawingFill;

  /// No description provided for @drawingExtendLeft.
  ///
  /// In en, this message translates to:
  /// **'Extend left'**
  String get drawingExtendLeft;

  /// No description provided for @drawingExtendRight.
  ///
  /// In en, this message translates to:
  /// **'Extend right'**
  String get drawingExtendRight;

  /// No description provided for @drawingText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get drawingText;

  /// No description provided for @drawingTextPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get drawingTextPlaceholder;

  /// No description provided for @drawingFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get drawingFontSize;

  /// No description provided for @drawingPointPrice.
  ///
  /// In en, this message translates to:
  /// **'Point {n} price'**
  String drawingPointPrice(int n);

  /// No description provided for @drawingEntryPrice.
  ///
  /// In en, this message translates to:
  /// **'Entry price'**
  String get drawingEntryPrice;

  /// No description provided for @drawingStopPrice.
  ///
  /// In en, this message translates to:
  /// **'Stop price'**
  String get drawingStopPrice;

  /// No description provided for @drawingTargetPrice.
  ///
  /// In en, this message translates to:
  /// **'Target price'**
  String get drawingTargetPrice;

  /// No description provided for @drawingInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a price greater than 0.'**
  String get drawingInvalidPrice;

  /// No description provided for @drawingInvalidPosition.
  ///
  /// In en, this message translates to:
  /// **'The stop and the target must lie on their sides of the entry.'**
  String get drawingInvalidPosition;

  /// No description provided for @drawingSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get drawingSave;

  /// No description provided for @drawingTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get drawingTextTitle;

  /// No description provided for @drawingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get drawingAdd;

  /// No description provided for @drawingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The drawing could not be saved. Your drawings were loaded again.'**
  String get drawingSaveFailed;

  /// No description provided for @drawingLimitReached.
  ///
  /// In en, this message translates to:
  /// **'This copy already holds the most drawings allowed (200). Remove one to add another.'**
  String get drawingLimitReached;

  /// No description provided for @drawingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The drawings could not be loaded.'**
  String get drawingLoadFailed;

  /// No description provided for @drawingCopies.
  ///
  /// In en, this message translates to:
  /// **'Chart copies of {symbol}'**
  String drawingCopies(String symbol);

  /// No description provided for @drawingCopyName.
  ///
  /// In en, this message translates to:
  /// **'Copy {n}'**
  String drawingCopyName(int n);

  /// No description provided for @drawingCopyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} drawings'**
  String drawingCopyCount(int count);

  /// No description provided for @drawingNewCopy.
  ///
  /// In en, this message translates to:
  /// **'New copy'**
  String get drawingNewCopy;

  /// No description provided for @drawingDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate this copy'**
  String get drawingDuplicate;

  /// No description provided for @drawingRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get drawingRename;

  /// No description provided for @drawingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name of the copy'**
  String get drawingNameLabel;

  /// No description provided for @drawingRemoveCopy.
  ///
  /// In en, this message translates to:
  /// **'Remove this copy'**
  String get drawingRemoveCopy;

  /// No description provided for @drawingRemoveCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String drawingRemoveCopyTitle(String name);

  /// No description provided for @drawingRemoveCopyBody.
  ///
  /// In en, this message translates to:
  /// **'The copy and its {count} drawings are removed from both the Spot and the Futures chart. This cannot be undone.'**
  String drawingRemoveCopyBody(int count);

  /// No description provided for @drawingRemoveCopyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove copy'**
  String get drawingRemoveCopyConfirm;

  /// No description provided for @drawingCopyLimit.
  ///
  /// In en, this message translates to:
  /// **'A pair holds at most 10 copies.'**
  String get drawingCopyLimit;

  /// No description provided for @drawingLayoutLimit.
  ///
  /// In en, this message translates to:
  /// **'This pair already holds the most copies allowed (10). Remove one to add another.'**
  String get drawingLayoutLimit;

  /// No description provided for @drawingLayoutFailed.
  ///
  /// In en, this message translates to:
  /// **'The copy could not be saved. Try again.'**
  String get drawingLayoutFailed;
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
