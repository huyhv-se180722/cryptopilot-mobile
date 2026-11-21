import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/age_format.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../academy/data/academy_progress_repository.dart';
import '../../community/domain/community.dart';
import '../../community/presentation/community_widgets.dart';
import '../../journal/domain/performance.dart';
import '../../paper/application/home_demo.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../../market/presentation/markets_screen.dart';
import '../../market/presentation/pair_actions.dart';
import '../../news/domain/news.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../notifications/presentation/notification_format.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../plans/domain/plan.dart';
import '../../watchlist/application/watchlist_controller.dart';
import '../../watchlist/domain/watchlist.dart';
import '../../watchlist/presentation/add_pair_sheet.dart';
import '../../watchlist/presentation/watchlist_view.dart';
import '../application/home_providers.dart';
import '../../../core/widgets/pair_label.dart';

/// SCR-08 Trader Dashboard, the home tab (SRS: watchlist snapshot, active
/// plans and open positions, recent notifications, performance summary,
/// latest news). Only what the backend provides is shown, as on the web;
/// each block loads, fails and empties on its own; pull to refresh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navHome),
        actions: [
          IconButton(
            key: const Key('home-search'),
            tooltip: l.homeSearch,
            icon: const Icon(Icons.search),
            onPressed: () {
              ref
                  .read(marketsSegmentRequestProvider.notifier)
                  .request(MarketsSegment.spot);
              context.go('/markets');
            },
          ),
          IconButton(
            key: const Key('open-ai'),
            tooltip: l.aiTitle,
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push('/ai'),
          ),
          const NotificationBell(),
          IconButton(
            key: const Key('open-account'),
            tooltip: l.navAccount,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            refreshHome(ref),
            ref.read(watchlistControllerProvider.notifier).load(),
            ref.read(academyProgressProvider.notifier).load(),
            ref.refresh(homeDemoProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _WatchlistBlock(),
            const _PlansBlock(),
            const _NotificationsBlock(),
            const _PerformanceBlock(),
            const _NewsBlock(),
            const _CommunityBlock(),
            const _DemoCard(),
            const _AcademyCard(),
            const SizedBox(height: 8),
            Text(
              l.msg42,
              key: const Key('home-disclaimer'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of the dashboard: title, an optional "See all", its content.
class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.blockKey,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final Key? blockKey;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: blockKey,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(onPressed: onSeeAll, child: Text(l.homeSeeAll)),
              ],
            ),
            Padding(padding: const EdgeInsets.only(right: 8), child: child),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: context.cp.muted)),
        ?action,
      ],
    ),
  );
}

/// A failed block: what went wrong and Try again.
class _Failed extends StatelessWidget {
  const _Failed(this.error, this.retry);

  final Object error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = switch (error) {
      final ApiFailure failure => failureText(l, failure),
      _ => l.msg43(l.errorUnknownReference),
    };
    return _Note(
      text,
      action: TextButton(onPressed: retry, child: Text(l.commonRetry)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: LinearProgressIndicator(),
  );
}

class _WatchlistBlock extends ConsumerWidget {
  const _WatchlistBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(watchlistControllerProvider);
    final watchlist = state.watchlist;
    Widget child;
    if (watchlist == null && state.failure != null) {
      child = _Failed(
        state.failure!,
        ref.read(watchlistControllerProvider.notifier).load,
      );
    } else if (watchlist == null) {
      child = const _Loading();
    } else if (watchlist.items.isEmpty) {
      child = _Note(
        l.homeWatchlistEmpty,
        action: TextButton.icon(
          onPressed: () => showAddPairSheet(context),
          icon: const Icon(Icons.add),
          label: Text(l.watchAddPair),
        ),
      );
    } else {
      child = Column(
        children: [
          for (final item in watchlist.items.take(homeRows))
            _WatchRow(item: item),
        ],
      );
    }
    return _Block(
      blockKey: const Key('home-watchlist'),
      title: l.homeWatchlist,
      onSeeAll: () {
        ref
            .read(marketsSegmentRequestProvider.notifier)
            .request(MarketsSegment.watchlist);
        context.go('/markets');
      },
      child: child,
    );
  }
}

