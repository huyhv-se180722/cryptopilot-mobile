import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../chart/application/chart_prefs.dart';
import '../../chart/presentation/chart_surface.dart';
import '../../chart/presentation/chart_view.dart';
import '../../chart/presentation/indicator_sheet.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../../market/presentation/pair_actions.dart';
import '../application/analysis_controller.dart';
import 'analysis_card.dart';
import 'futures_metrics_card.dart';
import 'futures_strip.dart';
import 'pair_news.dart';
import 'score_card.dart';
import 'stats_card.dart';

/// SCR-10 Spot pair analysis (SRS 3.3.2) and SCR-11 Futures pair analysis
/// (SRS 3.3.3): a Futures pair shows the same content on its own candles
/// plus mark, index and funding, and the open interest and long/short
/// charts.
/// The pair comes from the market board, so an unknown or disabled pair
/// says so and returns to SCR-09.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({required this.market, required this.symbol, super.key});

  final Market market;
  final String symbol;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  /// SRS 3.3.2: 1h by default.
  Timeframe _tf = Timeframe.h1;
  bool _leaving = false;

  /// SRS 3.3.2: the pair is no longer available → say so, back to SCR-09.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.analysisPairGone)));
      context.go('/markets');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final board = marketRepositoryProvider(widget.market);
    final pairs = ref.watch(board.select((s) => s.pairs));
    final boardFailure = ref.watch(board.select((s) => s.failure));
    final pair = pairs?.where((p) => p.symbol == widget.symbol).firstOrNull;

    if (pair == null) {
      final Widget body;
      if (pairs != null) {
        _leave();
        body = _Message(l.analysisPairGone);
      } else if (boardFailure != null) {
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BlockFailure(
              error: boardFailure,
              onRetry: () => ref.read(board.notifier).load(),
            ),
          ),
        );
      } else {
        body = const Center(
          key: Key('analysis-loading'),
          child: CircularProgressIndicator(),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: body,
      );
    }

    final key = (market: widget.market, symbol: widget.symbol, tf: _tf);
    ref.listen(analysisControllerProvider(key).select((s) => s.pairGone), (
      _,
      gone,
    ) {
      if (gone) _leave();
    });
    final state = ref.watch(analysisControllerProvider(key));
    final live = ref.watch(board.select((s) => s.tickers[pair.symbol]));
    final ticker = switch ((live, state.ticker)) {
      (final Ticker known, final Ticker newer) => known.merge(newer),
      (final known, final newer) => newer ?? known,
    };
    final delayed = ref.watch(board.select((s) => s.delayed));
    final actions = ref.watch(pairActionsProvider);
    final askAi = ref.watch(askAiOnPairProvider);
    final futures = pair.market == Market.futures;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${pair.baseAsset}/${pair.quoteAsset}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _MarketTag(futures ? l.marketFutures : l.marketSpot),
          ],
        ),
      ),
      body: state.pairGone
          ? _Message(l.analysisPairGone)
          : SingleChildScrollView(
              key: const Key('analysis-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(pair: pair, ticker: ticker, delayed: delayed),
                  const SizedBox(height: 8),
                  if (state.notInPlan)
                    _NotInPlan(state: state)
                  else ...[
                    if (futures) ...[
                      FuturesStrip(pair: pair, ticker: ticker),
                      const SizedBox(height: 8),
                    ],
                    _ChartBlock(
                      pair: pair,
                      timeframe: _tf,
                      state: state,
                      onTimeframe: (tf) => setState(() => _tf = tf),
                    ),
                    const SizedBox(height: 12),
                    ScoreCard(
                      state: state,
                      onRetry: () => ref
                          .read(analysisControllerProvider(key).notifier)
                          .load(),
                    ),
                    StatsCard(pair: pair, ticker: ticker),
                    // Once the analysis was read: the metrics need the same
                    // plan (MSG29), so they are not asked for before it.
                    if (futures && state.analysis != null)
                      FuturesMetricsCard(pair: pair),
                    PairNews(coin: pair.baseAsset),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: state.pairGone
          ? null
          : _ActionBar(
              pairActions: actions?.call(context, pair),
              onAskAi: askAi == null ? null : () => askAi(context, pair, _tf),
              onCreatePlan: () => ref
                  .read(webLinksProvider)
                  .open(
                    // SCR-17 is on the web (SRS 3.1.1), pre-filled as there.
                    '/plans/new?symbol=${Uri.encodeQueryComponent(pair.symbol)}'
                    '${futures ? '&market=futures' : ''}',
                  ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _MarketTag extends StatelessWidget {
  const _MarketTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: context.cp.raised,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: context.cp.muted),
    ),
  );
}

/// The price, its 24 h change with a sign, Live / Delayed (CR-09) and the
/// day's range.
class _Header extends StatelessWidget {
  const _Header({
    required this.pair,
    required this.ticker,
    required this.delayed,
  });

  final MarketPair pair;
  final Ticker? ticker;
  final bool delayed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final ticker = this.ticker;
    final hasRange = ticker?.high24h != null || ticker?.low24h != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPrice(ticker?.displayPrice, pair.tickSize),
                  key: const Key('analysis-price'),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Futures has no 24 h change (Q-91): nothing rather than "--".
            if (ticker?.changePercent24h != null)
              SignedPercentText(
                ticker!.changePercent24h,
                key: const Key('analysis-change'),
                style: text.titleMedium,
              ),
            const Spacer(),
            LiveBadge(delayed: delayed),
          ],
        ),
        if (hasRange)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l.analysisDayRange(
                formatPrice(ticker?.high24h, pair.tickSize),
                formatPrice(ticker?.low24h, pair.tickSize),
                formatCompact(ticker?.quoteVolume24h),
              ),
              style: text.bodySmall?.copyWith(
                color: context.cp.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// The timeframes of BR-08, the indicator switches, the candle chart with
/// the BR-14 levels of the chart's timeframe and the note for a short
/// history.
class _ChartBlock extends ConsumerWidget {
  const _ChartBlock({
    required this.pair,
    required this.timeframe,
    required this.state,
    required this.onTimeframe,
  });

  final MarketPair pair;
  final Timeframe timeframe;
  final AnalysisState state;
  final ValueChanged<Timeframe> onTimeframe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final analysis = state.analysis;
    final lines = [
      if (analysis?.nearestResistance case final level?)
        ChartPriceLine(
          price: level,
          label: l.analysisResistance,
          color: cp.negative,
        ),
      if (analysis?.nearestSupport case final level?)
        ChartPriceLine(
          price: level,
          label: l.analysisSupport,
          color: cp.positive,
        ),
    ];
    // SRS 3.3.2: fewer than 200 closed candles.
    final short = analysis != null && analysis.indicators['ema200'] == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<Timeframe>(
                  key: const Key('analysis-timeframes'),
                  showSelectedIcon: false,
                  segments: [
                    for (final tf in chartTimeframes)
                      ButtonSegment(value: tf, label: Text(tf.wire)),
                  ],
                  selected: {timeframe},
                  onSelectionChanged: (picked) => onTimeframe(picked.first),
                ),
              ),
            ),
            IconButton(
              key: const Key('open-indicators'),
              tooltip: l.analysisIndicators,
              icon: const Icon(Icons.tune),
              onPressed: () => unawaited(showIndicatorSheet(context)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ChartView(
            candleKey: (
              market: pair.market,
              symbol: pair.symbol,
              tf: timeframe,
            ),
            precision: decimalsOf(pair.tickSize),
            indicators: ref.watch(chartIndicatorsProvider),
            lines: lines,
          ),
        ),
        if (short)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.analysisInsufficientNotice,
              key: const Key('analysis-insufficient'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cp.muted),
            ),
          ),
      ],
    );
  }
}

