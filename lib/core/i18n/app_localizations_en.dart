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
  String msg15(String field, String min, String max) {
    return '$field must be between $min and $max.';
  }

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

  @override
  String msg25(String pair) {
    return '$pair added to watchlist.';
  }

  @override
  String msg26(String pair, String n) {
    return 'Removing $pair will also delete $n alerts. Continue?';
  }

  @override
  String msg27(String max, String items, String plan) {
    return 'You have reached the limit of $max $items of the $plan plan. Upgrade to increase the limit?';
  }

  @override
  String msg29(String plan) {
    return 'This feature is available on the $plan plan or higher. View plans?';
  }

  @override
  String msg45(String pair) {
    return '$pair is already in your watchlist.';
  }

  @override
  String watchCount(int count, int limit) {
    return '$count / $limit pairs';
  }

  @override
  String watchCountNoLimit(int count) {
    return '$count pairs';
  }

  @override
  String get watchEmptyTitle => 'No pairs watched yet';

  @override
  String get watchEmptyBody =>
      'Add pairs to follow their price, setup score and alerts.';

  @override
  String get watchAddPair => 'Add pair';

  @override
  String get watchAdded => 'Added';

  @override
  String get watchAdd => 'Add';

  @override
  String get watchUnlabelled => 'Other';

  @override
  String watchScore(String score) {
    return 'Score $score';
  }

  @override
  String get watchScoreInsufficient => 'Score: insufficient data';

  @override
  String watchAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts',
      one: '1 alert',
      zero: 'No alerts',
    );
    return '$_temp0';
  }

  @override
  String get watchUnlisted => 'Not available now';

  @override
  String get watchEdit => 'Edit label and note';

  @override
  String get watchRemove => 'Remove';

  @override
  String get watchLabel => 'Label';

  @override
  String get watchNote => 'Note';

  @override
  String get watchSave => 'Save';

  @override
  String get watchSearchPairs => 'Search pair or coin';

  @override
  String get upgradeOnWeb => 'View plans on the web';

  @override
  String get watchAddToWatchlist => 'Add to watchlist';

  @override
  String get watchWatching => 'Watching';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsNew => 'New alert';

  @override
  String get alertCreate => 'Create alert';

  @override
  String get alertEdit => 'Edit alert';

  @override
  String get alertsAll => 'All';

  @override
  String get alertStatusACTIVE => 'Active';

  @override
  String get alertStatusPAUSED => 'Paused';

  @override
  String get alertStatusTRIGGERED => 'Triggered';

  @override
  String get alertStatusEXPIRED => 'Expired';

  @override
  String get alertTypeAll => 'All types';

  @override
  String get alertTypePRICE => 'Price';

  @override
  String get alertTypeINDICATOR => 'Indicator';

  @override
  String get alertsEmpty => 'No alerts yet.';

  @override
  String get alertsEmptyBody => 'Create one from a pair in Markets, or here.';

  @override
  String get alertsEmptyFiltered => 'No alerts match these filters.';

  @override
  String alertTriggerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Triggered $count×',
      one: 'Triggered once',
      zero: 'Never triggered',
    );
    return '$_temp0';
  }

  @override
  String alertLastTriggered(String time) {
    return 'last $time';
  }

  @override
  String alertExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get alertNoExpiry => 'No expiry';

  @override
  String get alertPause => 'Pause';

  @override
  String get alertResume => 'Resume';

  @override
  String get alertDelete => 'Delete';

  @override
  String get alertDeleteTitle => 'Delete alert';

  @override
  String alertDeleteConfirm(String condition, String pair) {
    return 'Delete the $condition alert on $pair? This cannot be undone.';
  }

  @override
  String get alertDeleted => 'Alert deleted.';

  @override
  String get alertPaused => 'Alert paused.';

  @override
  String get alertResumed => 'Alert resumed.';

  @override
  String get alertResumeExpired =>
      'This alert has expired. Edit it to set a new expiry.';

  @override
  String get alertIndicatorRSI_14 => 'RSI (14)';

  @override
  String get alertIndicatorMACD_CROSS => 'MACD cross';

  @override
  String get alertIndicatorEMA_CROSS => 'EMA 20 / EMA 50 cross';

  @override
  String get alertIndicatorFUNDING_RATE => 'Funding rate';

  @override
  String get alertIndicatorOPEN_INTEREST_CHANGE => 'Open interest change (1h)';

  @override
  String get alertConditionCROSS_ABOVE => 'Crosses above';

  @override
  String get alertConditionCROSS_BELOW => 'Crosses below';

  @override
  String get alertConditionGREATER_THAN => 'Greater than';

  @override
  String get alertConditionLESS_THAN => 'Less than';

  @override
  String get alertCrossMACD_ABOVE => 'MACD crosses above signal';

  @override
  String get alertCrossMACD_BELOW => 'MACD crosses below signal';

  @override
  String get alertCrossEMA_ABOVE => 'EMA 20 crosses above EMA 50';

  @override
  String get alertCrossEMA_BELOW => 'EMA 20 crosses below EMA 50';

  @override
  String get alertModeONCE => 'Once';

  @override
  String get alertModeONCE_PER_BAR => 'Once per bar';

  @override
  String get alertModeEVERY_TIME => 'Every time';

  @override
  String get alertModeHint =>
      'Once stops after the first trigger; once per bar triggers at most once per candle (1h for price); every time waits for the cooldown.';

  @override
  String get alertPairField => 'Pair';

  @override
  String get alertPairSearch => 'Search pair or coin';

  @override
  String get alertAddsToWatchlist =>
      'This pair is added to your watchlist with the alert.';

  @override
  String get alertMarketField => 'Market';

  @override
  String get alertTypeField => 'Alert type';

  @override
  String get alertIndicatorField => 'Indicator';

  @override
  String get alertTimeframeField => 'Timeframe';

  @override
  String get alertConditionField => 'Condition';

  @override
  String get alertPriceField => 'Target price';

  @override
  String get alertPriceHint => 'Rounded to the pair’s tick size.';

  @override
  String get alertRsiField => 'RSI level';

  @override
  String get alertPercentField => 'Change over 1 hour (%)';

  @override
  String get alertFundingField => 'Funding rate (%)';

  @override
  String alertLastPrice(String price) {
    return 'Last $price';
  }

  @override
  String alertMarkPrice(String price) {
    return 'Mark $price';
  }

  @override
  String get alertTriggerField => 'Trigger';

  @override
  String get alertCooldownField => 'Cooldown (minutes)';

  @override
  String get alertChannelsField => 'Channels';

  @override
  String get alertInApp => 'In-app (always on)';

  @override
  String get alertEmail => 'Email';

  @override
  String get alertPush => 'Push';

  @override
  String get alertExpiryField => 'Expiry';

  @override
  String alertExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get alertExpiryKeep => 'Keep current';

  @override
  String get alertSave => 'Save alert';

  @override
  String get alertNotListed =>
      'This pair is not listed on the selected market.';

  @override
  String get alertFuturesOnly =>
      'Funding rate and open interest alerts are on Futures only.';

  @override
  String alertErrPositive(String field) {
    return '$field must be greater than 0.';
  }

  @override
  String alertErrCooldown(String field) {
    return '$field must be at least 1 minute.';
  }

  @override
  String get alertErrExpiry =>
      'The expiry must be in the future and within 90 days.';

  @override
  String alertErrNumber(String field) {
    return '$field must be a number.';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsAll => 'All';

  @override
  String get notificationsUnread => 'Unread';

  @override
  String get notificationsMarkAll => 'Mark all as read';

  @override
  String get notificationsAllRead => 'All notifications marked as read.';

  @override
  String get notificationsEmpty => 'No notifications yet.';

  @override
  String get notificationsEmptyUnread => 'You\'re all caught up.';

  @override
  String get notificationsView => 'View';

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get notificationAgeNow => 'now';

  @override
  String notificationAgeMinutes(int n) {
    return '${n}m ago';
  }

  @override
  String notificationAgeHours(int n) {
    return '${n}h ago';
  }

  @override
  String notificationAgeDays(int n) {
    return '${n}d ago';
  }
}
