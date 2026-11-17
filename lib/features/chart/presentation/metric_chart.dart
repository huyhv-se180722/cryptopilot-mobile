import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/chart_prefs.dart';
import '../domain/chart_time.dart';
import 'chart_surface.dart';
import 'metric_surface.dart';

/// A line chart over time in the theme of the candle chart (SCR-11 open
/// interest and long/short ratio; ADR-012 / D-144). Drawing only: the
/// screen around it shows the figures. Times are in the device's zone, as
/// on the candle chart (BR-08), and the zone is named below the axis.
///
/// The page is sent [lines] again only when the list is another one, so the
/// caller keeps the same list while nothing changed: a redraw would undo
/// what the Trader zoomed to.
class MetricChart extends ConsumerStatefulWidget {
  const MetricChart({
    required this.lines,
    required this.label,
    this.cover,
    super.key,
  });

  final List<MetricLine> lines;

  /// What the chart shows, for a screen reader.
  final String label;

  /// Drawn over the chart while there is nothing to draw (loading, empty,
  /// failed): the page stays, so the next lines appear without a restart.
  final Widget? cover;

  static const height = 220.0;

  @override
  ConsumerState<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends ConsumerState<MetricChart> {
  MetricSurface? _surface;
  ChartTheme? _theme;
  List<MetricLine>? _sent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    // Watched, so the page lives exactly as long as this chart.
    final surface = ref.watch(metricSurfaceProvider);
    final zone = ref.watch(chartZoneProvider);
    if (!identical(surface, _surface)) {
      _surface = surface;
      _theme = null;
      _sent = null;
      unawaited(
        surface.warm().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    final theme = ChartTheme.of(cp);
    if (theme != _theme) {
      _theme = theme;
      unawaited(surface.setTheme(theme));
    }
    if (!identical(widget.lines, _sent)) {
      _sent = widget.lines;
      unawaited(surface.setLines(metricPayload(widget.lines, zone)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            key: const Key('metric-chart'),
            height: MetricChart.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    container: true,
                    image: true,
                    label: widget.label,
                    child: ExcludeSemantics(child: surface.view()),
                  ),
                ),
                if (widget.cover case final cover?)
                  Positioned.fill(
                    child: ColoredBox(color: cp.surface, child: cover),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l.chartTimeZone(zoneLabel(zone)),
            key: const Key('metric-zone'),
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cp.muted),
          ),
        ),
      ],
    );
  }
}
