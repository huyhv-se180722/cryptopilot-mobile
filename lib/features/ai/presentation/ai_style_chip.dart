import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/web/web_links.dart';
import '../../account/domain/profile.dart';
import '../application/ai_style.dart';

String tradingStyleName(AppLocalizations l, TradingStyle style) =>
    switch (style) {
      TradingStyle.scalping => l.aiStyleScalping,
      TradingStyle.day => l.aiStyleDay,
      TradingStyle.swing => l.aiStyleSwing,
      TradingStyle.position => l.aiStylePosition,
    };

String riskProfileName(AppLocalizations l, RiskProfile risk) => switch (risk) {
  RiskProfile.conservative => l.aiRiskConservative,
  RiskProfile.balanced => l.aiRiskBalanced,
  RiskProfile.aggressive => l.aiRiskAggressive,
};

/// The trading style and risk profile the assistant answers for, as the
/// web's style chip (T-074); it opens the profile on the web to change
/// them, or to choose a style when none is set.
class AiStyleChip extends ConsumerWidget {
  const AiStyleChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(aiStyleProvider).value;
    if (profile == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final style = profile.tradingStyle;
    final label = style == null
        ? l.aiStyleNotSet
        : l.aiStyleChip(
            tradingStyleName(l, style),
            riskProfileName(l, profile.riskProfile),
          );
    return Tooltip(
      message: l.aiStyleHint,
      child: ActionChip(
        key: const Key('ai-style'),
        visualDensity: VisualDensity.compact,
        avatar: const Icon(Icons.tune, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: () => unawaited(ref.read(webLinksProvider).open('/profile')),
      ),
    );
  }
}
