import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../market/domain/market.dart';
import '../application/analysis_controller.dart';
import '../domain/analysis.dart';
import 'analysis_card.dart';

/// The Setup Score card of SCR-10 / SCR-11 (SRS 3.3.2, BR-13): the 0–100
/// score read with the Trader's preset, the preset's name, version and
/// timeframe, the scored and dominant sides, why it was capped, and the
/// MSG42 disclaimer (BR-60). The
/// component scores are locked with MSG29 on a plan without them (CR-08). A
/// missing score is "Insufficient data", never 0.
class ScoreCard extends ConsumerWidget {
  const ScoreCard({required this.state, required this.onRetry, super.key});

  final AnalysisState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final analysis = state.analysis;

    return AnalysisCard(
      key: const Key('score-card'),
      title: l.analysisScoreTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (analysis != null)
            ..._score(context, ref, analysis)
          else if (state.failure case final failure?)
            BlockFailure(error: failure, onRetry: onRetry)
          else
            const BlockSkeleton(key: Key('score-loading')),
          const Divider(height: 24),
          Text(
            l.msg42,
            key: const Key('analysis-disclaimer'),
            style: text.bodySmall?.copyWith(color: cp.muted),
          ),
        ],
      ),
    );
  }

  List<Widget> _score(BuildContext context, WidgetRef ref, Analysis analysis) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final setup = analysis.setupScore;
    final score = setup?.score;
    final components = setup?.components;

    // SRS 3.3.3: the sides belong to the Futures score. On Spot the scored
    // side is always LONG and is not shown (SRS 3.3.2).
    final hasSides =
        analysis.market == Market.futures &&
        (setup?.scoredSide != null || setup?.dominantSide != null);

    return [
      if (score == null)
        Text(
          l.analysisInsufficient,
          key: const Key('score-insufficient'),
          style: text.titleMedium?.copyWith(color: cp.muted),
        )
      else ...[
        Semantics(
          // One node, read as a sentence instead of "56" then "/ 100".
          container: true,
          label: l.analysisScoreLabel('$score'),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                key: const Key('score-value'),
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l.analysisScoreOutOf,
                style: text.bodyMedium?.copyWith(color: cp.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: cp.raised,
          ),
        ),
      ],
      if (hasSides) ...[
        const SizedBox(height: 8),
        _Sides(setup: setup),
        const SizedBox(height: 2),
        Text(
          l.analysisSidesNote,
          key: const Key('score-sides-note'),
          style: text.bodySmall?.copyWith(color: cp.muted),
        ),
      ],
      if (setup != null) ...[
        const SizedBox(height: 8),
        Text(
          l.analysisPresetLine(
            _presetName(l, setup.preset),
            setup.presetVersion,
            setup.timeframe,
          ),
          key: const Key('score-preset'),
          style: text.bodySmall?.copyWith(color: cp.muted),
        ),
      ],
      if (setup?.capReason == CapReason.lowRoom) ...[
        const SizedBox(height: 8),
        Row(
          key: const Key('score-capped'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: cp.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.analysisScoreCapped,
                style: text.bodySmall?.copyWith(color: cp.warning),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Text(l.analysisComponents, style: text.labelLarge),
      const SizedBox(height: 4),
      if (analysis.componentsLocked)
        _Locked(onOpen: () => ref.read(webLinksProvider).open('/subscription'))
      else if (components != null) ...[
        _Component(l.componentTrend, components.trend),
        _Component(l.componentMomentum, components.momentum),
        _Component(l.componentVolume, components.volume),
        _Component(l.componentLevel, components.level),
        if (analysis.market == Market.futures)
          _Component(l.componentDerivatives, components.derivatives),
      ] else
        Text(
          l.analysisInsufficient,
          style: text.bodySmall?.copyWith(color: cp.muted),
        ),
    ];
  }
}

/// SRS 3.3.3 (BR-13, setup score v2): the side every component of a
/// Futures score was scored for and the dominant side of the trend, with
/// the score.
/// Information about the score, never a recommendation to trade (BR-51):
/// plain text, no green or red, no arrow.
class _Sides extends StatelessWidget {
  const _Sides({required this.setup});

  final AnalysisScore? setup;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final rows = [
      if (setup?.scoredSide case final side?)
        (
          'scored',
          l.analysisScoredSide,
          switch (side) {
            ScoredSide.long => l.sideLong,
            ScoredSide.short => l.sideShort,
          },
        ),
      if (setup?.dominantSide case final side?)
        (
          'dominant',
          l.analysisDominantSide,
          switch (side) {
            DominantSide.long => l.sideLong,
            DominantSide.short => l.sideShort,
            DominantSide.neutral => l.sideNeutral,
          },
        ),
    ];
    return Wrap(
      key: const Key('score-sides'),
      spacing: 16,
      runSpacing: 2,
      children: [
        for (final (id, label, value) in rows)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: text.bodySmall?.copyWith(color: cp.muted)),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    key: Key('side-$id'),
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _presetName(AppLocalizations l, String preset) => switch (preset) {
  'SCALPING' => l.presetScalping,
  'DAY_TRADING' => l.presetDayTrading,
  'SWING' => l.presetSwing,
  _ => preset,
};

/// CR-08: the component scores stay visible with a lock and MSG29; the plans
/// are on the web.
class _Locked extends StatelessWidget {
  const _Locked({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    return Container(
      key: const Key('components-locked'),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 2),
      decoration: BoxDecoration(
        border: Border.all(color: cp.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 16, color: cp.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    // SRS 3.3.2: component scores on PRO and PREMIUM.
                    l.msg29('PRO'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cp.muted),
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            key: const Key('components-upgrade'),
            onPressed: onOpen,
            child: Text(l.upgradeOnWeb),
          ),
        ],
      ),
    );
  }
}

/// One component, 0–100; a value that cannot be computed is a dash read as
/// "Insufficient data".
class _Component extends StatelessWidget {
  const _Component(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cp = context.cp;
    final shown = value == null ? null : formatDecimal(value, 0);
    // Drawing only: the bar's length is not a figure the Trader reads.
    final part = ((double.tryParse(value ?? '') ?? 0) / 100).clamp(0.0, 1.0);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(color: cp.muted),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: part,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: cp.raised,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                shown ?? '—',
                semanticsLabel: shown ?? l.analysisInsufficient,
                textAlign: TextAlign.end,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
