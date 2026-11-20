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
  String msg32(String size) {
    return 'File type or size is not supported (maximum $size).';
  }

  @override
  String get msg33 => 'Your post has been published.';

  @override
  String get msg34 => 'Thank you, your report has been submitted.';

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
  String get overviewMarketCap => 'Market Cap';

  @override
  String get overviewVolume => '24h volume';

  @override
  String get overviewDominance => 'BTC Dominance';

  @override
  String get overviewFearGreed => 'Fear & Greed';

  @override
  String get overviewAltcoinSeason => 'Altcoin Season';

  @override
  String get overviewOpenInterest => 'Open Interest';

  @override
  String get overviewSeasonBitcoin => 'Bitcoin';

  @override
  String get overviewSeasonAltcoin => 'Altcoin';

  @override
  String overviewSeasonHint(int count, int days) {
    return '$count listed altcoins against Bitcoin over $days days; 75 or more is an altcoin season';
  }

  @override
  String get overviewOpenInterestHint => 'Listed Futures pairs together';

  @override
  String get overviewSourcePaprika => 'Market cap and volume: CoinPaprika';

  @override
  String get overviewSourceFearGreed => 'Fear & Greed: alternative.me';

  @override
  String get overviewFgExtremeFear => 'Extreme fear';

  @override
  String get overviewFgFear => 'Fear';

  @override
  String get overviewFgNeutral => 'Neutral';

  @override
  String get overviewFgGreed => 'Greed';

  @override
  String get overviewFgExtremeGreed => 'Extreme greed';

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
  String msg30(String quota) {
    return 'You have used today\'s $quota questions. Quota resets at 00:00.';
  }

  @override
  String get msg31 =>
      'The AI Assistant is temporarily unavailable. Please try again.';

  @override
  String get aiTitle => 'AI assistant';

  @override
  String get aiAskAi => 'Ask AI';

  @override
  String get aiNewConversation => 'New conversation';

  @override
  String get aiUntitled => 'New conversation';

  @override
  String get aiFilterAll => 'All';

  @override
  String get aiTopicMarket => 'Market analysis';

  @override
  String get aiTopicMine => 'My plan & performance';

  @override
  String get aiTopicGeneral => 'General question';

  @override
  String get aiTopicMarketHint =>
      'The assistant reads the current price, indicators and setup score of the coin you pick.';

  @override
  String get aiTopicMineHint =>
      'The assistant reads your plan (with the state of its coin) and your trading statistics.';

  @override
  String get aiTopicGeneralHint =>
      'General question — the assistant reads no market data.';

  @override
  String get aiChooseMode => 'What shall we look at?';

  @override
  String get aiNoConversations => 'No conversations yet.';

  @override
  String get aiNoConversationsHint => 'Start one and ask your first question.';

  @override
  String get aiGroupToday => 'Today';

  @override
  String get aiGroupYesterday => 'Yesterday';

  @override
  String get aiGroupWeek => 'Last 7 days';

  @override
  String get aiGroupOlder => 'Older';

  @override
  String get aiRename => 'Rename';

  @override
  String get aiRenameTitle => 'Rename conversation';

  @override
  String get aiRenameLabel => 'Title';

  @override
  String get aiSave => 'Save';

  @override
  String get aiDelete => 'Delete';

  @override
  String get aiDeleteTitle => 'Delete this conversation?';

  @override
  String get aiDeleteBody =>
      'It disappears from your list. Questions already asked today still count toward your quota.';

  @override
  String get aiDeleted => 'Conversation deleted.';

  @override
  String get aiEmptyChat => 'Ask a question to start.';

  @override
  String get aiThinking => 'The assistant is writing…';

  @override
  String get aiTryAgain => 'Try again';

  @override
  String get aiSend => 'Send';

  @override
  String aiCounter(int count) {
    return '$count/1000';
  }

  @override
  String aiQuota(int remaining, int limit) {
    return '$remaining/$limit today';
  }

  @override
  String get aiQuotaUnlimited => 'Unlimited';

  @override
  String get aiUpgradeTitle => 'The AI assistant is on PRO and PREMIUM';

  @override
  String get aiUpgradeBody =>
      'Your conversations stay readable. Upgrade to ask new questions.';

  @override
  String get aiPickPair => 'Pick a coin';

  @override
  String get aiSearchPairs => 'Search pairs';

  @override
  String get aiTimeframe => 'Timeframe';

  @override
  String aiPairChip(String symbol, String market, String timeframe) {
    return '$symbol · $market · $timeframe';
  }

  @override
  String get aiPlan => 'One of my plans';

  @override
  String get aiNoPlan => 'No plan';

  @override
  String get aiNoPlans => 'You have no plan to ask about yet.';

  @override
  String aiPlanChip(String symbol, String direction) {
    return 'Plan $symbol $direction';
  }

  @override
  String get aiLong => 'Long';

  @override
  String get aiShort => 'Short';

  @override
  String get aiPerformance => 'My trading performance';

  @override
  String get aiPerformanceLocked => 'Trading performance: PREMIUM only';

  @override
  String get aiPairNeedsChoice => 'Pick a coin for the assistant to analyse.';

  @override
  String get aiMineNeedsChoice => 'Pick a plan or tick the performance to ask.';

  @override
  String get aiPrivacy => 'Your email, name and capital are never sent.';

  @override
  String get communityTitle => 'Community';

  @override
  String get communityTabLatest => 'Latest';

  @override
  String get communityTabTrending => 'For You';

  @override
  String get communityTabMostLiked => 'Most liked';

  @override
  String get communityTabSaved => 'Saved';

  @override
  String get communityTabMine => 'My posts';

  @override
  String get communityCoinAll => 'All coins';

  @override
  String get communityCoinPick => 'Coin';

  @override
  String get communityMarketAll => 'All markets';

  @override
  String get communitySearch => 'Search titles and texts';

  @override
  String get communitySearchShort => 'Type at least 2 characters to search.';

  @override
  String get communityClearFilters => 'Clear filters';

  @override
  String get communityEmpty => 'No posts yet';

  @override
  String get communityEmptyFiltered => 'No posts match these filters.';

  @override
  String get communityEmptySaved => 'Posts you save appear here.';

  @override
  String get communityEmptyMine => 'You have not posted yet.';

  @override
  String get communityPinned => 'Pinned';

  @override
  String get communityOfficial => 'Official';

  @override
  String get communityEdited => 'edited';

  @override
  String get communityLike => 'Like';

  @override
  String get communityUnlike => 'Remove like';

  @override
  String get communitySave => 'Save';

  @override
  String get communityUnsave => 'Remove from saved';

  @override
  String get communityComments => 'Comments';

  @override
  String communityCommentsCount(int n) {
    return 'Comments ($n)';
  }

  @override
  String get communityBullish => 'Bullish';

  @override
  String get communityBearish => 'Bearish';

  @override
  String get communityVoteBullish => 'Vote bullish';

  @override
  String get communityVoteBearish => 'Vote bearish';

  @override
  String get communityVideo => 'Video';

  @override
  String get communityWatchVideo => 'Watch the video';

  @override
  String get communityOpenImage => 'Open the image';

  @override
  String get communityUnknownAuthor => 'Member';

  @override
  String get communityMenu => 'More';

  @override
  String get communityReport => 'Report';

  @override
  String get communityDelete => 'Delete';

  @override
  String get communityDeleteTitle => 'Delete this post?';

  @override
  String get communityDeleted => 'Post deleted.';

  @override
  String get communityCommentPlaceholder => 'Write a comment';

  @override
  String get communityReplyPlaceholder => 'Write a reply';

  @override
  String get communitySend => 'Comment';

  @override
  String get communitySendReply => 'Reply';

  @override
  String get communityReply => 'Reply';

  @override
  String communityReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get communityCancelReply => 'Cancel reply';

  @override
  String get communityCommentDeleted => 'Comment deleted';

  @override
  String get communityCommentDeleteTitle => 'Delete this comment?';

  @override
  String get communityCommentDeleteBody =>
      'If it has replies, it stays in the thread as \"Comment deleted\".';

  @override
  String get communityEditComment => 'Edit comment';

  @override
  String get communitySaveChanges => 'Save changes';

  @override
  String get communityCommentTooLong =>
      'A comment holds at most 2,000 characters.';

  @override
  String get communityNoComments => 'No comments yet. Start the discussion.';

  @override
  String get communityReportPost => 'Report post';

  @override
  String get communityReportComment => 'Report comment';

  @override
  String get communityReportReason => 'Reason';

  @override
  String get communityReasonSpam => 'Spam';

  @override
  String get communityReasonScam => 'Scam or fraud';

  @override
  String get communityReasonAbuse => 'Abuse or harassment';

  @override
  String get communityReasonMisleading => 'Misleading information';

  @override
  String get communityReasonOther => 'Other';

  @override
  String get communityReportDetails => 'Details';

  @override
  String get communityReportDetailsHint =>
      'Required for Other, up to 500 characters';

  @override
  String get communityReportDetailsRequired =>
      'Describe the problem when you choose Other.';

  @override
  String get communityReportSubmit => 'Submit report';

  @override
  String get communityAlreadyReportedPost =>
      'You have already reported this post.';

  @override
  String get communityAlreadyReportedComment =>
      'You have already reported this comment.';

  @override
  String get communityLoadMore => 'Load more';

  @override
  String get composerNew => 'New post';

  @override
  String get composerEdit => 'Edit post';

  @override
  String get composerPublish => 'Publish';

  @override
  String get composerTitle => 'Title';

  @override
  String get composerTitleHint =>
      'Give your post a title (5 to 150 characters)';

  @override
  String get composerContent => 'What do you want to share?';

  @override
  String get composerCoins => 'Coins (up to 5)';

  @override
  String get composerAddCoin => 'Add a coin';

  @override
  String composerRemoveCoin(String coin) {
    return 'Remove $coin';
  }

  @override
  String get composerMarket => 'Market';

  @override
  String get composerNoMarket => 'None';

  @override
  String get composerStance => 'Your stance';

  @override
  String get composerNoStance => 'None';

  @override
  String get composerMediaHint =>
      'Up to 4 images (JPG, PNG, WEBP) or 1 video (MP4, WEBM).';

  @override
  String get composerAddImages => 'Add images';

  @override
  String get composerAddVideo => 'Add video';

  @override
  String composerUploading(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get composerRemove => 'Remove';

  @override
  String get composerFieldInvalid => 'Check this field.';

  @override
  String get composerSaved => 'Your changes are saved.';

  @override
  String communityLikesCount(String n) {
    return '$n likes';
  }

  @override
  String communityCommentsShort(String n) {
    return '$n comments';
  }

  @override
  String aiStyleChip(String style, String risk) {
    return 'Style: $style · $risk';
  }

  @override
  String get aiStyleNotSet => 'Set your trading style';

  @override
  String get aiStyleHint =>
      'The assistant explains things for the way you trade.';

  @override
  String get aiStyleScalping => 'Scalping';

  @override
  String get aiStyleDay => 'Day trading';

  @override
  String get aiStyleSwing => 'Swing';

  @override
  String get aiStylePosition => 'Position';

  @override
  String get aiRiskConservative => 'Conservative';

  @override
  String get aiRiskBalanced => 'Balanced';

  @override
  String get aiRiskAggressive => 'Aggressive';

  @override
  String get aiPlaceholderGeneral => 'Ask anything about trading…';

  @override
  String get aiPlaceholderNoPair => 'Ask about a coin…';

  @override
  String aiPlaceholderPair(String symbol) {
    return 'Ask about $symbol…';
  }

  @override
  String get aiPlaceholderMine =>
      'Ask about your plan or your trading performance…';

  @override
  String get aiDisclaimer => 'For reference only, not investment advice.';

  @override
  String get aiSources => 'Sources';

  @override
  String get aiCopy => 'Copy';

  @override
  String get aiCopied => 'Answer copied.';

  @override
  String get aiYou => 'You';

  @override
  String get aiAssistant => 'Assistant';

  @override
  String get aiLoadOlder => 'Load earlier messages';

  @override
  String get aiDone => 'Done';

  @override
  String get planJournalEntry => 'Journal entry';

  @override
  String get planMarkPrice => 'Mark price';

  @override
  String get journalPair => 'Pair';

  @override
  String get planTabPositions => 'Positions';

  @override
  String get planTabActive => 'Active';

  @override
  String get planTabHistory => 'History';

  @override
  String get planTabJournal => 'Journal';

  @override
  String get planCreateOnWeb => 'Create a plan on the web';

  @override
  String get planDrafts => 'Drafts';

  @override
  String get planEmpty => 'Nothing here yet.';

  @override
  String get planEmptyHint =>
      'Plans are created on the web; they show here once saved.';

  @override
  String get planHistoryExecuted => 'Executed';

  @override
  String get planHistoryCancelled => 'Cancelled · Expired';

  @override
  String get planPositionOpen => 'OPEN';

  @override
  String get planPositionClosed => 'CLOSED';

  @override
  String get planLong => 'LONG';

  @override
  String get planShort => 'SHORT';

  @override
  String get planEntry => 'Entry';

  @override
  String get planStopLoss => 'SL';

  @override
  String get planTakeProfit => 'TP';

  @override
  String get planDetailTitle => 'Trading plan';

  @override
  String get planEditOnWeb => 'Edit on the web';

  @override
  String get planSimulatedPosition => 'Simulated position';

  @override
  String get planInvalidTakeProfit =>
      'Invalidated: take profit reached before the entry';

  @override
  String get planInvalidStopLoss =>
      'Invalidated: stop loss reached before the entry';

  @override
  String get planInvalidPrice =>
      'Invalidated: the invalidation price was reached';

  @override
  String get planUnrealized => 'Unrealized P/L';

  @override
  String get planUnrealizedHint =>
      'By the current price; fees and funding not included.';

  @override
  String get planNetPnl => 'Net P/L';

  @override
  String get planProvisional => 'provisional';

  @override
  String get planEntryFill => 'Entry fill';

  @override
  String get planQuantity => 'Quantity';

  @override
  String get planCurrentPrice => 'Current price';

  @override
  String get planLiquidation => 'Liquidation';

  @override
  String get planBreakeven => 'Breakeven';

  @override
  String get planExit => 'Exit';

  @override
  String get planExitTime => 'Exit time';

  @override
  String get planRealized => 'Realized P/L';

  @override
  String get planFees => 'Fees';

  @override
  String get planFunding => 'Funding';

  @override
  String get planEntryTime => 'Entry time';

  @override
  String get planCloseTakeProfit => 'Take profit';

  @override
  String get planCloseStopLoss => 'Stop loss';

  @override
  String get planCloseManual => 'Closed manually';

  @override
  String get planCloseLiquidation => 'Liquidation';

  @override
  String get planSeverityBlocking => 'BLOCKING';

  @override
  String get planSeverityWarning => 'WARNING';

  @override
  String get planSeverityInfo => 'INFO';

  @override
  String get planInputs => 'Plan inputs';

  @override
  String get planEntryType => 'Entry type';

  @override
  String get planCapital => 'Capital (USDT)';

  @override
  String get planRiskPercent => 'Risk per trade';

  @override
  String get planLeverage => 'Leverage';

  @override
  String get planTimeframe => 'Timeframe';

  @override
  String get planExpires => 'Expires';

  @override
  String get planNote => 'Note';

  @override
  String get planSnapshot => 'Calculation snapshot';

  @override
  String get planRiskAmount => 'Risk (USDT)';

  @override
  String get planRewardAmount => 'Reward (USDT)';

  @override
  String get planRiskReward => 'Risk/reward';

  @override
  String get planNetRiskReward => 'Risk/reward after fees';

  @override
  String get planStatusHistory => 'Status history';

  @override
  String get planActivate => 'Activate';

  @override
  String get planCancel => 'Cancel plan';

  @override
  String get planKeep => 'Keep it';

  @override
  String get planSetLevels => 'Set SL/TP';

  @override
  String get planClosePosition => 'Close position';

  @override
  String get planConfirmClose => 'Confirm close';

  @override
  String get planClosed => 'Position closed.';

  @override
  String get planExitEstimate => 'Estimated exit price';

  @override
  String get planPriceResult => 'Price result';

  @override
  String get planEntryFeeLine => 'Entry fee';

  @override
  String get planExitFee => 'Exit fee (taker)';

  @override
  String get planNetEstimate => 'Estimated net P/L';

  @override
  String get planRuleLong =>
      'stop loss below the last price, take profit above it';

  @override
  String get planRuleShort =>
      'stop loss above the last price, take profit below it';

  @override
  String get planSave => 'Save';

  @override
  String get journalAll => 'All';

  @override
  String get journalAllTime => 'All time';

  @override
  String get journalApply => 'Apply';

  @override
  String get journalReset => 'Reset';

  @override
  String get journalWin => 'WIN';

  @override
  String get journalLoss => 'LOSS';

  @override
  String get journalBreakeven => 'BREAKEVEN';

  @override
  String get journalOpen => 'Open';

  @override
  String get journalClosed => 'Closed';

  @override
  String get journalSimulated => 'Simulated';

  @override
  String get journalManual => 'Manual';

  @override
  String get journalPeriod => 'Period';

  @override
  String get journalMarket => 'Market';

  @override
  String get journalSource => 'Source';

  @override
  String get journalResult => 'Result';

  @override
  String get journalStatus => 'Status';

  @override
  String get journalStrategy => 'Strategy';

  @override
  String get journalNoStrategy => 'No strategy';

  @override
  String get journalEmpty => 'No trades in this period.';

  @override
  String get journalRecordOnWeb => 'Record on the web';

  @override
  String get journalEntryTitle => 'Trade';

  @override
  String get journalOpenPlan => 'Open its trading plan';

  @override
  String get journalReview => 'Review';

  @override
  String get journalReviewImageNote =>
      'This trade has a chart image; its review is edited on the web so the image is kept.';

  @override
  String get journalSetup => 'Setup description';

  @override
  String get journalLessons => 'Lessons learned';

  @override
  String get journalMistakes => 'Mistakes';

  @override
  String get journalImageFailed => 'The chart image could not be loaded.';

  @override
  String get journalImageOnWeb => 'Chart image on the web';

  @override
  String get journalEditOnWeb => 'Edit on the web';

  @override
  String get journalDelete => 'Delete';

  @override
  String get journalDeleteTitle => 'Delete this trade?';

  @override
  String get journalDeleteBody =>
      'This manual trade and its review are removed from your journal and statistics.';

  @override
  String get journalDeleted => 'Trade deleted.';

  @override
  String journalLastDays(int days) {
    return 'Last $days days';
  }

  @override
  String planLevelHistory(int count) {
    return 'Level changes ($count)';
  }

  @override
  String planWarnings(int count) {
    return 'Warnings ($count)';
  }

  @override
  String msg16(String direction, String rule) {
    return 'For $direction positions: $rule.';
  }

  @override
  String get msg18 =>
      'This plan has blocking warnings and cannot be activated.';

  @override
  String get msg19 => 'Trading plan activated.';

  @override
  String get msg20 => 'Cancel this trading plan? This action cannot be undone.';

  @override
  String msg21(String price, String pnl) {
    return 'Close this position at about $price? Estimated P/L: $pnl.';
  }

  @override
  String msg51(String deviation, String quantity, String rr) {
    return 'The price has moved ${deviation}R from your plan. New quantity $quantity, risk/reward $rr. Activate anyway?';
  }

  @override
  String msg52(String deviation, String max) {
    return 'The price has moved ${deviation}R from your plan, beyond the allowed ${max}R or past the take profit. The plan was not activated.';
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
  String get tradeKindPostOnly => 'Post-only';

  @override
  String get tradeKindOto => 'OTO';

  @override
  String get tradeTrailing => 'Trailing % (optional)';

  @override
  String get tradePendingPrice => 'Then the other way at';

  @override
  String get tradeTifGtc => 'GTC · good till cancelled';

  @override
  String get tradeTifIoc => 'IOC · fill now, cancel the rest';

  @override
  String get tradeTifFok => 'FOK · fill all now or cancel';

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
  String get assetsEquity => 'Equity';

  @override
  String assetsEquityDays(int days) {
    return '${days}D';
  }

  @override
  String assetsEquityChart(int days) {
    return 'Demo account equity, last $days days';
  }

  @override
  String get assetsEquityEmpty =>
      'The equity history starts after the first day.';

  @override
  String assetsCoinPnl(String cost, String pnl) {
    return 'Avg cost $cost · PnL $pnl';
  }

  @override
  String assetsSpotUpnl(String amount) {
    return 'Spot unrealized PnL $amount USDT';
  }

  @override
  String get assetsPnlIncomplete =>
      'Some coins have no cost or price yet; the totals leave them out.';

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
  String get futHistPositions => 'Positions';

  @override
  String get futHistIncome => 'Income';

  @override
  String get futHistConditional => 'Conditional';

  @override
  String get futHistLiquidations => 'Liquidations';

  @override
  String get futHistMargin => 'Margin';

  @override
  String get futHistAllPairs => 'All pairs';

  @override
  String get futHistAdded => 'Added';

  @override
  String get futHistReduced => 'Reduced';

  @override
  String futHistClosed(String quantity) {
    return 'Closed $quantity';
  }

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
  String get paperErrPositionModeLocked =>
      'Close every Futures position and cancel every order to change the position mode.';

  @override
  String get futModeOneWay => 'One-way';

  @override
  String get futModeHedge => 'Hedge';

  @override
  String get futModeTitle => 'Position mode';

  @override
  String get futModeOneWayHint => 'One position per pair, Long or Short.';

  @override
  String get futModeHedgeHint =>
      'A Long and a Short position per pair at once.';

  @override
  String get futOpen => 'Open';

  @override
  String get futCloseTab => 'Close';

  @override
  String get futCloseLong => 'Close Long';

  @override
  String get futCloseShort => 'Close Short';

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
  String get futKindTrailingStop => 'Trailing Stop';

  @override
  String get futCallback => 'Callback %';

  @override
  String get futActivation => 'Activation price (optional)';

  @override
  String get futErrCallback => 'Enter 0.1 to 20.';

  @override
  String get futTifGtx => 'GTX · post-only';

  @override
  String get futTifGtd => 'GTD · good till a date';

  @override
  String get futGtdHour => '1 hour';

  @override
  String get futGtdDay => '1 day';

  @override
  String get futGtdWeek => '7 days';

  @override
  String get futAmend => 'Edit';

  @override
  String get calcOpen => 'Calculator';

  @override
  String calcTitle(String symbol) {
    return '$symbol calculator';
  }

  @override
  String get calcPnl => 'PnL';

  @override
  String get calcTarget => 'Target price';

  @override
  String get calcLiquidation => 'Liquidation price';

  @override
  String get calcMaxOpen => 'Max open';

  @override
  String get calcOpenPrice => 'Open price';

  @override
  String get calcEntry => 'Entry price';

  @override
  String get calcExit => 'Exit price';

  @override
  String get calcRoe => 'ROE % (negative for a loss)';

  @override
  String get calcWallet => 'Wallet balance (USDT)';

  @override
  String get calcWalletIsolated => 'Isolated margin (USDT, optional)';

  @override
  String get calcAddLot => 'Add a part';

  @override
  String get calcRemoveLot => 'Remove this part';

  @override
  String get calcLotsMissing => 'Enter at least one price and quantity.';

  @override
  String get calcCalculate => 'Calculate';

  @override
  String get calcInitialMargin => 'Initial margin';

  @override
  String get calcPnlResult => 'PnL (USDT)';

  @override
  String get calcRoeResult => 'ROE';

  @override
  String get calcTargetResult => 'Target price';

  @override
  String get calcLiquidationResult => 'Liquidation price';

  @override
  String get calcMaxQuantity => 'Max quantity';

  @override
  String get calcMaxNotional => 'Max value (USDT)';

  @override
  String get calcOpenPriceResult => 'Average open price';

  @override
  String get calcTotalQuantity => 'Total quantity';

  @override
  String get futAmendTitle => 'Edit the demo order';

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