class _WatchRow extends ConsumerWidget {
  const _WatchRow({required this.item});

  final WatchItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = pairFor(ref, item);
    final spot = pair?.market == Market.spot;
    final ticker = ref.watch(
      marketRepositoryProvider(
        Market.spot,
      ).select((s) => spot ? s.tickers[item.symbol] : null),
    );
    final text = Theme.of(context).textTheme;
    return InkWell(
      key: Key('home-watch-${item.symbol}'),
      onTap: pair == null ? null : () => openPairAnalysis(context, pair),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: pair == null
                  ? PairLabel.symbol(item.symbol, style: text.titleSmall)
                  : PairLabel(
                      base: pair.baseAsset,
                      quote: pair.quoteAsset,
                      style: text.titleSmall,
                    ),
            ),
            // A Futures-only pair has no Spot price (M-09): a dash.
            Text(
              formatPrice(ticker?.lastPrice, pair?.tickSize),
              style: text.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            ChangePill(percent: ticker?.changePercent24h, width: 76),
          ],
        ),
      ),
    );
  }
}

class _PlansBlock extends ConsumerStatefulWidget {
  const _PlansBlock();

  @override
  ConsumerState<_PlansBlock> createState() => _PlansBlockState();
}

class _PlansBlockState extends ConsumerState<_PlansBlock> {
  PlanTab _tab = PlanTab.active;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final web = ref.read(webLinksProvider);
    final plans = ref.watch(homePlansProvider(_tab));
    final active = ref.watch(homePlansProvider(PlanTab.active));
    final positions = ref.watch(openPositionsProvider);
    final activeCount = active.value?.total;
    final open = positions.value;

    final Widget child = switch (plans) {
      AsyncValue(:final value?) when value.items.isEmpty => _Note(
        _tab == PlanTab.active
            ? l.homePlansEmptyActive
            : l.homePlansEmptyExecuted,
        action: TextButton(
          onPressed: () => web.open('/plans/new'),
          child: Text(l.homeCreatePlanWeb),
        ),
      ),
      AsyncValue(:final value?) => Column(
        children: [for (final plan in value.items) _PlanRow(plan: plan)],
      ),
      AsyncValue(:final error?) => _Failed(
        error,
        () => ref.invalidate(homePlansProvider(_tab)),
      ),
      _ => const _Loading(),
    };

    return _Block(
      blockKey: const Key('home-plans'),
      title: l.homePlans,
      onSeeAll: () => web.open('/plans'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<PlanTab>(
            key: const Key('home-plan-tab'),
            segments: [
              ButtonSegment(
                value: PlanTab.active,
                label: Text(
                  activeCount == null
                      ? l.homePlansActive
                      : l.homePlansActiveCount(activeCount),
                ),
              ),
              ButtonSegment(
                value: PlanTab.executed,
                label: Text(l.homePlansExecuted),
              ),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _tab = value.single),
          ),
          if (open != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                open.more
                    ? l.homeOpenPositionsMore(open.open)
                    : l.homeOpenPositions(open.open),
                key: const Key('home-open-positions'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          child,
        ],
      ),
    );
  }
}

String _planStatus(AppLocalizations l, PlanSummary plan) =>
    switch (plan.positionState) {
      PositionState.open => l.homePositionOpen,
      PositionState.closed => l.homePositionClosed,
      null => switch (plan.status) {
        PlanStatus.draft => l.planStatusDraft,
        PlanStatus.active => l.planStatusActive,
        PlanStatus.executed => l.planStatusExecuted,
        PlanStatus.cancelled => l.planStatusCancelled,
        PlanStatus.expired => l.planStatusExpired,
        PlanStatus.invalidated => l.planStatusInvalidated,
      },
    };

class _PlanRow extends ConsumerWidget {
  const _PlanRow({required this.plan});

