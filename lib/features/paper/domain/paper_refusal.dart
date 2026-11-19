import 'package:flutter/foundation.dart';

import '../../../core/errors/api_failure.dart';

/// What a paper refusal says, by its `code` (most borrow MSG43 or MSG15, so
/// the code, not the message, tells them apart; plan 9.8, web
/// `paper-errors.ts`).
enum RefusalKind {
  /// At least [PaperRefusal.limit] (MIN of a filter).
  atLeast,

  /// At most [PaperRefusal.limit] (MAX of a filter).
  atMost,

  /// A multiple of [PaperRefusal.limit] (STEP of a filter).
  step,

  /// The order value is below [PaperRefusal.limit] in the quote asset.
  minNotional,

  /// The order value is above [PaperRefusal.limit] in the quote asset.
  maxNotional,

  /// Too far below the last price: at least [PaperRefusal.limit].
  percentBelow,

  /// Too far above the last price: at most [PaperRefusal.limit].
  percentAbove,

  /// Not enough free [PaperRefusal.asset]: [PaperRefusal.limit] needed.
  insufficientBalance,

  /// The order (or group) has already finished.
  orderNotOpen,

  /// A limit maker would take liquidity at once.
  wouldTake,

  /// The stop is already met at the last price.
  wouldTrigger,

  /// Too many open orders on the pair: at most [PaperRefusal.limit].
  tooManyOrders,

  /// Too many open stops on the pair: at most [PaperRefusal.limit].
  tooManyStops,

  /// The pair cannot be valued in USDT now.
  notValued,
}

@immutable
class PaperRefusal {
  const PaperRefusal(this.kind, {this.field, this.limit, this.asset});

  final RefusalKind kind;

  /// The request field the server names (`price`, `quantity`,
  /// `quoteOrderQty`, `stopPrice`, `oco.takeProfitPrice`, …), or null for a
  /// refusal of the whole order.
  final String? field;
  final String? limit;
  final String? asset;
}

const _filterCodes = {
  'PAPER_PRICE_FILTER',
  'PAPER_LOT_SIZE',
  'PAPER_MARKET_LOT_SIZE',
  'PAPER_NOTIONAL',
  'PAPER_PERCENT_PRICE',
};

/// The paper refusal [failure] carries, or null for any other failure.
PaperRefusal? paperRefusal(ApiFailure failure) {
  if (failure is! ProblemFailure) return null;
  final problem = failure.problem;
  final args = problem.messageArgs;
  String? arg(int i) => i < args.length ? args[i] : null;
  switch (problem.code) {
    case 'PAPER_INSUFFICIENT_BALANCE':
      // [asset, needed, free]
      return PaperRefusal(
        RefusalKind.insufficientBalance,
        asset: arg(0),
        limit: arg(1),
      );
    case 'PAPER_ORDER_NOT_OPEN':
      return const PaperRefusal(RefusalKind.orderNotOpen);
    case 'PAPER_ORDER_WOULD_TAKE':
      return const PaperRefusal(RefusalKind.wouldTake);
    case 'PAPER_ORDER_WOULD_TRIGGER':
      return PaperRefusal(RefusalKind.wouldTrigger, field: arg(0));
    case 'PAPER_PAIR_NOT_VALUED':
      return const PaperRefusal(RefusalKind.notValued);
    case 'PAPER_MAX_NUM_ORDERS':
      return PaperRefusal(RefusalKind.tooManyOrders, limit: arg(2));
    case 'PAPER_MAX_NUM_ALGO_ORDERS':
      return PaperRefusal(RefusalKind.tooManyStops, limit: arg(2));
  }
  if (!_filterCodes.contains(problem.code)) return null;
  // [field, value, limit, MIN | MAX | STEP]
  final field = arg(0);
  final limit = arg(2);
  final bound = arg(3);
  if (field == null || limit == null) return null;
  final min = bound == 'MIN';
  final kind = switch ((problem.code, bound)) {
    (_, 'STEP') => RefusalKind.step,
    ('PAPER_NOTIONAL', _) =>
      min ? RefusalKind.minNotional : RefusalKind.maxNotional,
    ('PAPER_PERCENT_PRICE', _) =>
      min ? RefusalKind.percentBelow : RefusalKind.percentAbove,
    (_, 'MIN') => RefusalKind.atLeast,
    (_, 'MAX') => RefusalKind.atMost,
    _ => null,
  };
  if (kind == null) return null;
  return PaperRefusal(kind, field: field, limit: limit);
}
