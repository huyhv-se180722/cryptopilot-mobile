import 'package:flutter/material.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/spot_form_controller.dart';
import '../domain/paper_refusal.dart';

/// A paper refusal in words; [quote] names the asset of an order value.
String refusalText(AppLocalizations l, PaperRefusal refusal, String quote) {
  final limit = groupThousands(refusal.limit ?? '');
  return switch (refusal.kind) {
    RefusalKind.atLeast => l.paperErrAtLeast(limit),
    RefusalKind.atMost => l.paperErrAtMost(limit),
    RefusalKind.step => l.paperErrStep(refusal.limit ?? ''),
    RefusalKind.minNotional => l.paperErrMinNotional(limit, quote),
    RefusalKind.maxNotional => l.paperErrMaxNotional(limit, quote),
    RefusalKind.percentBelow => l.paperErrPercentBelow(limit),
    RefusalKind.percentAbove => l.paperErrPercentAbove(limit),
    RefusalKind.insufficientBalance => l.paperErrInsufficient,
    RefusalKind.orderNotOpen => l.paperErrNotOpen,
    RefusalKind.wouldTake => l.paperErrWouldTake,
    RefusalKind.wouldTrigger => l.paperErrWouldTrigger,
    RefusalKind.tooManyOrders => l.paperErrTooManyOrders(limit),
    RefusalKind.tooManyStops => l.paperErrTooManyStops(limit),
    RefusalKind.notValued => l.paperErrNotValued,
    RefusalKind.insufficientMargin => l.paperErrInsufficientMargin,
    RefusalKind.reduceOnlyRejected => l.paperErrReduceOnly,
    RefusalKind.maxPosition => l.paperErrMaxPosition,
    RefusalKind.leverageMargin => l.paperErrLeverageMargin,
    RefusalKind.marginTypeLocked => l.paperErrMarginTypeLocked,
    RefusalKind.inLiquidation => l.paperErrInLiquidation,
    RefusalKind.positionMargin => l.paperErrPositionMargin,
  };
}

/// A field error in words.
String fieldErrorText(AppLocalizations l, FieldError error, String quote) {
  if (error.refusal case final refusal?) return refusalText(l, refusal, quote);
  return switch (error.issue!) {
    InputIssue.required => l.paperErrRequired,
    InputIssue.notPositive => l.paperErrPositive,
    InputIssue.offStep => l.paperErrStep(_plain(error.limit ?? '')),
    InputIssue.stopSide => l.paperErrStopSide,
    InputIssue.takeProfitSide => l.paperErrTakeProfitSide,
  };
}

/// `0.010000000000` → `0.01`.
String _plain(String step) => step.contains('.')
    ? step.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
    : step;

/// "Demo · virtual funds" on every paper screen (D-154 (3)).
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('paper-demo-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: context.cp.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: context.cp.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.paperDemoBanner,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
