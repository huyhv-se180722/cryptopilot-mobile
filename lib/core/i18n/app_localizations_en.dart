// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get productName => 'CryptoPilot';

  @override
  String get productTagline => 'Crypto Trading Support System';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String msg01(String field) {
    return 'The $field field is required.';
  }

  @override
  String get msg02 => 'Please enter a valid email address.';

  @override
  String get msg03 =>
      'Password must be 8-64 characters and include uppercase, lowercase letters and a digit.';

  @override
  String get msg07 => 'This link is invalid or has expired.';

  @override
  String get msg08 => 'Incorrect email or password. Please check again.';

  @override
  String msg09(String minutes) {
    return 'Too many failed attempts. Please try again after $minutes minutes.';
  }

  @override
  String msg10(String status) {
    return 'Your account has been $status. Please contact support.';
  }

  @override
  String get msg11 =>
      'Please verify your email before logging in. Resend verification email?';

  @override
  String get msg12 => 'If the email is registered, a reset link has been sent.';

  @override
  String get msg13 => 'Your password has been changed. Please log in again.';

  @override
  String get msg14 => 'Saved successfully.';

  @override
  String get msg41 => 'No results found.';

  @override
  String get msg42 =>
      'Information on CryptoPilot is for reference and education only and is not investment advice.';

  @override
  String msg43(String code) {
    return 'Something went wrong. Please try again. (Ref: $code)';
  }

  @override
  String get msg44 => 'Your session has expired. Please log in again.';

  @override
  String msg50(String seconds) {
    return 'Too many requests. Please try again in $seconds seconds.';
  }

  @override
  String get errorNetwork =>
      'Unable to reach the server. Check your connection and try again.';

  @override
  String get errorTimeout =>
      'The server took too long to respond. Please try again.';

  @override
  String get errorUnknownReference => '—';

  @override
  String get statusLocked => 'locked';

  @override
  String get statusBanned => 'banned';

  @override
  String get authEmailLabel => 'Email address';

  @override
  String get authEmailField => 'email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordField => 'password';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authNewPasswordField => 'new password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordField => 'confirm password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authRememberMe => 'Keep me signed in for 30 days';

  @override
  String get authForgotLink => 'Forgot password?';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginSubtitle =>
      'Welcome back. Sign in to continue to your workspace.';

  @override
  String get authLoginSubmit => 'Sign in';

  @override
  String get authNoAccount => 'New to CryptoPilot?';

  @override
  String get authCreateAccountLink => 'Create a free account';

  @override
  String get authCreateAccountHint =>
      'Accounts are created on the CryptoPilot website.';

  @override
  String get authResendVerification => 'Resend verification email';

  @override
  String get authResendSent =>
      'If the address is registered and unverified, a new link is on its way.';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authRulesTitle => 'Password requirements';

  @override
  String get authRuleLength => '8–64 characters';

  @override
  String get authRuleLowercase => 'A lowercase letter';

  @override
  String get authRuleUppercase => 'An uppercase letter';

  @override
  String get authRuleDigit => 'A digit';

  @override
  String get authPasswordsDiffer => 'The passwords do not match.';

  @override
  String get authForgotTitle => 'Forgot password';

  @override
  String get authForgotSubtitle =>
      'Enter the email of your account and we will send you a reset link.';

  @override
  String get authForgotSubmit => 'Send reset link';

  @override
  String get authForgotSentTitle => 'Check your email';

  @override
  String get authForgotSentBody =>
      'Open the link in the email to choose a new password. It is valid for 30 minutes.';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetSubtitle => 'Choose a new password for your account.';

  @override
  String get authResetSubmit => 'Set new password';

  @override
  String get authRequestNewLink => 'Request a new link';

  @override
  String get authSessionExpiredTitle => 'Session expired';

  @override
  String get splashUnavailableTitle => 'Cannot reach CryptoPilot';

  @override
  String get adminTitle => 'The administration console is on the web';

  @override
  String get adminBody =>
      'This app is for Traders. Open the console in your browser to manage CryptoPilot.';

  @override
  String get adminOpenConsole => 'Open the web console';

  @override
  String get navHome => 'Home';

  @override
  String get navMarkets => 'Markets';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navPlans => 'Plans';

  @override
  String get navJournal => 'Journal';

  @override
  String get navAccount => 'Account';

  @override
  String get tabComingTitle => 'Coming in the next build';

  @override
  String get tabComingBody =>
      'This tab is being built. Use the CryptoPilot website meanwhile.';

  @override
  String get openOnWeb => 'Open on the web';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountNotificationsHint => 'In-app notifications are always on.';

  @override
  String get accountNotifyEmail => 'Email';

  @override
  String get accountNotifyPush => 'Push';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accountOnWeb => 'On the website';

  @override
  String get accountProfileLink => 'Profile and security';

  @override
  String get accountSubscriptionLink => 'Subscription';

  @override
  String get accountAbout => 'About';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutConfirm => 'Sign out of CryptoPilot on this device?';

  @override
  String get marketLive => 'Live';

  @override
  String get marketDelayed => 'Delayed';

  @override
  String get marketWatchlist => 'Watchlist';

  @override
  String get marketSpot => 'Spot';

  @override
  String get marketFutures => 'Futures';

  @override
  String get marketSearch => 'Search pair or coin';

  @override
  String get marketSortVolume => 'Pair / Vol';

  @override
  String get marketSortPrice => 'Last price';

  @override
  String get marketSortChange => '24h chg';

  @override
  String get marketPerpetual => 'Perp';

  @override
  String marketVolumeShort(String value) {
    return 'Vol $value';
  }

  @override
  String marketFundingShort(String rate) {
    return 'Funding $rate';
  }

  @override
  String get marketHigh24h => '24h high';

  @override
  String get marketLow24h => '24h low';

  @override
  String marketVolume24h(String asset) {
    return '24h volume ($asset)';
  }

  @override
  String marketTurnover24h(String asset) {
    return '24h turnover ($asset)';
  }

  @override
  String get marketBestBid => 'Best bid';

  @override
  String get marketBestAsk => 'Best ask';

  @override
  String get marketMarkPrice => 'Mark price';

  @override
  String get marketIndexPrice => 'Index price';

  @override
  String get marketFundingRate => 'Funding rate';

  @override
  String get marketNextFunding => 'Next funding in';

  @override
  String get marketAnalysisNext =>
      'Charts, indicators and the setup score arrive in the next build.';
}
