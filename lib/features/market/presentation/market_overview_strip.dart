import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/market_overview.dart';
import '../domain/coin_market.dart';
import 'market_widgets.dart';

String fearGreedLabel(AppLocalizations l, FearGreedBand band) => switch (band) {
  FearGreedBand.extremeFear => l.overviewFgExtremeFear,
  FearGreedBand.fear => l.overviewFgFear,
  FearGreedBand.neutral => l.overviewFgNeutral,
  FearGreedBand.greed => l.overviewFgGreed,
  FearGreedBand.extremeGreed => l.overviewFgExtremeGreed,
};

/// The Market overview strip above the Spot and Futures lists (A-65): the
/// whole market's figures, `--` for one the backend does not know. Nothing
/// shows when they cannot be read; the lists work without them.
class MarketOverviewStrip extends ConsumerWidget {
  const MarketOverviewStrip({super.key});

  static const height = 92.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final overview = ref.watch(marketOverviewProvider);
    if (overview.hasError && !overview.hasValue) return const SizedBox.shrink();
    final o = overview.value;
    final cards = o == null
        ? [for (var i = 0; i < 3; i++) const _CardFrame(child: SizedBox())]
        : _cards(context, l, cp, o);
    return SizedBox(
      key: const Key('market-overview'),
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  static String _usd(String? value) =>
      value == null ? '--' : '\$${formatCompact(value)}';

  List<Widget> _cards(
    BuildContext context,
    AppLocalizations l,
    CpColors cp,
    MarketOverview o,
  ) {
    final g = o.global;
    final fg = o.fearGreed;
    final season = o.altcoinSeason;
    final oi = o.openInterest;
    final band = fg == null ? null : fearGreedBand(fg.value);
    return [
      _Stat(
        key: const Key('overview-cap'),
        title: l.overviewMarketCap,
        value: _usd(g?.marketCapUsd),
        change: g?.marketCapChange24hPercent,
        source: l.overviewSourcePaprika,
      ),
      _Stat(
        key: const Key('overview-volume'),
        title: l.overviewVolume,
        value: _usd(g?.volume24hUsd),
        source: l.overviewSourcePaprika,
      ),
      _Stat(
        key: const Key('overview-dominance'),
        title: l.overviewDominance,
        value: g?.bitcoinDominancePercent == null
            ? '--'
            : '${formatDecimal(g!.bitcoinDominancePercent, 1)}%',
        source: l.overviewSourcePaprika,
      ),
      _CardFrame(
        key: const Key('overview-fear-greed'),
        tooltip: l.overviewSourceFearGreed,
        semantics: [
          l.overviewFearGreed,
          fg == null ? '--' : '${fg.value}',
          if (band != null) fearGreedLabel(l, band),
        ].join(', '),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(l.overviewFearGreed),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  if (fg != null) ...[
                    SizedBox(
                      width: 44,
                      height: 28,
                      child: CustomPaint(
                        key: const Key('overview-fear-greed-gauge'),
                        painter: _Gauge(fg.value, cp),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Value(fg == null ? '--' : '${fg.value}'),
                        if (band != null)
                          Text(
                            fearGreedLabel(l, band),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: switch (band) {
                                    FearGreedBand.extremeFear ||
                                    FearGreedBand.fear => cp.negative,
                                    FearGreedBand.greed ||
                                    FearGreedBand.extremeGreed => cp.positive,
                                    _ => cp.muted,
                                  },
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _CardFrame(
        key: const Key('overview-season'),
        tooltip: season == null
            ? null
            : l.overviewSeasonHint(season.altcoins, season.days),
        semantics: season == null
            ? '${l.overviewAltcoinSeason} --'
            : '${l.overviewAltcoinSeason} ${season.index} / 100',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(l.overviewAltcoinSeason),
            const SizedBox(height: 4),
            _Value(season == null ? '--' : '${season.index}/100'),
            const Spacer(),
            if (season != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: season.index / 100,
                  minHeight: 4,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: cp.raised,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _Note(l.overviewSeasonBitcoin)),
                  const SizedBox(width: 4),
                  Flexible(child: _Note(l.overviewSeasonAltcoin, end: true)),
                ],
              ),
            ],
          ],
        ),
      ),
      _Stat(
        key: const Key('overview-open-interest'),
        title: l.overviewOpenInterest,
        value: _usd(oi?.valueUsd),
        change: oi?.change24hPercent,
        source: l.overviewOpenInterestHint,
      ),
    ];
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.child,
    this.tooltip,
    this.semantics,
    super.key,
  });

  final Widget child;
  final String? tooltip;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    Widget card = Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cp.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cp.border),
      ),
      child: child,
    );
    if (semantics != null) {
      card = Semantics(
        container: true,
        label: semantics,
        child: ExcludeSemantics(child: card),
      );
    }
    return tooltip == null ? card : Tooltip(message: tooltip, child: card);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.title,
    required this.value,
    this.change,
    this.source,
    super.key,
  });

  final String title;
  final String value;
  final String? change;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final percent = change == null ? null : formatSignedPercent(change);
    return _CardFrame(
      tooltip: source,
      semantics: [title, value, ?percent].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(title),
          const SizedBox(height: 4),
          _Value(value),
          const Spacer(),
          // The change with its arrow (D-163).
          if (percent != null)
            ChangeText(
              percent: change,
              style: Theme.of(context).textTheme.labelMedium,
            ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: context.cp.muted),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.end = false});

  final String text;
  final bool end;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: end ? TextAlign.end : TextAlign.start,
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: context.cp.muted),
  );
}

/// The Fear & Greed index on a half dial, red to green in five bands, with
/// a dot at the value (D-163). Colours from the theme tokens only.
class _Gauge extends CustomPainter {
  _Gauge(this.value, this.cp);

  final int value;
  final CpColors cp;

  @override
  void paint(Canvas canvas, Size size) {
    final r = min(size.width / 2, size.height) - 4;
    final center = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    final colors = [
      cp.negative,
      Color.lerp(cp.negative, cp.warning, 0.5)!,
      cp.warning,
      Color.lerp(cp.warning, cp.positive, 0.5)!,
      cp.positive,
    ];
    for (var i = 0; i < colors.length; i++) {
      canvas.drawArc(
        rect,
        pi + i * pi / 5 + 0.04,
        pi / 5 - 0.08,
        false,
        Paint()
          ..color = colors[i]
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    final angle = pi + pi * value.clamp(0, 100) / 100;
    final dot = center + Offset(r * cos(angle), r * sin(angle));
    canvas.drawCircle(dot, 4.5, Paint()..color = cp.text);
    canvas.drawCircle(dot, 2.5, Paint()..color = cp.surface);
  }

  @override
  bool shouldRepaint(_Gauge old) => old.value != value || old.cp != cp;
}