/// SRS 3.3.3: on a plan without the Futures analysis, opening it shows
/// MSG29; the plans are on the web.
class _NotInPlan extends ConsumerWidget {
  const _NotInPlan({required this.state});

  final AnalysisState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Card(
      key: const Key('analysis-not-in-plan'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock_outline, color: context.cp.muted),
            const SizedBox(height: 8),
            Text(failureText(l, state.failure!), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('upgrade-open-web'),
              onPressed: () => ref.read(webLinksProvider).open('/subscription'),
              child: Text(l.upgradeOnWeb),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed bar of SRS 3.3.2's actions: Add to Watchlist and Create Alert
/// (composed by `main.dart`), Ask AI (SCR-29, at the timeframe on screen)
/// and Create Trading Plan, which opens the web.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.pairActions,
    required this.onCreatePlan,
    this.onAskAi,
  });

  final Widget? pairActions;
  final VoidCallback onCreatePlan;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: context.cp.surface,
      child: SafeArea(
        top: false,
        child: Container(
          key: const Key('analysis-actions'),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.cp.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              if (pairActions case final actions?) ...[
                actions,
                const SizedBox(width: 8),
              ],
              if (onAskAi case final ask?) ...[
                IconButton.outlined(
                  key: const Key('ask-ai'),
                  tooltip: l.aiAskAi,
                  onPressed: ask,
                  icon: const Icon(Icons.auto_awesome),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Tooltip(
                  message: l.analysisCreatePlanHint,
                  child: FilledButton.icon(
                    key: const Key('create-plan'),
                    onPressed: onCreatePlan,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      l.analysisCreatePlan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