  final PlanSummary plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pair = ref.watch(
      marketRepositoryProvider(plan.market).select(
        (s) => s.pairs?.where((p) => p.pairId == plan.pairId).firstOrNull,
      ),
    );
    String price(String? value) => formatPrice(value, pair?.tickSize);
    final long = plan.direction == PlanDirection.long;
    return InkWell(
      key: Key('home-plan-${plan.id}'),
      // SCR-18 (T-091).
      onTap: () => context.push('/plan/${Uri.encodeComponent(plan.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Pair and market shrink first on a narrow phone.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: pair?.symbol ?? '…',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              '  ${[plan.market == Market.spot ? l.marketSpot : l.marketFutures, if (plan.leverage != null) '${plan.leverage}x'].join(' · ')}',
                          style: text.bodySmall?.copyWith(color: cp.muted),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  long ? l.homeDirectionLong : l.homeDirectionShort,
                  style: text.labelMedium?.copyWith(
                    color: long ? cp.positive : cp.negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_planStatus(l, plan), style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l.homePlanLevels(
                price(plan.entryPrice),
                price(plan.stopLoss),
                price(plan.takeProfit),
              ),
              style: text.bodySmall?.copyWith(
                color: cp.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBlock extends ConsumerWidget {
  const _NotificationsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final latest = ref.watch(homeNotificationsProvider);
    final Widget child = switch (latest) {
      AsyncValue(:final value?) when value.isEmpty => _Note(
        l.notificationsEmpty,
      ),
      AsyncValue(:final value?) => Column(
        children: [
          for (final notification in value)
            NotificationRow(
              notification: notification,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
        ],
      ),
      AsyncValue(:final error?) => _Failed(
        error,
        () => ref.invalidate(homeNotificationsProvider),
      ),
      _ => const _Loading(),
    };
    return _Block(
      blockKey: const Key('home-notifications'),
      title: l.notificationsTitle,
      onSeeAll: () => context.push('/notifications'),
      child: child,
    );
  }
}

class _PerformanceBlock extends ConsumerWidget {
  const _PerformanceBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final summary = ref.watch(homePerformanceProvider);
    final Widget child = switch (summary) {
      AsyncValue(:final value?) when value.trades == 0 => _Note(
        l.homePerformanceEmpty,
      ),
      AsyncValue(:final value?) => _PerformanceFigures(summary: value),
      // A backend without the performance API (before T-051) answers 404,
      // with or without a problem body.
      AsyncValue(:final error?) when _notThere(error) => _Note(
        l.homePerformanceUnavailable,
      ),
      AsyncValue(:final error?) => _Failed(
        error,
        () => ref.invalidate(homePerformanceProvider),
      ),
      _ => const _Loading(),
    };
    return _Block(
      blockKey: const Key('home-performance'),
      title: l.homePerformance,
      // SCR-23 is on the web only (SRS 3.1.1).
      onSeeAll: () => ref.read(webLinksProvider).open('/performance'),
      child: child,
    );
  }
}

bool _notThere(Object error) => switch (error) {
  ProblemFailure(:final problem) => problem.status == 404,
  UnexpectedFailure(:final status) => status == 404,
  _ => false,
};

class _PerformanceFigures extends StatelessWidget {
  const _PerformanceFigures({required this.summary});

  final PerformanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final pnl = directionOf(summary.totalNetPnl);
    Widget figure(String label, String value, {Color? color, Key? key}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall?.copyWith(color: cp.muted)),
              const SizedBox(height: 2),
              Text(
                value,
                key: key,
                style: text.titleMedium?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          figure(l.homePerformanceTrades, '${summary.trades}'),
          figure(
            l.homePerformanceWinRate,
            formatRatioAsPercent(summary.winRate),
          ),
          figure(
            l.homePerformanceNetPnl,
            formatSignedDecimal(summary.totalNetPnl),
            key: const Key('home-net-pnl'),
            color: switch (pnl) {
              Direction.up => cp.positive,
              Direction.down => cp.negative,
              Direction.flat => null,
            },
          ),
        ],
      ),
    );
  }
}

class _NewsBlock extends ConsumerWidget {
  const _NewsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final web = ref.read(webLinksProvider);
    final news = ref.watch(homeNewsProvider);
    final Widget child = switch (news) {
      AsyncValue(:final value?) when value.isEmpty => _Note(l.homeNewsEmpty),
      AsyncValue(:final value?) => Column(
        children: [for (final article in value) _NewsRow(article: article)],
      ),
      AsyncValue(:final error?) => _Failed(
        error,
        () => ref.invalidate(homeNewsProvider),
      ),
      _ => const _Loading(),
    };
    return _Block(
      blockKey: const Key('home-news'),
      title: l.homeNews,
      // SCR-28 is on the web only (SRS 3.1.1).
      onSeeAll: () => web.open('/news'),
      child: child,
    );
  }
}

