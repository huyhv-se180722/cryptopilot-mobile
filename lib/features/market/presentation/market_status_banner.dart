import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../data/market_status_repository.dart';
import '../domain/market.dart';
import '../domain/market_health.dart';

String _marketName(AppLocalizations l, Market market) =>
    market == Market.spot ? l.mktSpot : l.mktFutures;

/// An instant as the banner words it: the local time, with the day when it
/// is not today.
String marketTime(DateTime? at, {DateTime? now}) {
  if (at == null) return '—';
  final local = at.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return DateFormat(sameDay ? 'HH:mm' : 'd MMM HH:mm', 'en').format(local);
}

/// Why [symbol] of [health]'s market cannot be traded now, or null (I7):
/// the market is closed, or the pair's own data is lost while it is open
/// (E5). The order forms show it and keep their button off; the backend is
/// still the real gate (MSG57).
String? tradingBlockText(
  AppLocalizations l,
  MarketHealth health,
  String? symbol,
) {
  if (!health.tradingOpen) {
    return l.mktBlocked(_marketName(l, health.market));
  }
  if (symbol != null && !health.canTrade(symbol)) {
    return l.mktPairBlocked(symbol.toUpperCase());
  }
  return null;
}

/// The trading block of one pair, kept current by the market status.
String? watchTradingBlock(
  WidgetRef ref,
  AppLocalizations l,
  Market market,
  String? symbol,
) => tradingBlockText(
  l,
  ref.watch(marketStatusProvider.select((status) => status.of(market))),
  symbol,
);

/// The strip on Trade, Assets and the plan screens (D-159, T-146), one line
/// per market of [markets] that is not live: paused, under maintenance or
/// catching up, with since when, why, what the Trader keeps and where the
/// shown prices come from; and for ten minutes after it ends, that trading
/// has reopened, until dismissed. A short reconnect shows nothing.
class MarketStatusBanner extends ConsumerStatefulWidget {
  const MarketStatusBanner({this.markets = Market.values, super.key});

  final List<Market> markets;

  @override
  ConsumerState<MarketStatusBanner> createState() => _MarketStatusBannerState();
}

class _MarketStatusBannerState extends ConsumerState<MarketStatusBanner> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(marketStatusProvider);
    final shown = [
      for (final market in widget.markets)
        if (status.of(market) case final health
            when health.noteworthy &&
                !(health.tradingOpen && _dismissed.contains(health.incidentId)))
          health,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final health in shown)
          _MarketLine(
            health: health,
            onDismiss: () => setState(() => _dismissed.add(health.incidentId!)),
          ),
      ],
    );
  }
}

class _MarketLine extends StatelessWidget {
  const _MarketLine({required this.health, required this.onDismiss});

  final MarketHealth health;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final market = _marketName(l, health.market);
    final Color tone;
    final IconData icon;
    final String title;
    final lines = <String>[];
    if (health.tradingOpen) {
      tone = cp.positive;
      icon = Icons.check_circle_outline;
      title = l.mktResumedTitle(market);
      lines.add(
        l.mktResumedBody(
          marketTime(health.since ?? health.pausedAt),
          marketTime(health.resumedAt),
        ),
      );
    } else if (health.state == MarketHealthState.maintenance) {
      tone = cp.warning;
      icon = Icons.build_outlined;
      title = l.mktMaintenanceTitle(market);
      lines.add(health.message ?? l.mktMaintenanceBody);
      if (health.expectedEndAt != null) {
        lines.add(l.mktExpectedEnd(marketTime(health.expectedEndAt)));
      }
    } else if (health.state == MarketHealthState.recovering) {
      tone = cp.primary;
      icon = Icons.sync;
      title = l.mktRecoveringTitle(market);
      lines.add(l.mktRecoveringBody);
      final total = health.pairsTotal ?? 0;
      if (total > 0) {
        lines.add(l.mktProgress('${health.pairsDone ?? 0}', '$total'));
      }
    } else {
      tone = cp.negative;
      icon = Icons.error_outline;
      title = l.mktPausedTitle(market);
      lines.add(l.mktPausedBody(marketTime(health.since)));
      if (health.reason case final reason?) {
        lines.add(switch (reason) {
          IncidentReason.streamLost => l.mktReasonStreamLost,
          IncidentReason.restUnavailable => l.mktReasonRestUnavailable,
          IncidentReason.rateLimited => l.mktReasonRateLimited,
          IncidentReason.ipBanned => l.mktReasonIpBanned,
          IncidentReason.maintenance => l.mktReasonMaintenance,
        });
      }
      if (health.retryAt != null) {
        lines.add(l.mktRetryAt(marketTime(health.retryAt)));
      }
    }
    if (!health.tradingOpen && health.state != MarketHealthState.maintenance) {
      if (health.displaySource == DisplaySource.okx) {
        lines.add(l.mktReferenceOkx);
      }
      if (health.displaySource == DisplaySource.none) {
        lines.add(l.mktReferenceNone);
      }
    }
    final text = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: Key('market-status-${health.market.wire}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        color: tone.withValues(alpha: 0.12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: tone),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        color: tone,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: ' ${lines.join(' ')}',
                      style: TextStyle(color: cp.text),
                    ),
                  ],
                ),
                style: text,
              ),
            ),
            if (health.tradingOpen)
              IconButton(
                key: Key('market-status-dismiss-${health.market.wire}'),
                tooltip: l.mktDismiss,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// The trading block of a form, in the error colour, or nothing.
class TradingBlockNotice extends StatelessWidget {
  const TradingBlockNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      key: const Key('trading-block'),
      style: TextStyle(color: context.cp.negative, fontSize: 12),
    ),
  );
}

/// Under a pair's price while its market's data is lost (D-159): the
/// display-only reference price from OKX with its time, or that there is
/// none. Nothing while the market's data is live.
class ReferencePriceNote extends ConsumerWidget {
  const ReferencePriceNote({
    required this.market,
    required this.symbol,
    super.key,
  });

  final Market market;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lost = ref.watch(
      marketStatusProvider.select((status) => status.of(market).dataLost),
    );
    if (!lost) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final prices = ref.watch(fallbackPricesProvider(market));
    final price = prices?.prices[symbol.toUpperCase()];
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: context.cp.muted);
    return Padding(
      key: const Key('reference-price'),
      padding: const EdgeInsets.only(top: 4),
      child: price == null
          ? Text(l.mktNoReference, style: style)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.mktReferencePrice(groupThousands(price.lastPrice)),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  l.mktSourceAsOf(marketTime(price.asOf ?? prices?.asOf)),
                  style: style,
                ),
                if (price.diverged)
                  Text(
                    l.mktDiverged,
                    style: style?.copyWith(color: context.cp.warning),
                  ),
              ],
            ),
    );
  }
}
