import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../chart/application/chart_prefs.dart';
import '../../chart/presentation/metric_chart.dart';
import '../../chart/presentation/metric_surface.dart';
import '../../market/domain/market.dart';
import '../application/analysis_controller.dart';
import '../domain/analysis.dart';
import 'analysis_card.dart';

enum _Metric { openInterest, longShort }

/// SCR-11 open interest (contracts and value) and global long/short account
/// ratio over the last 1, 3 or 7 days of what the system retains (SRS 3.3.3,
/// BR-10). When less than the selected period is stored, the card states the
/// period that is; points are sparse and never filled in. The figures above
/// the chart are the latest stored ones, as decimal strings.
class FuturesMetricsCard extends ConsumerStatefulWidget {
  const FuturesMetricsCard({required this.pair, super.key});

  final MarketPair pair;

  @override
  ConsumerState<FuturesMetricsCard> createState() => _FuturesMetricsCardState();
}

class _FuturesMetricsCardState extends ConsumerState<FuturesMetricsCard> {
  _Metric _metric = _Metric.openInterest;
  int _days = metricRanges.first;

  // The lines of what was drawn last: the chart redraws only for another
  // list, and this card is rebuilt with every price.
  FuturesMetrics? _drawn;
  _Metric? _drawnMetric;
  Color? _drawnFirst;
  Color? _drawnSecond;
  List<MetricLine> _lines = const [];

  List<MetricLine> _linesOf(FuturesMetrics? metrics, CpColors cp) {
    if (identical(metrics, _drawn) &&
        _metric == _drawnMetric &&
        cp.primary == _drawnFirst &&
        cp.accent == _drawnSecond) {
      return _lines;
    }
    _drawn = metrics;
    _drawnMetric = _metric;
    _drawnFirst = cp.primary;
    _drawnSecond = cp.accent;
    return _lines = switch ((metrics, _metric)) {
      (null, _) => const [],
      (final m?, _Metric.longShort) => [
        MetricLine(
          color: cp.primary,
          scale: MetricScale.right,
          format: MetricFormat.ratio,
          points: [for (final p in m.longShortRatio) (p.time, p.value)],
        ),
      ],
      (final m?, _Metric.openInterest) => [
        MetricLine(
          color: cp.primary,
          scale: MetricScale.left,
          format: MetricFormat.amount,
          points: [for (final p in m.openInterest) (p.time, p.value)],
        ),
        MetricLine(
          color: cp.accent,
          scale: MetricScale.right,
          format: MetricFormat.amount,
          points: [
            for (final p in m.openInterest)
              if (p.second case final worth?) (p.time, worth),
          ],
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final pair = widget.pair;
    final key = (symbol: pair.symbol, days: _days);
    final state = ref.watch(futuresMetricsProvider(key));
    final zone = ref.watch(chartZoneProvider);
    final metrics = state.metrics;
    final lines = _linesOf(metrics, cp);
    final empty = lines.every((line) => line.points.isEmpty);
    final open = _metric == _Metric.openInterest;

    final latestOi = metrics?.openInterest.lastOrNull;
    final latestLs = metrics?.longShortRatio.lastOrNull;
    final latest = open ? latestOi : latestLs;
    final since = open ? metrics?.openInterestSince : metrics?.longShortSince;
    final partial =
        metrics != null && since != null && since.isAfter(metrics.from);
    // In the zone the chart's axis is in (BR-08), never the device locale.
    String at(DateTime instant) =>
        DateFormat('d MMM HH:mm', 'en_US').format(instant.toUtc().add(zone));

    final Widget? cover = switch (state) {
      MetricsState(metrics: null, failure: final failure?) => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: BlockFailure(
            error: failure,
            onRetry: () =>
                ref.read(futuresMetricsProvider(key).notifier).load(),
          ),
        ),
      ),
      MetricsState(metrics: null) => ColoredBox(
        key: const Key('metrics-loading'),
        color: cp.raised,
      ),
      _ when empty => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            l.metricsEmpty,
            key: const Key('metrics-empty'),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: cp.muted),
          ),
        ),
      ),
      _ => null,
    };

    return AnalysisCard(
      key: const Key('futures-metrics'),
      title: l.metricsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_Metric>(
              key: const Key('metric-kind'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _Metric.openInterest,
                  label: Text(l.metricOpenInterest),
                ),
                ButtonSegment(
                  value: _Metric.longShort,
                  label: Text(l.metricLongShort),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (picked) =>
                  setState(() => _metric = picked.first),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              key: const Key('metric-range'),
              showSelectedIcon: false,
              segments: [
                for (final days in metricRanges)
                  ButtonSegment(value: days, label: Text(l.metricRange(days))),
              ],
              selected: {_days},
              onSelectionChanged: (picked) =>
                  setState(() => _days = picked.first),
            ),
          ),
          const SizedBox(height: 8),
          // One slot whatever it holds: the chart below keeps its place in
          // the tree, and with it its page.
          Column(
            key: const Key('metric-figures'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover == null && open && latestOi != null) ...[
                _Figure(
                  id: 'oi',
                  swatch: cp.primary,
                  label: l.metricOiContracts(pair.baseAsset),
                  value: Text(formatDecimal(latestOi.value, 3)),
                ),
                _Figure(
                  id: 'oi-value',
                  swatch: cp.accent,
                  label: l.metricOiValue(pair.quoteAsset),
                  value: Text(formatCompact(latestOi.second)),
                ),
              ],
              if (cover == null && !open && latestLs != null) ...[
                _Figure(
                  id: 'ls-ratio',
                  swatch: cp.primary,
                  label: l.metricLsRatio,
                  value: Text(formatDecimal(latestLs.value, 4)),
                ),
                // Named, so the two shares never rely on their colours alone.
                _Figure(
                  id: 'ls-long',
                  label: l.metricLongAccounts,
                  value: Text(
                    formatRatioAsPercent(latestLs.longShare, places: 2),
                    style: TextStyle(color: cp.positive),
                  ),
                ),
                _Figure(
                  id: 'ls-short',
                  label: l.metricShortAccounts,
                  value: Text(
                    formatRatioAsPercent(latestLs.shortShare, places: 2),
                    style: TextStyle(color: cp.negative),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          MetricChart(
            lines: lines,
            label: l.metricsChartLabel(
              pair.symbol,
              open ? l.metricOpenInterest : l.metricLongShort,
              _days,
            ),
            cover: cover,
          ),
          if (partial)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l.metricsPartial(at(since)),
                key: const Key('metrics-partial'),
                style: text.bodySmall?.copyWith(color: cp.warning),
              ),
            ),
          if (latest != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.metricsUpdated(at(latest.time)),
                key: const Key('metrics-updated'),
                style: text.bodySmall?.copyWith(color: cp.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One latest figure above the chart; the swatch is the colour of its line.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.id,
    required this.label,
    required this.value,
    this.swatch,
  });

  final String id;
  final String label;
  final Widget value;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            if (swatch case final color?) ...[
              Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: context.cp.muted),
              ),
            ),
            const SizedBox(width: 8),
            // A very long figure shrinks; the label keeps room to be read.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: DefaultTextStyle.merge(
                  key: Key('metric-$id'),
                  style: (text.bodyMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  child: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