/// The community (A-64): the newest pinned post and the newest posts; See
/// all opens SCR-24, a row SCR-25.
class _CommunityBlock extends ConsumerWidget {
  const _CommunityBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final posts = ref.watch(homeCommunityProvider);
    final Widget child = switch (posts) {
      AsyncValue(:final value?) when value.isEmpty => _Note(l.communityEmpty),
      AsyncValue(:final value?) => Column(
        children: [for (final post in value) _CommunityRow(post: post)],
      ),
      AsyncValue(:final error?) => _Failed(
        error,
        () => ref.invalidate(homeCommunityProvider),
      ),
      _ => const _Loading(),
    };
    return _Block(
      blockKey: const Key('home-community'),
      title: l.communityTitle,
      onSeeAll: () => context.push('/community'),
      child: child,
    );
  }
}

class _CommunityRow extends ConsumerWidget {
  const _CommunityRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    return InkWell(
      key: Key('home-post-${post.id}'),
      onTap: () => context.push(postLocation(post.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.official) ...[
                  OfficialBadge(label: l.communityOfficial),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                post.author.displayName ?? l.communityUnknownAuthor,
                formatAge(l, post.createdAt, now),
                l.communityLikesCount(compactCount(post.likeCount)),
                l.communityCommentsShort(compactCount(post.commentCount)),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The demo account (plan 9.1): its worth and today's PnL, or an
/// invitation before it is opened; both lead to Assets.
class _DemoCard extends ConsumerWidget {
  const _DemoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final demo = ref.watch(homeDemoProvider);
    final equity = demo.value;
    final pnl = equity?.todayPnl;
    final color = switch (directionOf(pnl)) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.muted,
    };
    return Card(
      key: const Key('home-demo'),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(l.homeDemo),
        subtitle: equity == null
            ? Text(l.homeDemoStart)
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${formatDecimal(equity.totalEquity, 2)} USDT · ',
                    ),
                    TextSpan(
                      // No snapshot yet today: the backend sends null.
                      text: l.homeDemoToday(
                        pnl == null
                            ? '--'
                            : '${pnl.startsWith('-') ? '' : '+'}${formatDecimal(pnl, 2)}',
                      ),
                      style: TextStyle(color: color),
                    ),
                  ],
                ),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/assets'),
      ),
    );
  }
}

/// The way into the Academy (D-155 (5)) with the beginner path progress.
class _AcademyCard extends ConsumerWidget {
  const _AcademyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final path = ref.watch(
      academyProgressProvider.select(
        (s) => switch (s.progress) {
          final p? => (done: p.pathCompleted, total: p.pathTotal),
          null => null,
        },
      ),
    );
    return Card(
      key: const Key('home-academy'),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: Text(l.homeAcademy),
        subtitle: path == null
            ? Text(l.homeAcademyStart)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeAcademyPath(path.done, path.total)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: path.total == 0 ? 0 : path.done / path.total,
                  ),
                ],
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/academy'),
      ),
    );
  }
}

class _NewsRow extends ConsumerWidget {
  const _NewsRow({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final sentiment = switch (article.sentiment) {
      NewsSentiment.bullish => l.newsBullish,
      NewsSentiment.neutral => l.newsNeutral,
      NewsSentiment.bearish => l.newsBearish,
      null => null,
    };
    return InkWell(
      key: Key('home-news-${article.id}'),
      onTap: () => ref.read(webLinksProvider).open('/news/${article.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              [
                article.source,
                notificationAge(l, article.publishedAt, now),
                ?sentiment,
                if (article.coins.isNotEmpty) article.coins.first,
              ].join(' · '),
              style: text.bodySmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
      ),
    );
  }
}
