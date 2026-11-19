import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/chart_prefs.dart';
import '../domain/chart_indicators.dart';

/// The switches of the chart's overlays and panels (SRS 3.3.2, BR-12).
Future<void> showIndicatorSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const IndicatorSheet(),
    );

String indicatorLabel(AppLocalizations l, ChartIndicator indicator) =>
    switch (indicator) {
      ChartIndicator.sma20 => l.indicatorSma20,
      ChartIndicator.ema20 => l.indicatorEma20,
      ChartIndicator.ema50 => l.indicatorEma50,
      ChartIndicator.ema200 => l.indicatorEma200,
      ChartIndicator.bollinger => l.indicatorBollinger,
      ChartIndicator.volume => l.indicatorVolume,
      ChartIndicator.rsi => l.indicatorRsi,
      ChartIndicator.macd => l.indicatorMacd,
    };

class IndicatorSheet extends ConsumerWidget {
  const IndicatorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final chosen = ref.watch(chartIndicatorsProvider);

    Widget heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        title,
        style: text.labelLarge?.copyWith(color: context.cp.muted),
      ),
    );

    Widget toggle(ChartIndicator indicator) => SwitchListTile(
      key: Key('indicator-${indicator.key}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
      title: Text(indicatorLabel(l, indicator)),
      value: chosen.contains(indicator),
      onChanged: (_) =>
          ref.read(chartIndicatorsProvider.notifier).toggle(indicator),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(l.analysisIndicators, style: text.titleLarge),
            ),
            heading(l.analysisOverlays),
            for (final indicator in ChartIndicator.values)
              if (ChartIndicator.overlays.contains(indicator))
                toggle(indicator),
            heading(l.analysisPanels),
            for (final indicator in ChartIndicator.values)
              if (!ChartIndicator.overlays.contains(indicator))
                toggle(indicator),
          ],
        ),
      ),
    );
  }
}
