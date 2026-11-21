import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/market_board.dart';
import '../application/market_overview.dart';
import '../data/market_repository.dart';
import '../domain/coin_market.dart';
import '../domain/market.dart';
import 'market_widgets.dart';
import 'pair_actions.dart';

enum CoinSort { top, gainers, losers }

/// The Coins list of the Markets tab (A-67, T-137), as the web's board:
/// rank, logo, name, live price and 24 h change, the market cap and the
/// 7 d change from the live price, and a 7-day line.
class CoinListView extends ConsumerStatefulWidget {
  const CoinListView({super.key});

  @override
  ConsumerState<CoinListView> createState() => _CoinListViewState();
}

class _CoinListViewState extends ConsumerState<CoinListView> {
  CoinSort _sort = CoinSort.top;

  static int _byChange(Decimal? x, Decimal? y, {required bool up}) {
    // A coin without a change goes last.
    if (x == null || y == null) {
      return (x == null ? 1 : 0) - (y == null ? 1 : 0);
    }
    return up ? y.compareTo(x) : x.compareTo(y);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final overview = ref.watch(marketOverviewProvider);
    // The Spot tickers stream while the list shows.
    final tickers = ref.watch(
      marketBoardProvider(Market.spot).select((s) => s.tickers),
    );
    final pairs =
        ref.watch(
          marketRepositoryProvider(Market.spot).select((s) => s.pairs),
        ) ??
        const <MarketPair>[];

    final Widget body;
    if (overview case AsyncValue(:final error?, hasValue: false)) {
      body = ListView(
        children: [
          const SizedBox(height: 96),
          Center(
            child: Text(
              error is ApiFailure ? failureText(l, error) : l.msg41,
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => ref.invalidate(marketOverviewProvider),
              child: Text(l.commonRetry),
            ),
          ),
        ],
      );
    } else if (overview.value case final o?) {
      final rows = [
        for (final coin in o.coins)
          (coin, coinFigures(coin, tickers[coin.spotSymbol])),
      ];
      if (_sort != CoinSort.top) {
        // Each change parsed once, not on every comparison (T-138).
        final change = {
          for (final row in rows)
            row.$1: Decimal.tryParse(row.$2.change24h ?? ''),
        };
        final up = _sort == CoinSort.gainers;
        rows.sort((a, b) => _byChange(change[a.$1], change[b.$1], up: up));
      }
      body = rows.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 96),
                Center(child: Text(l.msg41)),
              ],
            )
          : ListView.separated(
              key: const Key('coin-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => Divider(height: 1, color: cp.border),
              itemBuilder: (_, i) => i == rows.length
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l.coinsSource,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: cp.muted),
                      ),
                    )
                  : _CoinRow(
                      coin: rows[i].$1,
                      figures: rows[i].$2,
                      pair: pairs
                          .where((p) => p.symbol == rows[i].$1.spotSymbol)
                          .firstOrNull,
                    ),
            );
    } else {
      body = const ListSkeleton();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Wrap(
            spacing: 6,
            children: [
              for (final (sort, label) in [
                (CoinSort.top, l.coinsTop),
                (CoinSort.gainers, l.coinsGainers),
                (CoinSort.losers, l.coinsLosers),
              ])
                ChoiceChip(
                  key: Key('coins-sort-${sort.name}'),
                  label: Text(label),
                  selected: _sort == sort,
                  onSelected: (_) => setState(() => _sort = sort),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(marketOverviewProvider),
            child: body,
          ),
        ),
      ],
    );
  }
}

class _CoinRow extends StatelessWidget {
  const _CoinRow({required this.coin, required this.figures, this.pair});

  final CoinRow coin;
  final CoinFigures figures;
  final MarketPair? pair;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final f = figures;
    final week = f.change7d;
    final weekColor = switch (directionOf(week)) {
      Direction.up => cp.positive,
      Direction.down => cp.negative,
      Direction.flat => cp.muted,
    };
    final pair = this.pair;
    return InkWell(
      key: Key('coin-${coin.symbol}'),
      onTap: pair == null ? null : () => openPairAnalysis(context, pair),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                coin.rank == null ? '' : '${coin.rank}',
                style: text.labelSmall?.copyWith(color: cp.muted),
              ),
            ),
            CoinLogo(symbol: coin.symbol, url: coin.logoUrl),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coin.symbol,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.coinsCap(
                            f.marketCap == null
                                ? '--'
                                : '\$${formatCompact(f.marketCap)}',
                          ),
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: l.coins7d(formatSignedPercent(week)),
                          style: TextStyle(color: weekColor),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cp.muted),
                  ),
                ],
              ),
            ),
            if (coin.sparkline7d.length > 1)
              Semantics(
                label: l.coinsChart(coin.symbol),
                child: SizedBox(
                  width: 52,
                  height: 26,
                  child: CustomPaint(
                    key: Key('coin-line-${coin.symbol}'),
                    painter: _Sparkline(coin.sparkline7d, weekColor),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(f.price, pair?.tickSize),
                  style: text.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                ChangePill(percent: f.change24h, width: 70),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The 7-day closes as one line, scaled to the box.
class _Sparkline extends CustomPainter {
  _Sparkline(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final span = high - low == 0 ? 1 : high - low;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - low) / span * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.values != values || old.color != color;
}
