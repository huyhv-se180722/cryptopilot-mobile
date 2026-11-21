import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/data/order_book_repository.dart';
import '../../market/domain/market.dart';
import '../../market/domain/order_book.dart';
import '../../market/presentation/market_widgets.dart';

/// The order book of a pair beside a Trade form (TR-03, plan 9.2): 7 + 7
/// levels grouped by a chosen tick, the last price between them and the
/// bid share; a level tapped hands its price to [onPrice]. Read only
/// while the tab shows; Live / Delayed beside the last price (CR-09).
class OrderBookPanel extends ConsumerStatefulWidget {
  const OrderBookPanel({
    required this.pair,
    required this.market,
    required this.onPrice,
    super.key,
  });

  final MarketPair pair;
  final Market market;
  final ValueChanged<String> onPrice;

  @override
  ConsumerState<OrderBookPanel> createState() => _OrderBookPanelState();
}

class _OrderBookPanelState extends ConsumerState<OrderBookPanel> {
  int _scale = 0;

  String get _step => _stepAt(_scale);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final pair = widget.pair;
    final book = ref.watch(
      orderBookProvider((market: widget.market, symbol: pair.symbol)),
    );
    final last = ref.watch(
      marketRepositoryProvider(
        widget.market,
      ).select((s) => s.tickers[pair.symbol]?.lastPrice),
    );
    final depth = book.depth;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
    final places = decimalPlaces(_step);

    Widget row(BookLevel level, Color color) => InkWell(
      key: Key('book-${level.price}'),
      onTap: () => widget.onPrice(level.price),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatDecimal(level.price, places),
                style: small?.copyWith(color: color),
              ),
            ),
            Text(
              formatDecimal(level.quantity, decimalPlaces(pair.stepSize)),
              style: small,
            ),
          ],
        ),
      ),
    );

    if (depth == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final asks = groupLevels(depth.asks, _step, bids: false);
    final bids = groupLevels(depth.bids, _step, bids: true);
    final share = bidShare(bids, asks);
    return Column(
      key: const Key('trade-book'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.tradeBookPrice, style: small)),
            Text(l.tradeBookAmount, style: small),
          ],
        ),
        for (final level in asks.reversed) row(level, context.cp.negative),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  formatPrice(last, pair.tickSize),
                  key: const Key('book-last'),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              LiveBadge(key: const Key('book-live'), delayed: book.delayed),
            ],
          ),
        ),
        for (final level in bids) row(level, context.cp.positive),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            color: context.cp.positive,
            backgroundColor: context.cp.negative,
          ),
        ),
        DropdownButton<int>(
          key: const Key('book-tick'),
          isExpanded: true,
          isDense: true,
          value: _scale,
          onChanged: (scale) => setState(() => _scale = scale!),
          items: [
            for (var i = 0; i < 3; i++)
              DropdownMenuItem(
                value: i,
                child: Text(l.tradeTick(_stepAt(i)), style: small),
              ),
          ],
        ),
      ],
    );
  }

  String _stepAt(int scale) {
    var step = Decimal.parse(widget.pair.tickSize);
    for (var i = 0; i < scale; i++) {
      step = step * Decimal.ten;
    }
    return step.toString();
  }
}
