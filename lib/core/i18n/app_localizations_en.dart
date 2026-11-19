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
  String get accountLicences => 'Open-source licenses';

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
  String get analysisPairGone => 'This pair is no longer available.';

  @override
  String analysisDayRange(String high, String low, String volume) {
    return 'H $high · L $low · Vol $volume';
  }

  @override
  String chartTimeZone(String zone) {
    return 'Times in $zone';
  }

  @override
  String get analysisIndicators => 'Indicators';

  @override
  String get analysisOverlays => 'Overlays';

  @override
  String get analysisPanels => 'Panels';

  @override
  String get indicatorSma20 => 'SMA 20';

  @override
  String get indicatorEma20 => 'EMA 20';

  @override
  String get indicatorEma50 => 'EMA 50';

  @override
  String get indicatorEma200 => 'EMA 200';

  @override
  String get indicatorBollinger => 'Bollinger Bands (20, 2)';

  @override
  String get indicatorVolume => 'Volume with Volume SMA 20';

  @override
  String get indicatorRsi => 'RSI 14';

  @override
  String get indicatorMacd => 'MACD (12, 26, 9)';

  @override
  String get analysisSupport => 'Support';

  @override
  String get analysisResistance => 'Resistance';

  @override
  String get analysisInsufficient => 'Insufficient data';

  @override
  String get analysisInsufficientNotice =>
      'Fewer than 200 closed candles: some indicators and the setup score cannot be computed yet.';

  @override
  String get analysisScoreTitle => 'Setup score';

  @override
  String get analysisScoreOutOf => '/ 100';

  @override
  String analysisScoreLabel(String score) {
    return 'Setup score $score out of 100';
  }

  @override
  String analysisPresetLine(String preset, String version, String timeframe) {
    return '$preset $version · $timeframe';
  }

  @override
  String get presetScalping => 'Scalping';

  @override
  String get presetDayTrading => 'Day trading';

  @override
  String get presetSwing => 'Swing';

  @override
  String get analysisScoreCapped =>
      'Score capped: little room to the next level.';

  @override
  String get analysisComponents => 'Components';

  @override
  String get componentTrend => 'Trend';

  @override
  String get componentMomentum => 'Momentum';

  @override
  String get componentVolume => 'Volume';

  @override
  String get componentLevel => 'Level';

  @override
  String get componentDerivatives => 'Derivatives';

  @override
  String get analysisStatsTitle => 'Market statistics';

  @override
  String get statLastPrice => 'Last price';

  @override
  String get statSpread => 'Spread';

  @override
  String get statChange24h => '24h change';

  @override
  String analysisNewsTitle(String coin) {
    return 'Latest $coin news';
  }

  @override
  String analysisNewsEmpty(String coin) {
    return 'No $coin news in the last 7 days.';
  }

  @override
  String get analysisCreatePlan => 'Create plan';

  @override
  String get analysisCreatePlanHint => 'Create trading plan on the web';

  @override
  String get analysisScoredSide => 'Scored side';

  @override
  String get analysisDominantSide => 'Dominant side';

  @override
  String get sideLong => 'Long';

  @override
  String get sideShort => 'Short';

  @override
  String get sideNeutral => 'Neutral';

  @override
  String get analysisSidesNote =>
      'Sides describe the score. They are not a trade recommendation.';

  @override
  String get metricsTitle => 'Futures data';

  @override
  String get metricOpenInterest => 'Open interest';

  @override
  String get metricLongShort => 'Long/short ratio';

  @override
  String metricRange(int days) {
    return '${days}D';
  }

  @override
  String metricOiContracts(String asset) {
    return 'Open interest ($asset)';
  }

  @override
  String metricOiValue(String asset) {
    return 'Open interest value ($asset)';
  }

  @override
  String get metricLsRatio => 'Long/short account ratio';

  @override
  String get metricLongAccounts => 'Long accounts';

  @override
  String get metricShortAccounts => 'Short accounts';

  @override
  String metricsChartLabel(String symbol, String metric, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: 'day',
    );
    return '$symbol $metric, last $_temp0';
  }

  @override
  String metricsPartial(String from) {
    return 'Data is stored from $from only, a shorter period than the one selected.';
  }

  @override
  String get metricsEmpty => 'No data stored for this period yet.';

  @override
  String metricsUpdated(String time) {
    return 'Every 5 minutes · latest $time';
  }

  @override
  String get alertShort => 'Alert';

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
  String get watchReorder => 'Reorder';

  @override
  String get watchReorderHint => 'Drag ≡ to change the order';

  @override
  String get watchReorderDone => 'Done';

  @override
  String get watchReorderHandle => 'Drag to reorder';

  @override
  String get watchMoveUp => 'Move up';

  @override
  String get watchMoveDown => 'Move down';

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

  @override
  String get homeSearch => 'Search pairs';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeWatchlist => 'Watchlist';

  @override
  String get homeWatchlistEmpty => 'No pairs watched yet.';

  @override
  String get homePlans => 'Plans and positions';

  @override
  String get homePlansActive => 'Active';

  @override
  String homePlansActiveCount(int count) {
    return 'Active ($count)';
  }

  @override
  String get homePlansExecuted => 'Executed';

  @override
  String homeOpenPositions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open positions',
      one: '1 open position',
      zero: 'No open positions',
    );
    return '$_temp0';
  }

  @override
  String homeOpenPositionsMore(int count) {
    return '$count+ open positions';
  }

  @override
  String get homePlansEmptyActive => 'No active plans.';

  @override
  String get homePlansEmptyExecuted => 'No executed plans.';

  @override
  String get homeCreatePlanWeb => 'Create a plan on the web';

  @override
  String homePlanLevels(String entry, String stop, String target) {
    return 'Entry $entry · SL $stop · TP $target';
  }

  @override
  String get homeDirectionLong => 'Long';

  @override
  String get homeDirectionShort => 'Short';

  @override
  String get homePositionOpen => 'Position open';

  @override
  String get homePositionClosed => 'Position closed';

  @override
  String get planStatusDraft => 'Draft';

  @override
  String get planStatusActive => 'Active';

  @override
  String get planStatusExecuted => 'Executed';

  @override
  String get planStatusCancelled => 'Cancelled';

  @override
  String get planStatusExpired => 'Expired';

  @override
  String get planStatusInvalidated => 'Invalidated';

  @override
  String get homePerformance => 'Performance';

  @override
  String get homePerformanceTrades => 'Trades';

  @override
  String get homePerformanceWinRate => 'Win rate';

  @override
  String get homePerformanceNetPnl => 'Net P/L (USDT)';

  @override
  String get homePerformanceEmpty => 'No closed trades yet.';

  @override
  String get homePerformanceUnavailable => 'Performance is not available yet.';

  @override
  String get homeNews => 'Latest news';

  @override
  String get homeNewsEmpty => 'No news in the last 7 days.';

  @override
  String get newsBullish => 'Bullish';

  @override
  String get newsNeutral => 'Neutral';

  @override
  String get newsBearish => 'Bearish';

  @override
  String get homeAcademy => 'Academy';

  @override
  String homeAcademyPath(int done, int total) {
    return 'Beginner path $done/$total';
  }

  @override
  String get homeAcademyStart => 'Learn crypto step by step';

  @override
  String get accountAcademy => 'Academy';

  @override
  String get academyTitle => 'Học viện Crypto';

  @override
  String get academySubtitle =>
      'Kiến thức crypto giải thích dễ hiểu, từ đồng coin đầu tiên đến quản lý rủi ro.';

  @override
  String get academyPathTitle => 'Lộ trình cho người mới';

  @override
  String academyPathProgress(int done, int total) {
    return 'Đã học $done/$total bài của lộ trình';
  }

  @override
  String academyReadProgress(int done, int total) {
    return 'Bạn đã đọc $done/$total bài';
  }

  @override
  String get academyLessons => 'Bài học';

  @override
  String get academyAllTopics => 'Tất cả chủ đề';

  @override
  String get academyAllLevels => 'Mọi trình độ';

  @override
  String get academyLevelBeginner => 'Cơ bản';

  @override
  String get academyLevelIntermediate => 'Trung cấp';

  @override
  String get academyLevelAdvanced => 'Nâng cao';

  @override
  String get academySearch => 'Tìm bài học…';

  @override
  String get academyNoLessons => 'Không có bài học nào khớp với bộ lọc.';

  @override
  String academyReadingTime(int minutes) {
    return '$minutes phút đọc';
  }

  @override
  String get academyGlossary => 'Thuật ngữ';

  @override
  String get academyGlossarySubtitle =>
      'Định nghĩa ngắn gọn các thuật ngữ thường gặp trong crypto.';

  @override
  String get academyGlossaryTeaser => 'Gặp một từ chưa hiểu?';

  @override
  String get academyOpenGlossary => 'Mở bảng thuật ngữ';

  @override
  String get academySearchTerms => 'Tìm thuật ngữ…';

  @override
  String get academyAllLetters => 'Tất cả';

  @override
  String get academyNoTerms => 'Không có thuật ngữ nào khớp.';

  @override
  String get academyReadLesson => 'Đọc bài học';

  @override
  String get academySummary => 'Tóm tắt nhanh';

  @override
  String get academyTryInApp => 'Thử ngay trong ứng dụng';

  @override
  String get academyPrevious => 'Bài trước';

  @override
  String get academyNext => 'Bài tiếp theo';

  @override
  String get academyRelated => 'Bài liên quan';

  @override
  String academyUpdated(String date) {
    return 'Cập nhật $date';
  }

  @override
  String academyPhotoCredit(String credit) {
    return 'Ảnh: $credit';
  }

  @override
  String get academyNotFound =>
      'Bài học không tồn tại hoặc chưa được xuất bản.';

  @override
  String get academyBack => 'Quay lại Học viện';

  @override
  String get academyDisclaimer =>
      'Nội dung chỉ nhằm mục đích giáo dục, không phải lời khuyên đầu tư.';

  @override
  String get academyMarkLearned => 'Đánh dấu đã học';

  @override
  String get academyLearned => 'Đã học';

  @override
  String get academyUnmarkHint => 'Bấm lần nữa để bỏ đánh dấu.';

  @override
  String get academyRetry => 'Thử lại';

  @override
  String get navTrade => 'Trade';

  @override
  String get navAssets => 'Assets';

  @override
  String get paperDemoBanner =>
      'Demo · virtual funds. Orders never reach an exchange.';

  @override
  String get tradeSpot => 'Spot';

  @override
  String get tradeFutures => 'Futures';

  @override
  String get tradeChoosePair => 'Choose a pair';

  @override
  String get tradeBuy => 'Buy';

  @override
  String get tradeSell => 'Sell';

  @override
  String tradeBuyAsset(String asset) {
    return 'Buy $asset';
  }

  @override
  String tradeSellAsset(String asset) {
    return 'Sell $asset';
  }

  @override
  String get tradeKindLimit => 'Limit';

  @override
  String get tradeKindMarket => 'Market';

  @override
  String get tradeKindStopLimit => 'Stop Limit';

  @override
  String get tradeKindStopMarket => 'Stop Market';

  @override
  String get tradeKindOco => 'OCO';

  @override
  String get tradeKindLimitTpSl => 'Limit TP/SL';

  @override
  String get tradePrice => 'Price';

  @override
  String get tradeAmount => 'Amount';

  @override
  String get tradeTotal => 'Total';

  @override
  String get tradeStop => 'Stop';

  @override
  String get tradeTakeProfit => 'Take profit';

  @override
  String get tradeStopLoss => 'Stop loss';

  @override
  String get tradeStopLimit => 'Stop limit (optional)';

  @override
  String get tradeByAmount => 'By amount';

  @override
  String get tradeByTotal => 'By total';

  @override
  String tradeAvailable(String amount, String asset) {
    return 'Avbl $amount $asset';
  }

  @override
  String get tradeConfirmTitle => 'Confirm the demo order';

  @override
  String get tradeConfirm => 'Confirm';

  @override
  String get tradePlaced => 'Demo order placed.';

  @override
  String tradeOpenOrders(int count) {
    return 'Open orders ($count)';
  }

  @override
  String get tradeMarketTrades => 'Market trades';

  @override
  String get tradeCancel => 'Cancel';

  @override
  String get tradeCancelAll => 'Cancel all';

  @override
  String get tradeCanceled => 'Order canceled.';

  @override
  String get tradeNoOpenOrders => 'No open orders on this pair.';

  @override
  String get tradeNoTrades => 'No trades yet.';

  @override
  String tradeTick(String size) {
    return 'Tick $size';
  }

  @override
  String get tradeBookPrice => 'Price';

  @override
  String get tradeBookAmount => 'Amount';

  @override
  String get accountConfirmOrders => 'Confirm demo orders before they go';

  @override
  String get paperErrRequired => 'Required.';

  @override
  String get paperErrPositive => 'Enter a number above 0.';

  @override
  String paperErrStep(String limit) {
    return 'Enter a multiple of $limit.';
  }

  @override
  String paperErrAtLeast(String limit) {
    return 'Enter at least $limit.';
  }

  @override
  String paperErrAtMost(String limit) {
    return 'Enter at most $limit.';
  }

  @override
  String paperErrMinNotional(String limit, String asset) {
    return 'The order value must be at least $limit $asset.';
  }

  @override
  String paperErrMaxNotional(String limit, String asset) {
    return 'The order value must be at most $limit $asset.';
  }

  @override
  String paperErrPercentBelow(String limit) {
    return 'Too far below the last price: enter at least $limit.';
  }

  @override
  String paperErrPercentAbove(String limit) {
    return 'Too far above the last price: enter at most $limit.';
  }

  @override
  String get paperErrStopSide => 'The stop is on the wrong side of the price.';

  @override
  String get paperErrTakeProfitSide =>
      'The take profit is on the wrong side of the price.';

  @override
  String get paperErrInsufficient =>
      'Not enough available balance for this order.';

  @override
  String get paperErrNotOpen => 'This order is no longer open.';

  @override
  String get paperErrWouldTake => 'A maker-only order would trade at once.';

  @override
  String get paperErrWouldTrigger =>
      'The stop is already met at the last price.';

  @override
  String paperErrTooManyOrders(String limit) {
    return 'Too many open orders on this pair (at most $limit).';
  }

  @override
  String paperErrTooManyStops(String limit) {
    return 'Too many open stops on this pair (at most $limit).';
  }

  @override
  String get paperErrNotValued =>
      'This pair cannot be valued in USDT right now.';

  @override
  String get assetsTotal => 'Estimated total';

  @override
  String assetsUsdt(String amount) {
    return '$amount USDT';
  }

  @override
  String get assetsHidden => '••••••';

  @override
  String get assetsShowBalances => 'Show balances';

  @override
  String get assetsHideBalances => 'Hide balances';

  @override
  String get assetsSpot => 'Spot wallet';

  @override
  String get assetsFutures => 'Futures wallet';

  @override
  String get assetsHideSmall => 'Hide coins under 1 USDT';

  @override
  String get assetsIncomplete =>
      'Some coins have no price now and are left out of the total.';

  @override
  String assetsFree(String amount) {
    return 'Available $amount';
  }

  @override
  String assetsLocked(String amount) {
    return 'In orders $amount';
  }

  @override
  String get assetsNoCoins => 'No coins to show.';

  @override
  String get assetsTransfer => 'Transfer';

  @override
  String get assetsHistory => 'History';

  @override
  String get assetsTradeDemo => 'Trade (demo)';

  @override
  String get assetsFuturesPnl => 'Unrealized PnL';

  @override
  String get assetsFuturesMargin => 'Margin balance';

  @override
  String get assetsFuturesAvailable => 'Available';

  @override
  String get transferTitle => 'Transfer USDT';

  @override
  String transferFrom(String wallet) {
    return 'From $wallet';
  }

  @override
  String transferTo(String wallet) {
    return 'To $wallet';
  }

  @override
  String get transferSwap => 'Swap';

  @override
  String get transferAmount => 'Amount (USDT)';

  @override
  String get transferMax => 'Max';

  @override
  String get transferSend => 'Transfer';

  @override
  String get transferDone => 'Transferred.';

  @override
  String get transferOver => 'More than the wallet holds.';

  @override
  String get transferTooPrecise => 'At most 8 decimals.';

  @override
  String get transferOverFutures =>
      'More than can leave Futures: margin in use and unrealized profit stay.';

  @override
  String get historyOrders => 'Orders';

  @override
  String get historyFills => 'Fills';

  @override
  String get historyLedger => 'Ledger';

  @override
  String get historyTransfers => 'Transfers';

  @override
  String get historyAll => 'All';

  @override
  String get historyDay => '1D';

  @override
  String get historyWeek => '1W';

  @override
  String get historyMonth => '1M';

  @override
  String get historyQuarter => '3M';

  @override
  String get historyEmpty => 'Nothing in this period.';

  @override
  String get historyAllStatuses => 'Any status';

  @override
  String get historyAllTypes => 'Any type';

  @override
  String get homeDemo => 'Demo account';

  @override
  String homeDemoToday(String pnl) {
    return 'Today $pnl';
  }

  @override
  String get homeDemoStart => 'Practise trading with virtual funds';

  @override
  String tradeFilled(
    String side,
    String quantity,
    String symbol,
    String price,
  ) {
    return 'Demo fill: $side $quantity $symbol at $price';
  }

  @override
  String get paperErrInsufficientMargin =>
      'Not enough available margin for this order.';

  @override
  String get paperErrReduceOnly =>
      'A reduce-only order cannot open or grow a position.';

  @override
  String get paperErrMaxPosition =>
      'This position is larger than the leverage allows. Lower the leverage or the size.';

  @override
  String get paperErrLeverageMargin =>
      'The leverage cannot change with the margin this position holds.';

  @override
  String get paperErrMarginTypeLocked =>
      'The margin mode cannot change while a position or an order is open.';

  @override
  String get paperErrInLiquidation =>
      'The account is being liquidated. Try again in a moment.';

  @override
  String get paperErrPositionMargin =>
      'The margin cannot change by that amount.';

  @override
  String get futBuyLong => 'Buy / Long';

  @override
  String get futSellShort => 'Sell / Short';

  @override
  String get futCross => 'Cross';

  @override
  String get futIsolated => 'Isolated';

  @override
  String futLeverage(int value) {
    return '${value}x';
  }

  @override
  String futLeverageTitle(int max) {
    return 'Leverage (max ${max}x)';
  }

  @override
  String get futMarginTitle => 'Margin mode';

  @override
  String get futSave => 'Save';

  @override
  String get futKindLimit => 'Limit';

  @override
  String get futKindMarket => 'Market';

  @override
  String get futKindStopLimit => 'Stop Limit';

  @override
  String get futKindStopMarket => 'Stop Market';

  @override
  String get futKindTakeProfitLimit => 'Take Profit Limit';

  @override
  String get futKindTakeProfitMarket => 'Take Profit Market';

  @override
  String get futTrigger => 'Trigger price';

  @override
  String get futSize => 'Size';

  @override
  String futSizeCoin(String asset) {
    return '$asset';
  }

  @override
  String get futSizeUsdt => 'USDT';

  @override
  String get futMark => 'Mark';

  @override
  String get futLast => 'Last';

  @override
  String get futReduceOnly => 'Reduce-only';

  @override
  String get futTpSl => 'TP/SL';

  @override
  String futAvailable(String amount) {
    return 'Avbl $amount USDT';
  }

  @override
  String futCost(String amount) {
    return 'Cost $amount USDT';
  }

  @override
  String futLiq(String price) {
    return 'Est. liq. price $price';
  }

  @override
  String get futConfirmTitle => 'Confirm the demo order';

  @override
  String get futBlocked => 'This order cannot go: fix what is marked.';

  @override
  String futPositions(int count) {
    return 'Positions ($count)';
  }

  @override
  String futOrders(int count) {
    return 'Open orders ($count)';
  }

  @override
  String get futNoPositions => 'No open positions.';

  @override
  String get futNoOrders => 'No open orders.';

  @override
  String get futLong => 'Long';

  @override
  String get futShort => 'Short';

  @override
  String futEntry(String price) {
    return 'Entry $price';
  }

  @override
  String futMarkPrice(String price) {
    return 'Mark $price';
  }

  @override
  String futLiqShort(String price) {
    return 'Liq. $price';
  }

  @override
  String futPnl(String amount) {
    return 'PnL $amount';
  }

  @override
  String get futClose => 'Close';

  @override
  String get futMarketClose => 'Market close';

  @override
  String get futCloseAll => 'Close all';

  @override
  String futCostMax(String cost, String max) {
    return 'Cost $cost · Max $max';
  }

  @override
  String futCostOnly(String cost) {
    return 'Cost $cost';
  }

  @override
  String futMaxOnly(String max) {
    return 'Max $max';
  }

  @override
  String get futStepUp => 'One step up';

  @override
  String get futStepDown => 'One step down';

  @override
  String futTpSlLine(String tp, String sl) {
    return 'TP $tp · SL $sl';
  }

  @override
  String get futWarnInsufficientMargin => 'Insufficient margin';

  @override
  String get futWarnSlBeyondLiquidation => 'Stop loss past liquidation';

  @override
  String get futWarnHighLeverage => 'High leverage';

  @override
  String get futWarnOversizedPosition => 'Oversized position';

  @override
  String get futWarnLowRr => 'Low reward to risk';

  @override
  String get futWarnHighFundingRate => 'High funding rate';

  @override
  String get futWarnWideStopLoss => 'Wide stop loss';

  @override
  String get futCloseAllAsk => 'Close every demo position at market?';

  @override
  String futMarketCloseAsk(String symbol) {
    return 'Close the whole $symbol demo position at market?';
  }

  @override
  String futMarginOf(String amount) {
    return 'Margin $amount';
  }

  @override
  String futMarginRatio(String percent) {
    return 'Margin ratio $percent';
  }

  @override
  String get futCloseTitle => 'Close the position';

  @override
  String get futCloseLimit => 'Limit price (empty: Market)';

  @override
  String get futMargin => 'Margin';

  @override
  String get futMarginAdd => 'Add';

  @override
  String get futMarginRemove => 'Remove';

  @override
  String get futAmountUsdt => 'Amount (USDT)';

  @override
  String get futTakeProfit => 'Take profit';

  @override
  String get futStopLoss => 'Stop loss';

  @override
  String get futDone => 'Done.';

  @override
  String futMarginCall(String symbol, String ratio) {
    return 'Margin call on $symbol: margin ratio $ratio. Add margin or reduce the position.';
  }

  @override
  String get futErrTpSlReduceOnly => 'TP/SL cannot go with reduce-only.';
}
